import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import 'dashboard_provider.dart';
import 'notifications_tab.dart';
import 'my_skills_page.dart';
import 'job_execution_screen.dart';

import '../../jobs/presentation/states/job_state.dart';
import '../../jobs/presentation/job_details_page.dart';

class PartnerHomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const PartnerHomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends ConsumerState<PartnerHomeScreen> {
  final SkillService _skillService = SkillService();
  TechnicianSkillProfileModel? _skillProfile;

  @override
  void initState() {
    super.initState();
    _fetchSkillProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).fetchAndUpdateLocation(context: context, showPromptDialogs: false);
      ref.read(jobStateProvider.notifier).fetchAssignedJobs();
    });
  }

  Future<void> _fetchSkillProfile() async {
    final profile = await _skillService.fetchMySkillProfile();
    if (mounted && profile != null) {
      setState(() {
        _skillProfile = profile;
      });
    }
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
            SnackBar(content: Text('Calling $name at $phone (Masked Relay)')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $name at $phone (Masked Relay)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final dashNotifier = ref.read(dashboardProvider.notifier);

    final technicianName = (authState.fullName != null && authState.fullName!.isNotEmpty)
        ? authState.fullName!
        : 'Rahul';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1E3A8A),
          onRefresh: () async {
            await dashNotifier.fetchAndUpdateLocation();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. TOP HERO AUTO-SCROLL BANNER (HELLO TECH & REAL GPS) ──
                _PartnerHeroAutoScrollBanner(
                  technicianName: technicianName,
                  skillProfile: _skillProfile,
                  dashState: dashState,
                  dashNotifier: dashNotifier,
                  onProfileTap: () => widget.onNavigateTab?.call(3),
                  onNotificationTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsTab()),
                    );
                  },
                  onSkillsTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MySkillsPage()),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // ─── 2. METRICS & PERFORMANCE SNAPSHOT (2-Column Card Row) ───
                _buildMetricsSnapshotRow(dashState),
                const SizedBox(height: 18),

                // ─── 3. IN-PROGRESS / ACTIVE JOB CARD ────────────────────────
                _buildActiveJobCard(context, dashState, dashNotifier),
                const SizedBox(height: 20),

                // ─── 4. AUTO-SCROLL INCENTIVE & SPOTLIGHT BOOSTER CAROUSEL ───
                const _PartnerSpotlightIncentiveCarousel(),
                const SizedBox(height: 22),

                // ─── 5. TODAY'S SCHEDULE (Upcoming Jobs List) ────────────────
                _buildTodayScheduleSection(context, dashNotifier),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 2. Metrics & Performance Snapshot (2-Column Row) ──────────────────────
  Widget _buildMetricsSnapshotRow(DashboardState state) {
    final earningsText = '₹${state.todayEarnings.toStringAsFixed(0)}';
    final jobsDoneText = '${state.completedJobsCount} / ${state.todayJobsCount > 0 ? state.todayJobsCount : 0}';

    return Row(
      children: [
        // Card 1: "Today's Earnings" with wallet icon and value "₹1,850"
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '+18%',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Today's Earnings",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  earningsText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Card 2: "Jobs Done" with completion check icon and value "3 / 5"
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.task_alt_rounded,
                        size: 20,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Target 5',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Jobs Done",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  jobsDoneText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 4. In-Progress / Active Job Card ──────────────────────────────────────
  Widget _buildActiveJobCard(BuildContext context, DashboardState state, DashboardNotifier notifier) {
    final activeJob = state.activeJob;

    if (activeJob == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: state.isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: state.isOnline ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                state.isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                color: state.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              state.isOnline ? 'Active Radar: Waiting for Requests' : 'You are currently Offline',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.isOnline
                  ? 'High-priority leads within 15 km will ring loudly here.'
                  : 'Toggle the switch above to go online and receive service leads.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final title = activeJob.title;
    final customerName = activeJob.customerName;
    final customerAddress = activeJob.customerAddress;
    final payout = '₹${activeJob.price.toStringAsFixed(0)}';
    final customerPhone = activeJob.customerPhone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "IN PROGRESS" chip and payout amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 4),
                    Text(
                      'IN PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payout,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title: Service Name
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Customer details: Customer name and location with distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_pin_circle_outlined,
                size: 18,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Navigate Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchMaps(customerAddress),
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Call icon button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.call, color: Color(0xFF059669), size: 20),
                  onPressed: () => _callCustomer(customerPhone, customerName),
                ),
              ),
              const SizedBox(width: 8),

              // Start Job button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobExecutionScreen(
                          job: {
                            'id': activeJob.id,
                            'title': title,
                            'customerName': customerName,
                            'address': customerAddress,
                            'customerPhone': customerPhone,
                            'payout': payout,
                            'timeSlot': '1 Hour Service Window',
                            'status': 'ACCEPTED',
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Start Job',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. Today's Schedule (Upcoming Jobs List) ──────────────────────────────
  Widget _buildTodayScheduleSection(BuildContext context, DashboardNotifier notifier) {
    final jobState = ref.watch(jobStateProvider);
    final todayJobs = jobState.todayJobs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Schedule (${todayJobs.length})",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                widget.onNavigateTab?.call(1); // Navigate to Bookings tab
              },
              child: const Text(
                'View All →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No scheduled jobs for today',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'New customer bookings within 15km will be assigned automatically.',
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
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Service Icon Box
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.build_circle_outlined,
                          color: Color(0xFF1E3A8A),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Middle Content: Title, Time slot, Address snippet
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: Color(0xFF1E3A8A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  job.scheduleSlot ?? 'Standard Slot',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              job.customerAddress,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Expected Payout aligned to the right + Start Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${job.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Start →',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A),
                              ),
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

// ─── TOP HERO AUTO-SCROLL BANNER WIDGET ──────────────────────────────────────
class _PartnerHeroAutoScrollBanner extends StatefulWidget {
  final String technicianName;
  final TechnicianSkillProfileModel? skillProfile;
  final DashboardState dashState;
  final DashboardNotifier dashNotifier;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSkillsTap;

  const _PartnerHeroAutoScrollBanner({
    required this.technicianName,
    required this.skillProfile,
    required this.dashState,
    required this.dashNotifier,
    this.onProfileTap,
    this.onNotificationTap,
    this.onSkillsTap,
  });

  @override
  State<_PartnerHeroAutoScrollBanner> createState() => _PartnerHeroAutoScrollBannerState();
}

class _PartnerHeroAutoScrollBannerState extends State<_PartnerHeroAutoScrollBanner> {
  late PageController _pageController;
  int _currentIndex = 1000;
  Timer? _timer;

  static const List<String> _heroImages = [
    'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=1000&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=1000&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=1000&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _timer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.dashState;
    final addressText = state.currentLocationAddress.isNotEmpty
        ? state.currentLocationAddress
        : 'Bengaluru Central, Karnataka';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 1. Auto-scrolling background image carousel
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final imgUrl = _heroImages[index % _heroImages.length];
                  return Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
                  );
                },
              ),
            ),

            // 2. Multi-stop Gradient Scrim Overlay for crisp text contrast
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xF20F172A),
                      Color(0xAA0F172A),
                      Color(0xF80F172A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Foreground Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar, Hello Technician, Rating & Notification Bell
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onProfileTap,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Center(
                                      child: Icon(Icons.person_rounded, size: 28, color: Colors.white),
                                    ),
                                  ),
                                ),
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
                                          'Hello, ${widget.technicianName}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('👋', style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 3),
                                      Text(
                                        (widget.skillProfile != null && widget.skillProfile!.totalRatingsCount > 0)
                                            ? widget.skillProfile!.rating.toStringAsFixed(1)
                                            : '4.9',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${widget.skillProfile?.totalRatingsCount ?? 142} reviews)',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: widget.onSkillsTap,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            '${widget.skillProfile?.verifiedSkillsCount ?? 5} Verified Skills',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF34D399),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notification Bell Icon
                      GestureDetector(
                        onTap: widget.onNotificationTap,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Center(
                            child: Icon(Icons.notifications_outlined, size: 21, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Floating GPS Location Pill Overlay
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REAL-TIME GPS LOCATION',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF38BDF8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                addressText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF38BDF8)),
                          onPressed: () => widget.dashNotifier.fetchAndUpdateLocation(context: context, showPromptDialogs: true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Duty Online / Offline Switch Row with Glowing Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: state.isOnline
                          ? const Color(0x2210B981)
                          : const Color(0x22EF4444),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: state.isOnline
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                boxShadow: state.isOnline ? const [
                                  BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1)
                                ] : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.isOnline ? 'ONLINE & ACCEPTING JOBS' : 'OFFLINE (ON BREAK)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: state.isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: state.isOnline,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF10B981),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFEF4444),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) => widget.dashNotifier.toggleOnline(val, context: context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Dots Indicator
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_heroImages.length, (i) {
                        final isSel = (i == _currentIndex % _heroImages.length);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isSel ? 18 : 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SPOTLIGHT INCENTIVE & SAFETY AUTO-SCROLL CAROUSEL ────────────────────────
class _PartnerSpotlightIncentiveCarousel extends StatefulWidget {
  const _PartnerSpotlightIncentiveCarousel();

  @override
  State<_PartnerSpotlightIncentiveCarousel> createState() => _PartnerSpotlightIncentiveCarouselState();
}

class _PartnerSpotlightIncentiveCarouselState extends State<_PartnerSpotlightIncentiveCarousel> {
  late PageController _pageController;
  int _currentIndex = 1000;
  Timer? _timer;

  static const List<Map<String, dynamic>> _incentiveCards = [
    {
      'tag': '⚡ DAILY INCENTIVE',
      'title': 'Complete 3 Jobs Today',
      'subtitle': 'Unlock an extra ₹500 performance bonus directly to your wallet!',
      'gradient': [Color(0xFF4338CA), Color(0xFF312E81)],
      'icon': '🎁',
      'accent': Color(0xFFA5B4FC),
    },
    {
      'tag': '🛡️ SAFETY PROTOCOL',
      'title': 'Dual-OTP Verification',
      'subtitle': 'Always collect the 4-digit start OTP from customer before opening your tool bag.',
      'gradient': [Color(0xFF0F766E), Color(0xFF134E4A)],
      'icon': '🔐',
      'accent': Color(0xFF5EEAD4),
    },
    {
      'tag': '💰 100% INSTANT PAYOUT',
      'title': 'Zero Commission UPI Payouts',
      'subtitle': 'Your job payouts are settled instantly to your bank account daily.',
      'gradient': [Color(0xFFB45309), Color(0xFF78350F)],
      'icon': '⚡',
      'accent': Color(0xFFFDE68A),
    },
    {
      'tag': '⭐ PLATINUM PARTNER',
      'title': 'Maintain 4.8+ Rating',
      'subtitle': 'Top-rated technicians get priority booking dispatch in a 15km radius.',
      'gradient': [Color(0xFF1E3A8A), Color(0xFF172554)],
      'icon': '🏆',
      'accent': Color(0xFF93C5FD),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _timer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final card = _incentiveCards[index % _incentiveCards.length];
              final gradient = card['gradient'] as List<Color>;
              final accentColor = card['accent'] as Color;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              card['tag'] as String,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            card['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            card['subtitle'] as String,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      card['icon'] as String,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_incentiveCards.length, (i) {
            final isSel = (i == _currentIndex % _incentiveCards.length);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSel ? 16 : 5,
              height: 4.5,
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
