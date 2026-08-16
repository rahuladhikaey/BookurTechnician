import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/technician_banner.dart';
import 'dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardPage({super.key, this.onNavigateTab});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final PageController _bannerController;
  Timer? _autoSlideTimer;
  int _currentSlideIndex = 0;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!_isUserInteracting && _bannerController.hasClients) {
        final banners = ref.read(dashboardProvider).banners;
        if (banners.isNotEmpty) {
          final nextIndex = (_currentSlideIndex + 1) % banners.length;
          _bannerController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  void _pauseAutoSlideTemporarily() {
    setState(() => _isUserInteracting = true);
    _autoSlideTimer?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        _startAutoSlide();
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _handleBannerCta(TechnicianBanner banner) {
    final notifier = ref.read(dashboardProvider.notifier);
    switch (banner.targetType) {
      case 'ONLINE_TOGGLE':
        notifier.toggleOnline(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now ONLINE! Ready for new dispatches.')),
        );
        break;
      case 'JOBS':
        widget.onNavigateTab?.call(1); // Jobs tab
        break;
      case 'PERFORMANCE':
        widget.onNavigateTab?.call(4); // Profile / Performance tab
        break;
      case 'EARNINGS':
        widget.onNavigateTab?.call(2); // Earnings tab
        break;
      default:
        widget.onNavigateTab?.call(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. TOP HEADER ─────────────────────────────────────────────
              _buildTopHeader(context),
              const SizedBox(height: 16),

              // ─── 2. ONLINE / OFFLINE STATUS CARD ───────────────────────────
              _buildOnlineStatusCard(dashState, notifier),
              const SizedBox(height: 16),

              // ─── 3. 4-SLIDE RUNNING PROMOTIONAL BANNER ─────────────────────
              _buildPromotionalBannerCarousel(dashState),
              const SizedBox(height: 20),

              // ─── 4. TODAY'S SUMMARY ────────────────────────────────────────
              _buildTodaySummary(dashState),
              const SizedBox(height: 20),

              // ─── 5. NEW BOOKING REQUEST / ACTIVE JOB ───────────────────────
              if (dashState.isOnline && dashState.currentProposal != null && dashState.activeJob == null) ...[
                _buildNewBookingRequestCard(dashState, notifier),
                const SizedBox(height: 20),
              ],
              if (dashState.activeJob != null) ...[
                _buildActiveJobCard(dashState.activeJob!, notifier),
                const SizedBox(height: 20),
              ],

              // ─── 6. TODAY'S JOBS ───────────────────────────────────────────
              _buildTodayJobsSection(context),
              const SizedBox(height: 20),

              // ─── 7. EARNINGS ───────────────────────────────────────────────
              _buildEarningsCard(dashState),
              const SizedBox(height: 20),

              // ─── 8. PERFORMANCE ────────────────────────────────────────────
              _buildPerformanceCard(dashState),
              const SizedBox(height: 20),

              // ─── 9. QUICK ACTIONS ──────────────────────────────────────────
              _buildQuickActionsGrid(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Top Header ─────────────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Good Morning, Rahul 👋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B1635),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3),
            Text(
              'AC & Electrical Technician',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    icon: const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF0B1635)),
                    onPressed: () => widget.onNavigateTab?.call(3), // Notifications Tab
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => widget.onNavigateTab?.call(4), // Profile Tab
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF17399A), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=100'),
                  backgroundColor: Color(0xFFE8EEFF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 2. Online / Offline Status Card ───────────────────────────────────────
  Widget _buildOnlineStatusCard(DashboardState state, DashboardNotifier notifier) {
    final isOnline = state.isOnline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline ? const Color(0xFF16A34A).withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
          width: isOnline ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOnline
                ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  boxShadow: [
                    if (isOnline)
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isOnline ? "You're Online" : "You're Offline",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1635),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOnline
                ? 'You are available for new bookings'
                : "You won't receive new booking requests",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF667085),
            ),
          ),
          if (isOnline) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD9E2F2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 15, color: Color(0xFF2146A8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.isFetchingLocation
                          ? 'Acquiring real-time GPS location...'
                          : 'Live GPS: ${state.currentLocationAddress}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17357F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.isFetchingLocation)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2146A8)),
                    )
                  else
                    InkWell(
                      onTap: () => notifier.fetchAndUpdateLocation(),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.refresh, size: 15, color: Color(0xFF2146A8)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => notifier.toggleOnline(!isOnline),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnline ? const Color(0xFFDC2626) : const Color(0xFF2146A8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. 4-Slide Running Promotional Carousel ──────────────────────────────
  Widget _buildPromotionalBannerCarousel(DashboardState state) {
    final banners = state.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Listener(
          onPointerDown: (_) => _pauseAutoSlideTemporarily(),
          child: SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _currentSlideIndex = index);
              },
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _buildBannerSlideItem(banner);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Pagination Dots Indicator (● ○ ○ ○)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (index) {
            final isActive = index == _currentSlideIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF17399A) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerSlideItem(TechnicianBanner banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF17399A),
                ),
              ),
            ),
            // Premium Gradient Overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
            // Text & CTA content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    banner.subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _handleBannerCta(banner),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17399A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            banner.ctaText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
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

  // ─── 4. Today's Summary ───────────────────────────────────────────────────
  Widget _buildTodaySummary(DashboardState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Summary",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B1635),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildSummaryCard(
                title: "Today's Jobs",
                value: '${state.todayJobsCount}',
                icon: Icons.work_outline,
                iconColor: const Color(0xFF17399A),
                bgColor: const Color(0xFFE8EEFF),
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                title: "Today's Earnings",
                value: '₹${state.todayEarnings.toStringAsFixed(0)}',
                icon: Icons.currency_rupee,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                title: 'Completed',
                value: '${state.completedJobsCount}',
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                title: 'Rating',
                value: '${state.rating} ⭐',
                icon: Icons.star_outline,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0B1635)),
          ),
        ],
      ),
    );
  }

  // ─── 5. New Booking Request Card ──────────────────────────────────────────
  Widget _buildNewBookingRequestCard(DashboardState state, DashboardNotifier notifier) {
    final proposal = state.currentProposal!;
    final countdown = state.proposalCountdown;
    final progress = (countdown / 25).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 16,
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
              const Row(
                children: [
                  Icon(Icons.notifications_active, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '🔔 New Service Request',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B1635),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${countdown}s left',
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFFEF3C7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                proposal.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1635),
                ),
              ),
              Text(
                '₹${proposal.estimatedEarning.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Customer: ${proposal.customerName}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0B1635)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF667085)),
              const SizedBox(width: 4),
              Text(
                '📍 ${proposal.distanceKm} km away • Est. ${proposal.travelMinutes} min',
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.rejectProposal(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => notifier.acceptProposal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ACCEPT JOB', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 6. Active Job Card ───────────────────────────────────────────────────
  Widget _buildActiveJobCard(ActiveJobModel job, DashboardNotifier notifier) {
    String stepLabel = 'Accepted';
    String nextButtonLabel = 'START JOURNEY';
    ActiveJobStep nextStep = ActiveJobStep.onTheWay;

    switch (job.step) {
      case ActiveJobStep.accepted:
        stepLabel = 'Accepted • Ready to depart';
        nextButtonLabel = 'START JOURNEY';
        nextStep = ActiveJobStep.onTheWay;
        break;
      case ActiveJobStep.onTheWay:
        stepLabel = 'Heading to customer';
        nextButtonLabel = 'ARRIVED AT LOCATION';
        nextStep = ActiveJobStep.arrived;
        break;
      case ActiveJobStep.arrived:
        stepLabel = 'Arrived at Doorstep';
        nextButtonLabel = 'START SERVICE';
        nextStep = ActiveJobStep.serviceStarted;
        break;
      case ActiveJobStep.serviceStarted:
        stepLabel = 'Service in progress 🛠️';
        nextButtonLabel = 'COMPLETE SERVICE';
        nextStep = ActiveJobStep.completed;
        break;
      case ActiveJobStep.completed:
        stepLabel = 'Completed';
        nextButtonLabel = 'DONE';
        nextStep = ActiveJobStep.completed;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF17399A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17399A).withValues(alpha: 0.1),
            blurRadius: 16,
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
                  color: const Color(0xFFE8EEFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE SERVICE',
                  style: TextStyle(
                    color: Color(0xFF17399A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '₹${job.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0B1635)),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer: ${job.customerName}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0B1635)),
          ),
          const SizedBox(height: 2),
          Text(
            '📍 Customer Location: ${job.distanceKm} km • ${job.travelMinutes} min away',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Status: $stepLabel',
              style: const TextStyle(
                color: Color(0xFF166534),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 3 Action Buttons: NAVIGATE, CALL, CHAT
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening GPS Navigation...')),
                    );
                  },
                  icon: const Icon(Icons.navigation, size: 14),
                  label: const Text('NAVIGATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF17399A),
                    side: const BorderSide(color: Color(0xFF17399A)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Privacy Masked Calling'),
                        content: Text('Connecting to ${job.customerName} via secure relay...'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('CALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening in-app customer chat...')),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('CHAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF667085),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => notifier.updateActiveJobStep(nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF17399A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                nextButtonLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. Today's Jobs Section ──────────────────────────────────────────────
  Widget _buildTodayJobsSection(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Jobs",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B1635),
                letterSpacing: -0.2,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onNavigateTab?.call(1), // Jobs Tab
              child: const Text(
                'View All →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17399A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        state.activeJob != null
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.build, color: Color(0xFF17399A), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.activeJob!.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B1635)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${state.activeJob!.customerName} • Today',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${state.activeJob!.customerAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${state.activeJob!.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF17399A)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'In Progress',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Text(
                    'No active bookings scheduled for today',
                    style: TextStyle(fontSize: 13, color: Color(0xFF667085), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
      ],
    );
  }

  // ─── 8. Earnings Card ─────────────────────────────────────────────────────
  Widget _buildEarningsCard(DashboardState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1F63), Color(0xFF17399A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17399A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Earnings',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'This Week',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${state.weeklyEarnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEarningsMetric('Completed Jobs', '${state.weeklyCompletedJobs}'),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildEarningsMetric('Platform Fee', '₹${state.platformFee.toStringAsFixed(0)}'),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildEarningsMetric('Net Earnings', '₹${state.netEarnings.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => widget.onNavigateTab?.call(2), // Earnings Tab
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Earnings →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // ─── 9. Performance Card ──────────────────────────────────────────────────
  Widget _buildPerformanceCard(DashboardState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              const Text(
                'Your Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1635),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⭐ ${state.rating} Rating',
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPerformanceBar(
            label: 'Acceptance Rate',
            percentage: state.acceptanceRate,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 12),
          _buildPerformanceBar(
            label: 'Completion Rate',
            percentage: state.completionRate,
            color: const Color(0xFF17399A),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF16A34A), size: 16),
              const SizedBox(width: 6),
              Text(
                '${state.weeklyCompletedJobs} Jobs Completed Successfully',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B1635),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar({
    required String label,
    required double percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0B1635)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ─── 10. Quick Actions Grid ───────────────────────────────────────────────
  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B1635),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildQuickActionTile(
              title: 'My Jobs',
              subtitle: 'Active & history',
              icon: Icons.work_outline,
              color: const Color(0xFF17399A),
              onTap: () => widget.onNavigateTab?.call(1),
            ),
            _buildQuickActionTile(
              title: 'Earnings',
              subtitle: 'Payouts & tips',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF16A34A),
              onTap: () => widget.onNavigateTab?.call(2),
            ),
            _buildQuickActionTile(
              title: 'Availability',
              subtitle: 'Duty shifts & leaves',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () => widget.onNavigateTab?.call(4),
            ),
            _buildQuickActionTile(
              title: 'Support',
              subtitle: 'Safety cell & help',
              icon: Icons.headset_mic_outlined,
              color: const Color(0xFF6366F1),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Partner Support helpline: +91 98765 43210')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1635)),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF667085)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
