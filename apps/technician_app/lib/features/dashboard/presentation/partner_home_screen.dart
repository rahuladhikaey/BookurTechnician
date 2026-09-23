import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import 'dashboard_provider.dart';
import 'notifications_tab.dart';
import 'my_skills_page.dart';

import '../../jobs/presentation/states/job_state.dart';
import '../../jobs/presentation/job_details_page.dart';
import '../../jobs/domain/job.dart';
import '../../analytics/presentation/technician_analytics_screen.dart';
import '../../analytics/presentation/technician_analytics_provider.dart';
import '../../analytics/domain/technician_analytics_models.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/services/socket_service.dart';

class PartnerHomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const PartnerHomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends ConsumerState<PartnerHomeScreen> with SingleTickerProviderStateMixin {
  final SkillService _skillService = SkillService();
  TechnicianSkillProfileModel? _skillProfile;
  late AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _fetchSkillProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final auth = ref.read(authProvider);
        final userId = await SecureStorage().getUserId();
        if (userId != null && userId.isNotEmpty) {
          TechnicianSocketService().connect(
            technicianId: userId,
            phone: auth.phone,
            category: 'electrician',
          );
        }
      } catch (_) {}

      if (!mounted) return;
      ref.read(dashboardProvider.notifier).fetchAndUpdateLocation(context: context, showPromptDialogs: false);
      ref.read(jobStateProvider.notifier).fetchAssignedJobs();
    });
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkillProfile() async {
    final profile = await _skillService.fetchMySkillProfile();
    if (mounted && profile != null) {
      setState(() {
        _skillProfile = profile;
      });
    }
  }

  static String formatCleanAddress(String raw) {
    if (raw.isEmpty) return 'Customer Premise';
    final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seen = <String>{};
    final cleanParts = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        cleanParts.add(p);
      }
    }
    return cleanParts.join(', ');
  }

  Future<void> _launchMaps(String destination) async {
    final query = Uri.encodeComponent(destination);
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigating to $destination')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigating to $destination')),
        );
      }
    }
  }

  Future<void> _callCustomer(String phone, String name) async {
    final Uri callUri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling $name at $phone')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $name at $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final dashNotifier = ref.read(dashboardProvider.notifier);
    final jobState = ref.watch(jobStateProvider);

    final technicianName = (authState.fullName != null && authState.fullName!.isNotEmpty)
        ? authState.fullName!
        : 'Rahul Partner';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0F172A),
          backgroundColor: const Color(0xFFFDB813),
          onRefresh: () async {
            await dashNotifier.fetchAndUpdateLocation();
            await ref.read(jobStateProvider.notifier).fetchAssignedJobs();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. RAPIDO CAPTAIN TOP APP BAR ───────────────────────────
                _buildCaptainHeader(technicianName, dashState, dashNotifier),
                const SizedBox(height: 12),

                // ─── 2. MASTER DUTY ONLINE/OFFLINE RADAR CARD ────────────────
                _buildMasterDutyCard(dashState, dashNotifier),
                const SizedBox(height: 14),

                // ─── 3. ACTIVE RUNNING JOB CARD (FLOATING RAPIDO BANNER) ─────
                _buildActiveRunningJobCard(context, dashState, jobState),
                if (jobState.activeJob != null && jobState.activeJob!.status != TechJobStatus.completed)
                  const SizedBox(height: 14),

                // ─── 4. DAILY INCENTIVE / TARGET PROGRESS METER ──────────────
                _buildDailyIncentiveGoalCard(jobState),
                const SizedBox(height: 14),

                // ─── 5. PERFORMANCE & EARNINGS 4-GRID (RAPIDO STYLE) ─────────
                _buildPerformanceMetricsGrid(dashState, jobState),
                const SizedBox(height: 14),

                // ─── 6. PARTNER TIER STATUS BANNER ───────────────────────────
                _buildTierMembershipBanner(context),
                const SizedBox(height: 18),

                // ─── 7. TODAY'S SCHEDULED BOOKINGS (REAL DATA ONLY) ──────────
                _buildTodayScheduleSection(context, jobState),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. Captain Top Header ──────────────────────────────────────────────────
  Widget _buildCaptainHeader(String technicianName, DashboardState state, DashboardNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onNavigateTab?.call(3),
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: state.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            width: 2.2,
                          ),
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFF1E293B),
                          child: Icon(Icons.engineering_rounded, color: Color(0xFFFDB813), size: 24),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: state.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              technicianName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF38BDF8)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.isOnline
                            ? '🟢 Online • ${_skillProfile?.primaryCategory ?? "Partner"} Radar'
                            : '⚪ Offline • ${_skillProfile?.primaryCategory ?? "Partner"} (Tap switch)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.isOnline ? const Color(0xFF86EFAC) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsTab()),
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: _skillProfile != null
                    ? '${_skillProfile!.primaryCategory} (${_skillProfile!.totalSelectedSkills} Skills)'
                    : 'My Skills',
                icon: const Icon(Icons.badge_outlined, color: Color(0xFFFDB813), size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MySkillsPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Master Rapido Online/Offline Duty Card with Radar ────────────────────
  Widget _buildMasterDutyCard(DashboardState state, DashboardNotifier notifier) {
    final cleanAddr = formatCleanAddress(state.currentLocationAddress);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: state.isOnline ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: state.isOnline ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: state.isOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (state.isOnline)
                        AnimatedBuilder(
                          animation: _radarAnimController,
                          builder: (context, child) {
                            return Container(
                              width: 46 + (_radarAnimController.value * 16),
                              height: 46 + (_radarAnimController.value * 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withValues(
                                  alpha: (1.0 - _radarAnimController.value) * 0.4,
                                ),
                              ),
                            );
                          },
                        ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: state.isOnline ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          state.isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                          color: state.isOnline ? Colors.white : const Color(0xFF64748B),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isOnline ? 'CAPTAIN ON DUTY' : 'YOU ARE OFFLINE',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: state.isOnline ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.isOnline
                            ? 'Scanning high-demand 15km area'
                            : 'Go Online to receive instant orders',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              Transform.scale(
                scale: 1.15,
                child: Switch(
                  value: state.isOnline,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF10B981),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                  onChanged: (val) {
                    HapticFeedback.heavyImpact();
                    notifier.toggleOnline(val, context: context);
                    ref.read(jobStateProvider.notifier).toggleShift(val, context: context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Live GPS Location bar
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0F172A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.isFetchingLocation ? 'Locating partner GPS...' : cleanAddr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => notifier.fetchAndUpdateLocation(context: context, showPromptDialogs: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF0F172A)),
                      SizedBox(width: 4),
                      Text(
                        'Refresh GPS',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Active Running Job Card (Floating Rapido Banner) ─────────────────────
  Widget _buildActiveRunningJobCard(BuildContext context, DashboardState dashState, JobState jobState) {
    final activeJob = jobState.activeJob;
    if (activeJob == null || activeJob.status == TechJobStatus.completed) {
      return const SizedBox.shrink();
    }

    final title = activeJob.title;
    final customerName = activeJob.customerName;
    final address = formatCleanAddress(activeJob.customerAddress);
    final payout = '₹${activeJob.price.toStringAsFixed(0)}';
    final customerPhone = activeJob.customerPhone ?? '';

    String stepBadge = 'JOB IN PROGRESS';
    Color badgeColor = const Color(0xFF0F172A);
    Color badgeBg = const Color(0xFFFEFCE8);

    if (activeJob.status == TechJobStatus.accepted) {
      stepBadge = 'READY TO DISPATCH';
      badgeColor = const Color(0xFFB45309);
      badgeBg = const Color(0xFFFEF3C7);
    } else if (activeJob.status == TechJobStatus.onTheWay) {
      stepBadge = 'ON THE WAY TO LOCATION';
      badgeColor = const Color(0xFF0284C7);
      badgeBg = const Color(0xFFE0F2FE);
    } else if (activeJob.status == TechJobStatus.arrived) {
      stepBadge = 'ARRIVED • ENTER START OTP';
      badgeColor = const Color(0xFF15803D);
      badgeBg = const Color(0xFFDCFCE7);
    } else if (activeJob.status == TechJobStatus.serviceStarted) {
      stepBadge = 'SERVICE WORK UNDERWAY';
      badgeColor = const Color(0xFF16A34A);
      badgeBg = const Color(0xFFDCFCE7);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDB813), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDB813).withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  stepBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                payout,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(customerName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchMaps(address),
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (customerPhone.isNotEmpty) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.call, color: Color(0xFF16A34A), size: 20),
                    onPressed: () => _callCustomer(customerPhone, customerName),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailsPage(bookingId: activeJob.id),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: const Color(0xFFFDB813),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Open Console →', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. Daily Incentive Goal Progress Meter ──────────────────────────────────
  Widget _buildDailyIncentiveGoalCard(JobState jobState) {
    final completed = jobState.completedJobs.length;
    const target = 5;
    final progress = (completed / target).clamp(0.0, 1.0);
    final remaining = (target - completed).clamp(0, target);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE047)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    remaining > 0 ? 'Daily Milestone: Complete $remaining more' : '🎉 Daily Target Achieved!',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDB813),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+₹150 Bonus',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFFEF08A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completed / $target Trips Completed', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
              Text('${(progress * 100).toInt()}% Done', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. Performance & Earnings 4-Grid (Rapido Style) ─────────────────────────
  Widget _buildPerformanceMetricsGrid(DashboardState state, JobState jobState) {
    final earningsText = '₹${state.todayEarnings.toStringAsFixed(0)}';
    final completedCount = jobState.completedJobs.isNotEmpty
        ? jobState.completedJobs.length
        : state.completedJobsCount;
    final totalCount = jobState.todayJobs.length + completedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Shift Insights",
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Card 1: Today's Earnings
            Expanded(
              child: _buildMetricTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                title: "Earnings",
                value: earningsText,
                badgeText: "Instant UPI",
              ),
            ),
            const SizedBox(width: 10),
            // Card 2: Completed Orders
            Expanded(
              child: _buildMetricTile(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                title: "Jobs Done",
                value: '$completedCount / $totalCount',
                badgeText: "Target 8",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Card 3: Online Hours
            Expanded(
              child: _buildMetricTile(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                title: "Duty Hours",
                value: state.isOnline ? "Active" : "0.0 h",
                badgeText: "Shift",
              ),
            ),
            const SizedBox(width: 10),
            // Card 4: Acceptance Rate
            Expanded(
              child: _buildMetricTile(
                icon: Icons.verified_user_outlined,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                title: "Acceptance",
                value: "98.5%",
                badgeText: "VIP Tier",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              Text(
                badgeText,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  // ─── 6. Tier Membership Banner ──────────────────────────────────────────────
  Widget _buildTierMembershipBanner(BuildContext context) {
    final analyticsState = ref.watch(technicianAnalyticsProvider);
    final tierInfo = analyticsState.tierInfo;
    final currentTier = tierInfo?.tier ?? TechnicianTier.copper;

    List<Color> gradientColors;
    Color accentColor;
    String badgeTitle;
    String badgeEmoji;

    switch (currentTier) {
      case TechnicianTier.gold:
        gradientColors = const [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)];
        accentColor = const Color(0xFFFDE68A);
        badgeTitle = 'GOLD VIP CAPTAIN';
        badgeEmoji = '🥇';
        break;
      case TechnicianTier.silver:
        gradientColors = const [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B)];
        accentColor = const Color(0xFFE2E8F0);
        badgeTitle = 'SILVER PRO PARTNER';
        badgeEmoji = '🥈';
        break;
      case TechnicianTier.copper:
        gradientColors = const [Color(0xFF5C2C16), Color(0xFF804A26), Color(0xFFB87333)];
        accentColor = const Color(0xFFFFEDD5);
        badgeTitle = 'COPPER STARTER PASS';
        badgeEmoji = '🥉';
        break;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TechnicianAnalyticsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(badgeEmoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badgeTitle, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 2),
                  const Text('Reduced commission fee & daily bonus tier active', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  // ─── 7. Today's Scheduled Bookings (Real Data Only) ──────────────────────────
  Widget _buildTodayScheduleSection(BuildContext context, JobState jobState) {
    final todayJobs = jobState.todayJobs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Assigned Bookings (${todayJobs.length})",
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onNavigateTab?.call(1),
              child: const Text(
                'View All →',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (todayJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No scheduled jobs for today',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'New customer bookings within 15km will ring here automatically.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayJobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = todayJobs[index];
              return InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(jobStateProvider.notifier).acceptJob(
                        job.id,
                        job.title,
                        job.price,
                        job.customerName,
                        job.customerAddress,
                      );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsPage(bookingId: job.id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDB813), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: Color(0xFFB45309), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF0F172A)),
                                const SizedBox(width: 4),
                                Text(
                                  job.scheduleSlot ?? 'Standard Slot',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCleanAddress(job.customerAddress),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${job.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Open →',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFDB813)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
