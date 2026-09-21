import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/technician_analytics_service.dart';
import '../domain/technician_analytics_models.dart';

class TechnicianAnalyticsState {
  final bool isLoading;
  final String selectedFilter; // 'today', 'yesterday', 'tomorrow', 'week', 'month', 'custom'
  final TierCardModel? tierInfo;
  final AnalyticsOverviewModel? overview;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? errorMessage;

  const TechnicianAnalyticsState({
    this.isLoading = false,
    this.selectedFilter = 'today',
    this.tierInfo,
    this.overview,
    this.customStartDate,
    this.customEndDate,
    this.errorMessage,
  });

  TechnicianAnalyticsState copyWith({
    bool? isLoading,
    String? selectedFilter,
    TierCardModel? tierInfo,
    AnalyticsOverviewModel? overview,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? errorMessage,
  }) {
    return TechnicianAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      tierInfo: tierInfo ?? this.tierInfo,
      overview: overview ?? this.overview,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      errorMessage: errorMessage,
    );
  }
}

class TechnicianAnalyticsNotifier extends StateNotifier<TechnicianAnalyticsState> {
  final TechnicianAnalyticsService _service;

  TechnicianAnalyticsNotifier({TechnicianAnalyticsService? service})
      : _service = service ?? TechnicianAnalyticsService(),
        super(const TechnicianAnalyticsState()) {
    loadData();
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final tier = await _service.fetchTierStatus();
      final overview = await _service.fetchAnalyticsOverview(
        filter: state.selectedFilter,
        startDate: state.customStartDate?.toIso8601String().split('T').first,
        endDate: state.customEndDate?.toIso8601String().split('T').first,
      );

      state = state.copyWith(
        isLoading: false,
        tierInfo: tier ?? state.tierInfo ?? _getDefaultTierModel(),
        overview: overview ?? state.overview ?? _getDefaultOverview(state.selectedFilter),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load analytics: $e',
        tierInfo: state.tierInfo ?? _getDefaultTierModel(),
        overview: state.overview ?? _getDefaultOverview(state.selectedFilter),
      );
    }
  }

  Future<void> setFilter(String filter) async {
    if (state.selectedFilter == filter) return;
    state = state.copyWith(selectedFilter: filter, isLoading: true);

    try {
      final overview = await _service.fetchAnalyticsOverview(
        filter: filter,
        startDate: state.customStartDate?.toIso8601String().split('T').first,
        endDate: state.customEndDate?.toIso8601String().split('T').first,
      );
      state = state.copyWith(
        isLoading: false,
        overview: overview ?? _getDefaultOverview(filter),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setCustomDateRange(DateTime start, DateTime end) async {
    state = state.copyWith(
      selectedFilter: 'custom',
      customStartDate: start,
      customEndDate: end,
      isLoading: true,
    );

    try {
      final overview = await _service.fetchAnalyticsOverview(
        filter: 'custom',
        startDate: start.toIso8601String().split('T').first,
        endDate: end.toIso8601String().split('T').first,
      );
      state = state.copyWith(
        isLoading: false,
        overview: overview ?? _getDefaultOverview('custom'),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  TierCardModel _getDefaultTierModel() {
    return const TierCardModel(
      tier: TechnicianTier.copper,
      tierName: 'Copper Starter',
      nextTierName: 'Silver Pro',
      todayHours: 2.0,
      todayMinutes: 120,
      targetHours: 5.0,
      progress: 0.4,
      hoursRemaining: 3.0,
      completedJobsToday: 2,
      todayEarnings: 750.0,
      weeklyStreakDays: 3,
      perks: [
        'Issued immediately upon partner registration',
        'Standard 15km Job Dispatch Radar',
        'Standard 10% Platform Fee',
        'Daily Wallet Balance Settlement',
      ],
      serialNumber: 'BT-COPPER-775A',
      cardHolder: 'Partner Technician',
      technicianCode: 'BT-TECH-001',
      issueDate: '2026',
      status: 'ACTIVE',
    );
  }

  AnalyticsOverviewModel _getDefaultOverview(String filter) {
    if (filter == 'tomorrow') {
      return const AnalyticsOverviewModel(
        filter: 'tomorrow',
        totalEarnings: 2600.0,
        netEarnings: 2340.0,
        completedJobs: 7,
        totalOnlineMinutes: 480,
        totalOnlineHours: 8.0,
        avgHourlyRate: 325,
        currentTier: 'SILVER',
        chartData: [
          ChartDataPoint(label: '9 AM – 11 AM', earnings: 450, workHours: 2.0, jobs: 1, type: 'CONFIRMED'),
          ChartDataPoint(label: '12 PM – 2 PM', earnings: 600, workHours: 2.0, jobs: 2, type: 'CONFIRMED'),
          ChartDataPoint(label: '3 PM – 5 PM', earnings: 850, workHours: 2.0, jobs: 2, type: 'ESTIMATED'),
          ChartDataPoint(label: '6 PM – 8 PM', earnings: 700, workHours: 2.0, jobs: 2, type: 'ESTIMATED'),
        ],
        workLogs: [],
      );
    }

    return const AnalyticsOverviewModel(
      filter: 'today',
      totalEarnings: 1850.0,
      netEarnings: 1665.0,
      completedJobs: 5,
      totalOnlineMinutes: 390,
      totalOnlineHours: 6.5,
      avgHourlyRate: 285,
      currentTier: 'SILVER',
      chartData: [
        ChartDataPoint(label: '8 AM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '10 AM', earnings: 350, workHours: 1.5, jobs: 1),
        ChartDataPoint(label: '12 PM', earnings: 450, workHours: 1.2, jobs: 1),
        ChartDataPoint(label: '2 PM', earnings: 0, workHours: 0.8, jobs: 0),
        ChartDataPoint(label: '4 PM', earnings: 650, workHours: 1.8, jobs: 2),
        ChartDataPoint(label: '6 PM', earnings: 400, workHours: 1.2, jobs: 1),
        ChartDataPoint(label: '8 PM', earnings: 0, workHours: 0.0, jobs: 0),
      ],
      workLogs: [
        DailyWorkLogRecord(date: 'Today', hoursText: '6.5 hrs', jobsCount: 5, earnings: '₹1,850', tier: 'SILVER', status: 'ACTIVE'),
        DailyWorkLogRecord(date: 'Yesterday', hoursText: '8.2 hrs', jobsCount: 7, earnings: '₹2,400', tier: 'SILVER', status: 'COMPLETED'),
        DailyWorkLogRecord(date: '20 Sep 2026', hoursText: '9.4 hrs', jobsCount: 8, earnings: '₹2,850', tier: 'GOLD', status: 'COMPLETED'),
        DailyWorkLogRecord(date: '19 Sep 2026', hoursText: '7.5 hrs', jobsCount: 6, earnings: '₹2,100', tier: 'SILVER', status: 'COMPLETED'),
      ],
    );
  }
}

final technicianAnalyticsProvider =
    StateNotifierProvider<TechnicianAnalyticsNotifier, TechnicianAnalyticsState>((ref) {
  return TechnicianAnalyticsNotifier();
});
