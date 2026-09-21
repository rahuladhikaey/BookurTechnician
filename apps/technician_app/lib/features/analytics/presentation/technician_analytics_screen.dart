import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'technician_analytics_provider.dart';
import 'widgets/technician_tier_card.dart';
import 'widgets/analytics_dual_chart.dart';

class TechnicianAnalyticsScreen extends ConsumerStatefulWidget {
  const TechnicianAnalyticsScreen({super.key});

  @override
  ConsumerState<TechnicianAnalyticsScreen> createState() => _TechnicianAnalyticsScreenState();
}

class _TechnicianAnalyticsScreenState extends ConsumerState<TechnicianAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(technicianAnalyticsProvider.notifier).loadData();
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 7)),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(technicianAnalyticsProvider.notifier).setCustomDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(technicianAnalyticsProvider);
    final notifier = ref.read(technicianAnalyticsProvider.notifier);
    final tier = state.tierInfo;
    final overview = state.overview;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Income & Work Hours Analytics',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'Refresh Data',
            onPressed: () => notifier.loadData(silent: false),
          ),
        ],
      ),
      body: state.isLoading && overview == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : RefreshIndicator(
              color: const Color(0xFF1E3A8A),
              onRefresh: () => notifier.loadData(silent: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── 1. MEMBERSHIP TIER CARD (COPPER / SILVER / GOLD) ───
                    if (tier != null)
                      TechnicianTierCard(tierInfo: tier)
                    else
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ─── 2. TIME RANGE FILTER SELECTOR ─────────────────────
                    const Text(
                      'Select Analytics Timeframe',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Today', 'today', state.selectedFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Yesterday', 'yesterday', state.selectedFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Tomorrow (Projected)', 'tomorrow', state.selectedFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('This Week', 'week', state.selectedFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('This Month', 'month', state.selectedFilter, notifier),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF1E3A8A)),
                            label: Text(
                              state.selectedFilter == 'custom' && state.customStartDate != null
                                  ? '${state.customStartDate!.day}/${state.customStartDate!.month} – ${state.customEndDate!.day}/${state.customEndDate!.month}'
                                  : 'Custom Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: state.selectedFilter == 'custom' ? Colors.white : const Color(0xFF1E3A8A),
                              ),
                            ),
                            backgroundColor: state.selectedFilter == 'custom' ? const Color(0xFF1E3A8A) : Colors.white,
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            onPressed: _pickCustomDateRange,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ─── 3. KPI STAT METRICS GRID ─────────────────────────
                    if (overview != null)
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.55,
                        children: [
                          _buildKpiCard(
                            title: 'Gross Income',
                            value: '₹${overview.totalEarnings.toStringAsFixed(0)}',
                            subtitle: 'Net: ₹${overview.netEarnings.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFF0FDF4),
                            borderColor: const Color(0xFFBBF7D0),
                          ),
                          _buildKpiCard(
                            title: 'Working Time',
                            value: '${overview.totalOnlineHours} hrs',
                            subtitle: '${overview.totalOnlineMinutes} active mins',
                            icon: Icons.timer_rounded,
                            iconColor: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFDE68A),
                          ),
                          _buildKpiCard(
                            title: 'Orders Completed',
                            value: '${overview.completedJobs}',
                            subtitle: 'Service jobs finished',
                            icon: Icons.task_alt_rounded,
                            iconColor: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                            borderColor: const Color(0xFFBFDBFE),
                          ),
                          _buildKpiCard(
                            title: 'Avg Hourly Rate',
                            value: '₹${overview.avgHourlyRate} / hr',
                            subtitle: 'Earnings per work hour',
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF9333EA),
                            bgColor: const Color(0xFFFAF5FF),
                            borderColor: const Color(0xFFE9D5FF),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // ─── 4. INTERACTIVE DUAL-AXIS CHART (INCOME & HOURS) ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 10,
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
                              Text(
                                '${_getFilterTitle(state.selectedFilter)} Breakdown',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Tap bar to inspect',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (overview != null)
                            AnalyticsDualChart(
                              dataPoints: overview.chartData,
                              filterTitle: _getFilterTitle(state.selectedFilter),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ─── 5. DAILY WORK LOGS & TIER HISTORY TABLE ───────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Shift & Work Record',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Recent Days',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (overview != null && overview.workLogs.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: overview.workLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final log = overview.workLogs[idx];
                          Color tierColor = const Color(0xFFB87333);
                          String badgeEmoji = '🥉';
                          if (log.tier.toUpperCase() == 'GOLD') {
                            tierColor = const Color(0xFFD97706);
                            badgeEmoji = '🥇';
                          } else if (log.tier.toUpperCase() == 'SILVER') {
                            tierColor = const Color(0xFF64748B);
                            badgeEmoji = '🥈';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: tierColor.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(badgeEmoji, style: const TextStyle(fontSize: 18)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.date,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${log.hoursText} worked • ${log.jobsCount} jobs finished',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      log.earnings,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E3A8A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tierColor.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.tier,
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tierColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('No historical shift records found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String filterKey,
    String activeFilter,
    TechnicianAnalyticsNotifier notifier,
  ) {
    final isSelected = activeFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => notifier.setFilter(filterKey),
      selectedColor: const Color(0xFF1E3A8A),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: iconColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'yesterday':
        return 'Yesterday\'s Performance';
      case 'tomorrow':
        return 'Tomorrow\'s Scheduled Jobs';
      case 'week':
        return 'Weekly Trends (Mon–Sun)';
      case 'month':
        return 'Monthly Activity';
      case 'custom':
        return 'Custom Date Range';
      case 'today':
      default:
        return 'Today\'s Real-Time Shift';
    }
  }
}
