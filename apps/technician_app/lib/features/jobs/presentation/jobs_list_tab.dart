import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/semantic_colors.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getJobsForStatus(String tabName) {
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobStateProvider);
    final activeJob = jobState.activeJob;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings Log'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // tab 1: Active
          _buildActiveTab(activeJob),

          // tab 2: Upcoming
          _buildStaticListTab('Upcoming'),

          // tab 3: Completed
          _buildStaticListTab('Completed'),

          // tab 4: Cancelled
          _buildStaticListTab('Cancelled'),
        ],
      ),
    );
  }

  Widget _buildActiveTab(TechJob? activeJob) {
    if (activeJob == null || activeJob.status == TechJobStatus.completed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_history, size: 64, color: AppColors.textSecondary),
              SizedBox(height: AppSpacing.s),
              Text(
                'No active accepted job in progress.',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              SizedBox(height: AppSpacing.xxs),
              Text(
                'Switch your availability to ONLINE on the Home screen to receive new job dispatch proposals.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.round,
                    ),
                    child: Text(
                      'ACTIVE: ${activeJob.status.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Text(
                    '₹${activeJob.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SemanticColors.success),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(activeJob.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Customer: ${activeJob.customerName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Address: ${activeJob.customerAddress}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.m),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsPage(bookingId: activeJob.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
                ),
                child: const Text('TRACK ACTIVE JOB TIMELINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticListTab(String tabName) {
    final jobs = _getJobsForStatus(tabName);
    if (jobs.isEmpty) {
      return const Center(child: Text('No bookings in this category.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.s),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ID: ${job['id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    Text(
                      '₹${job['price'].toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(job['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Client: ${job['customerName']}', style: const TextStyle(fontSize: 12)),
                Text('Address: ${job['customerAddress']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scheduled: ${job['date']} | ${job['timeSlot']}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (tabName == 'Upcoming')
                      ElevatedButton(
                        onPressed: () {
                          ref.read(jobStateProvider.notifier).acceptJob(
                            job['id'],
                            job['title'],
                            job['price'],
                            job['customerName'],
                            job['customerAddress'],
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Accepted Job #${job['id']}! Navigate from Home tab.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SemanticColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Start Work', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
