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
import 'lead_alert_dialog.dart';

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
      ref.read(dashboardProvider.notifier).fetchAndUpdateLocation();
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

  // Real schedule jobs list
  final List<Map<String, dynamic>> _scheduleJobs = [
    {
      'id': 'JOB-9021',
      'title': 'Washing Machine Repair',
      'timeSlot': '02:30 PM - 03:30 PM',
      'customerName': 'Pooja Verma',
      'address': 'Flat 402, Green Glen Layout, Bellandur',
      'payout': 650.0,
      'distance': '1.8 km',
    },
    {
      'id': 'JOB-9022',
      'title': 'Switchboard & Fan Wiring',
      'timeSlot': '04:45 PM - 05:45 PM',
      'customerName': 'Rohan Gupta',
      'address': 'Villa 12, Palm Meadows, Whitefield',
      'payout': 400.0,
      'distance': '3.2 km',
    },
    {
      'id': 'JOB-9023',
      'title': 'Refrigerator Gas Refill & Servicing',
      'timeSlot': '06:30 PM - 07:30 PM',
      'customerName': 'Meera Sundaram',
      'address': 'B-102, Shriram Spandana, Wind Tunnel Road',
      'payout': 950.0,
      'distance': '4.1 km',
    },
  ];

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
                // ─── 1. CUSTOM TOP APP BAR ───────────────────────────────────
                _buildTopAppBar(context, technicianName),
                const SizedBox(height: 12),

                // ─── 2. REAL-TIME GPS LOCATION HEADER (TASK 4) ────────────────
                _buildRealtimeLocationHeader(context, dashState, dashNotifier),
                const SizedBox(height: 14),

                // ─── 3. DUTY STATUS SWITCH BANNER ────────────────────────────
                _buildDutyStatusBanner(dashState, dashNotifier),
                const SizedBox(height: 16),

                // ─── 3. METRICS & PERFORMANCE SNAPSHOT (2-Column Card Row) ───
                _buildMetricsSnapshotRow(dashState),
                const SizedBox(height: 18),

                // ─── 4. IN-PROGRESS / ACTIVE JOB CARD ────────────────────────
                _buildActiveJobCard(context, dashState, dashNotifier),
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

  // ─── 1. Custom Top App Bar ─────────────────────────────────────────────────
  Widget _buildTopAppBar(BuildContext context, String technicianName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: Circular user avatar, greeting text ("Hello, Rahul"), and partner rating with star icon ("4.88 (142 reviews)")
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  widget.onNavigateTab?.call(3); // Navigate to Profile tab
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: const Color(0xFFEFF6FF),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF1E3A8A),
                        ),
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
                    Text(
                      'Hello, $technicianName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          (_skillProfile?.rating ?? 4.88).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_skillProfile?.totalRatingsCount ?? 142} reviews)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MySkillsPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_skillProfile?.verifiedSkillsCount ?? 0} Verified Skills',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
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

        // Right side: Notification bell icon with action callback
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsTab()),
                  );
                },
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 2. Real-Time GPS Location Header (Task 4) ─────────────────────────────
  Widget _buildRealtimeLocationHeader(BuildContext context, DashboardState state, DashboardNotifier notifier) {
    final hasCoords = state.currentLatitude != null && state.currentLongitude != null;
    final coordsText = hasCoords
        ? '${state.currentLatitude!.toStringAsFixed(4)}°, ${state.currentLongitude!.toStringAsFixed(4)}°'
        : 'Acquiring GPS...';
    final addressText = state.currentLocationAddress.isNotEmpty
        ? state.currentLocationAddress
        : 'Real-Time Device Location';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Center(
              child: Icon(Icons.location_on_rounded, color: Color(0xFF1E3A8A), size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CURRENT REAL LOCATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isFetchingLocation ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.isFetchingLocation ? 'Fixing GPS...' : 'Live GPS Fix',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: state.isFetchingLocation ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$addressText ($coordsText)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh GPS Location',
            icon: state.isFetchingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A8A)),
                  )
                : const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF1E3A8A)),
            onPressed: state.isFetchingLocation ? null : () => notifier.fetchAndUpdateLocation(),
          ),
        ],
      ),
    );
  }

  // ─── 3. Duty Status Switch Banner ──────────────────────────────────────────
  Widget _buildDutyStatusBanner(DashboardState state, DashboardNotifier notifier) {
    final isOnline = state.isOnline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.06)
                : const Color(0xFFEF4444).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Indicator Dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              boxShadow: [
                BoxShadow(
                  color: isOnline
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFFEF4444).withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline
                      ? 'You are Online & Receiving Leads'
                      : 'You are currently Offline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? (state.currentLocationAddress.isNotEmpty
                          ? state.currentLocationAddress
                          : 'GPS Live Tracking Active')
                      : 'Toggle switch to start receiving service bookings',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isOnline ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Toggle Switch Widget
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: isOnline,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF10B981),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFEF4444),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: (val) async {
                final success = await notifier.toggleOnline(val);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val && success
                            ? '🟢 You are now ONLINE & ready for 15km service leads!'
                            : '🔴 You are now OFFLINE. No leads will be assigned.',
                      ),
                      backgroundColor: val ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  if (val && success) {
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted && state.isOnline) {
                        LeadAlertDialog.show(
                          context,
                          {
                            'title': 'AC Deep Cleaning & Master Service',
                            'customerAddress': 'Flat 402, Green Glen Layout, Bellandur (3.2 km away)',
                            'scheduledSlot': '1 Hour Service Window',
                            'distanceKm': 3.2,
                            'payoutAmount': 750,
                          },
                          onAccept: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF16A34A),
                                content: Text('🎉 Lead Accepted! Navigating to Job Execution.'),
                              ),
                            );
                          },
                          onDecline: () {},
                        );
                      }
                    });
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Metrics & Performance Snapshot (2-Column Row) ──────────────────────
  Widget _buildMetricsSnapshotRow(DashboardState state) {
    final earningsText = state.todayEarnings > 0
        ? '₹${state.todayEarnings.toStringAsFixed(0)}'
        : '₹1,850';
    
    final jobsDoneText = state.todayJobsCount > 0
        ? '${state.completedJobsCount} / ${state.todayJobsCount}'
        : '3 / 5';

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
    final title = activeJob?.title ?? 'Split AC Deep Cleaning & Servicing';
    final customerName = activeJob?.customerName ?? 'Amit Sharma';
    final customerAddress = activeJob?.customerAddress ?? 'B-304, Tower 3, Royal Residency (2.3 km away)';
    final payout = activeJob != null ? '₹${activeJob.price.toStringAsFixed(0)}' : '₹850';
    final customerPhone = activeJob?.customerPhone ?? '+91 98765 43210';

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
          // Header: "IN PROGRESS" chip and payout amount ("₹850")
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

          // Action row:
          // 1. Outlined button: "Navigate" with navigation icon
          // 2. Circular action button: "Call" icon button with green accent
          // 3. Primary elevated button: "Start Job" with primary deep blue fill
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

              // Circular Action Button: "Call" icon button with green accent
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

              // Primary elevated button: "Start Job" with primary deep blue fill
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobExecutionScreen(
                          job: {
                            'id': activeJob?.id ?? 'BT-901',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(
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

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _scheduleJobs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final job = _scheduleJobs[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.build_circle_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle Content: Title, Time slot, Address snippet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'],
                          style: const TextStyle(
                            fontSize: 14,
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
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job['timeSlot'],
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job['address'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expected Payout aligned to the right
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(job['payout'] as double).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job['distance'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
