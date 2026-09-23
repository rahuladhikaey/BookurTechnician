import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/job.dart';
import 'states/job_state.dart';
import 'job_details_page.dart';

class JobsListTab extends ConsumerStatefulWidget {
  const JobsListTab({super.key});

  @override
  ConsumerState<JobsListTab> createState() => _JobsListTabState();
}

class _JobsListTabState extends ConsumerState<JobsListTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobStateProvider.notifier).fetchAssignedJobs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openNavigation(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobStateProvider);

    // Combine scheduled upcoming jobs (tomorrow + next days)
    final upcomingJobs = [...jobState.tomorrowJobs, ...jobState.nextDayJobs];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB813),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CAPTAIN',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'My Bookings Log',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Refresh Bookings',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(jobStateProvider.notifier).fetchAssignedJobs();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFDB813),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDB813).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                tabs: [
                  Tab(text: 'Today (${jobState.todayJobs.length})'),
                  Tab(text: 'Upcoming (${upcomingJobs.length})'),
                  Tab(text: 'History (${jobState.completedJobs.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Today / Active
          _buildJobsList(
            jobs: jobState.todayJobs,
            emptyTitle: 'No Active Bookings Today',
            emptySubtitle: 'Stay Online with GPS active. New nearby customer orders within 15 km will ring directly on your screen.',
            isTodayTab: true,
          ),

          // Tab 2: Upcoming / Scheduled
          _buildJobsList(
            jobs: upcomingJobs,
            emptyTitle: 'No Scheduled Bookings',
            emptySubtitle: 'Advance customer scheduled bookings for upcoming time windows will be reserved for you here.',
            isTodayTab: false,
          ),

          // Tab 3: History / Completed
          _buildJobsList(
            jobs: jobState.completedJobs,
            emptyTitle: 'No Completed Bookings Yet',
            emptySubtitle: 'Once you fulfill customer orders and verify OTPs, your completed earnings records will appear here.',
            isTodayTab: false,
            isHistoryTab: true,
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList({
    required List<TechJob> jobs,
    required String emptyTitle,
    required String emptySubtitle,
    bool isTodayTab = false,
    bool isHistoryTab = false,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFFDB813),
      onRefresh: () async {
        await ref.read(jobStateProvider.notifier).fetchAssignedJobs();
      },
      child: jobs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isHistoryTab
                                ? Icons.receipt_long_rounded
                                : isTodayTab
                                    ? Icons.bolt_rounded
                                    : Icons.event_available_rounded,
                            size: 44,
                            color: isHistoryTab
                                ? const Color(0xFF64748B)
                                : isTodayTab
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          emptyTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emptySubtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _buildRapidoJobCard(job, isTodayTab: isTodayTab, isHistoryTab: isHistoryTab);
              },
            ),
    );
  }

  Widget _buildRapidoJobCard(TechJob job, {bool isTodayTab = false, bool isHistoryTab = false}) {
    final bookingCode = job.bookingCode ??
        'BT-${job.id.length > 6 ? job.id.substring(job.id.length - 6).toUpperCase() : job.id.toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTodayTab ? const Color(0xFFFDB813) : const Color(0xFFE2E8F0),
          width: isTodayTab ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isTodayTab
                ? const Color(0xFFFDB813).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Booking Code + Live Status + Price ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isHistoryTab
                  ? const Color(0xFFF8FAFC)
                  : isTodayTab
                      ? const Color(0xFFFEFCE8)
                      : const Color(0xFFF0FDF4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bookingCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDB813),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isHistoryTab
                            ? const Color(0xFFE2E8F0)
                            : isTodayTab
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isHistoryTab ? 'COMPLETED' : (isTodayTab ? '⚡ ACTIVE NOW' : 'SCHEDULED'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isHistoryTab
                              ? const Color(0xFF475569)
                              : isTodayTab
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${job.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),

          // ─── Body: Service Title & Customer Info ──────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Customer Row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 18, color: Color(0xFFFDB813)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.customerName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            job.customerPhone != null && job.customerPhone!.isNotEmpty
                                ? job.customerPhone!
                                : 'Verified Customer',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (job.customerPhone != null && job.customerPhone!.isNotEmpty)
                      InkWell(
                        onTap: () => _makeCall(job.customerPhone),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.call, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'CALL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location / Address Row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job.customerAddress.isNotEmpty ? job.customerAddress : 'Customer Premise Address',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _openNavigation(job.customerAddress),
                        child: const Icon(Icons.directions_rounded, size: 20, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Slot pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 5),
                        Text(
                          'Slot: ${job.scheduleSlot ?? "Standard Window"}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if (job.distanceKm != null && job.distanceKm! > 0)
                      Text(
                        '~${job.distanceKm!.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── Primary Action Button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHistoryTab
                          ? const Color(0xFF0F172A)
                          : isTodayTab
                              ? const Color(0xFFFDB813)
                              : const Color(0xFF0F172A),
                      foregroundColor: isTodayTab && !isHistoryTab ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isHistoryTab
                              ? Icons.receipt_long_rounded
                              : isTodayTab
                                  ? Icons.navigation_rounded
                                  : Icons.calendar_month_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHistoryTab
                              ? 'VIEW WORK SUMMARY & RECEIPT'
                              : isTodayTab
                                  ? 'NAVIGATE & START WORK →'
                                  : 'VIEW SCHEDULE & DETAILS',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
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
    );
  }
}
