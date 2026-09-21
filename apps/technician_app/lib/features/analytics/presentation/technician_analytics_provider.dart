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
      todayHours: 0.0,
      todayMinutes: 0,
      targetHours: 5.0,
      progress: 0.0,
      hoursRemaining: 5.0,
      completedJobsToday: 0,
      todayEarnings: 0.0,
      weeklyStreakDays: 0,
      perks: [
        'Issued immediately upon partner registration',
        'Standard 15km Job Dispatch Radar',
        'Standard 10% Platform Fee',
        'Daily Wallet Balance Settlement',
      ],
      serialNumber: 'BT-COPPER-PASS',
      cardHolder: 'Partner Technician',
      technicianCode: 'BT-TECH',
      issueDate: '2026',
      status: 'ACTIVE',
    );
  }

  AnalyticsOverviewModel _getDefaultOverview(String filter) {
    return AnalyticsOverviewModel(
      filter: filter,
      totalEarnings: 0.0,
      netEarnings: 0.0,
      completedJobs: 0,
      totalOnlineMinutes: 0,
      totalOnlineHours: 0.0,
      avgHourlyRate: 0,
      currentTier: 'COPPER',
      chartData: const [
        ChartDataPoint(label: '8 AM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '10 AM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '12 PM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '2 PM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '4 PM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '6 PM', earnings: 0, workHours: 0.0, jobs: 0),
        ChartDataPoint(label: '8 PM', earnings: 0, workHours: 0.0, jobs: 0),
      ],
      workLogs: const [],
    );
  }
}

final technicianAnalyticsProvider =
    StateNotifierProvider<TechnicianAnalyticsNotifier, TechnicianAnalyticsState>((ref) {
  return TechnicianAnalyticsNotifier();
});
