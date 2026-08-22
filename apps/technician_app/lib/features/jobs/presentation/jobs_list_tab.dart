import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
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
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobStateProvider.notifier).fetchAssignedJobs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Bookings Log',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF1E3A8A),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Today (${jobState.todayJobs.length})'),
            Tab(text: 'Tomorrow (${jobState.tomorrowJobs.length})'),
            Tab(text: 'Day After (${jobState.nextDayJobs.length})'),
            Tab(text: 'History (${jobState.completedJobs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Today
          _buildJobsList(
            jobs: jobState.todayJobs,
            emptyTitle: 'No assigned jobs for Today',
            emptySubtitle: 'New 15km work requests will be automatically assigned to you when online.',
            isTodayTab: true,
          ),

          // Tab 2: Tomorrow
          _buildJobsList(
            jobs: jobState.tomorrowJobs,
            emptyTitle: 'No bookings for Tomorrow',
            emptySubtitle: 'Advance customer scheduled bookings for tomorrow will appear here.',
            isTodayTab: false,
          ),

          // Tab 3: Day After
          _buildJobsList(
            jobs: jobState.nextDayJobs,
            emptyTitle: 'No bookings for Day After',
            emptySubtitle: 'Advance bookings for upcoming days will be listed here.',
            isTodayTab: false,
          ),

          // Tab 4: History / Completed
          _buildJobsList(
            jobs: jobState.completedJobs,
            emptyTitle: 'No completed job history',
            emptySubtitle: 'Your completed work history and payout summaries will show here.',
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
      color: const Color(0xFF1E3A8A),
      onRefresh: () async {
        await ref.read(jobStateProvider.notifier).fetchAssignedJobs();
      },
      child: jobs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 38,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          emptyTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            emptySubtitle,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _buildJobCard(job, isTodayTab: isTodayTab, isHistoryTab: isHistoryTab);
              },
            ),
    );
  }

  Widget _buildJobCard(TechJob job, {bool isTodayTab = false, bool isHistoryTab = false}) {
    final statusColor = isHistoryTab
        ? const Color(0xFF059669)
        : isTodayTab
            ? const Color(0xFF1E3A8A)
            : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTodayTab ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          width: isTodayTab ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Booking Code + Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.bookingCode ?? 'BOOKING #${job.id.length > 6 ? job.id.substring(0, 6) : job.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  '₹${job.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Service Title
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Customer Name & Phone
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  job.customerName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                if (job.customerPhone != null && job.customerPhone!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${job.customerPhone})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_rounded, size: 15, color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    job.customerAddress,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Schedule Slot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 5),
                  Text(
                    'Slot: ${job.scheduleSlot ?? "Standard Window"}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
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
                  backgroundColor: isHistoryTab ? const Color(0xFF334155) : const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isHistoryTab ? Icons.receipt_long_rounded : Icons.navigation_rounded,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isHistoryTab
                          ? 'VIEW COMPLETED WORK SUMMARY'
                          : isTodayTab
                              ? 'TRACK & START TODAY WORK →'
                              : 'VIEW WORK DETAILS & SCHEDULE',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
