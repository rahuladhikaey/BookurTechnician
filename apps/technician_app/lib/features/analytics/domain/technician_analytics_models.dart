enum TechnicianTier {
  copper,
  silver,
  gold,
}

extension TechnicianTierExt on TechnicianTier {
  String get nameCode {
    switch (this) {
      case TechnicianTier.copper:
        return 'COPPER';
      case TechnicianTier.silver:
        return 'SILVER';
      case TechnicianTier.gold:
        return 'GOLD';
    }
  }

  String get displayName {
    switch (this) {
      case TechnicianTier.copper:
        return 'Copper Starter';
      case TechnicianTier.silver:
        return 'Silver Pro';
      case TechnicianTier.gold:
        return 'Gold VIP';
    }
  }

  String get badgeEmoji {
    switch (this) {
      case TechnicianTier.copper:
        return '🥉';
      case TechnicianTier.silver:
        return '🥈';
      case TechnicianTier.gold:
        return '🥇';
    }
  }

  double get minDailyHours {
    switch (this) {
      case TechnicianTier.copper:
        return 0.0;
      case TechnicianTier.silver:
        return 5.0;
      case TechnicianTier.gold:
        return 9.0;
    }
  }
}

class TierCardModel {
  final TechnicianTier tier;
  final String tierName;
  final String nextTierName;
  final double todayHours;
  final int todayMinutes;
  final double targetHours;
  final double progress;
  final double hoursRemaining;
  final int completedJobsToday;
  final double todayEarnings;
  final int weeklyStreakDays;
  final List<String> perks;
  final String serialNumber;
  final String cardHolder;
  final String technicianCode;
  final String issueDate;
  final String status;

  const TierCardModel({
    required this.tier,
    required this.tierName,
    required this.nextTierName,
    required this.todayHours,
    required this.todayMinutes,
    required this.targetHours,
    required this.progress,
    required this.hoursRemaining,
    required this.completedJobsToday,
    required this.todayEarnings,
    this.weeklyStreakDays = 5,
    required this.perks,
    required this.serialNumber,
    required this.cardHolder,
    required this.technicianCode,
    required this.issueDate,
    this.status = 'ACTIVE',
  });

  factory TierCardModel.fromJson(Map<String, dynamic> json) {
    final rawTierStr = (json['tier']?.toString() ?? 'COPPER').toUpperCase();
    TechnicianTier resolvedTier = TechnicianTier.copper;
    if (rawTierStr == 'GOLD') {
      resolvedTier = TechnicianTier.gold;
    } else if (rawTierStr == 'SILVER') {
      resolvedTier = TechnicianTier.silver;
    }

    final card = json['card'] is Map ? Map<String, dynamic>.from(json['card']) : {};

    return TierCardModel(
      tier: resolvedTier,
      tierName: json['tierName']?.toString() ?? resolvedTier.displayName,
      nextTierName: json['nextTierName']?.toString() ?? 'Silver Pro',
      todayHours: (json['todayHours'] as num?)?.toDouble() ?? 2.0,
      todayMinutes: (json['todayMinutes'] as num?)?.toInt() ?? 120,
      targetHours: (json['targetHours'] as num?)?.toDouble() ?? 5.0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.4,
      hoursRemaining: (json['hoursRemaining'] as num?)?.toDouble() ?? 3.0,
      completedJobsToday: (json['completedJobsToday'] as num?)?.toInt() ?? 0,
      todayEarnings: (json['todayEarnings'] as num?)?.toDouble() ?? 0.0,
      weeklyStreakDays: (json['weeklyStreakDays'] as num?)?.toInt() ?? 5,
      perks: json['perks'] is List ? List<String>.from(json['perks']) : [
        'Issued immediately upon partner registration',
        'Standard 15km Job Dispatch Radar',
        'Standard 10% Platform Fee',
        'Daily Wallet Balance Settlement',
      ],
      serialNumber: card['serialNumber']?.toString() ?? 'BT-CARD-001',
      cardHolder: card['cardHolder']?.toString() ?? 'Partner Technician',
      technicianCode: card['technicianCode']?.toString() ?? 'BT-TECH-001',
      issueDate: card['issueDate']?.toString() ?? '2026',
      status: card['status']?.toString() ?? 'ACTIVE',
    );
  }

  bool get isMaxTier => tier == TechnicianTier.gold;
  double get progressToNextTier => progress;
  double get nextTierHoursRequired => targetHours;
  double get discountCommissionPercent {
    switch (tier) {
      case TechnicianTier.gold:
        return 5.0;
      case TechnicianTier.silver:
        return 8.0;
      case TechnicianTier.copper:
        return 10.0;
    }
  }
}

class ChartDataPoint {
  final String label;
  final String? time;
  final String? date;
  final double earnings;
  final double workHours;
  final int jobs;
  final String? type;

  const ChartDataPoint({
    required this.label,
    this.time,
    this.date,
    required this.earnings,
    required this.workHours,
    required this.jobs,
    this.type,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      label: json['label']?.toString() ?? '',
      time: json['time']?.toString(),
      date: json['date']?.toString(),
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      workHours: (json['workHours'] as num?)?.toDouble() ?? 0.0,
      jobs: (json['jobs'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString(),
    );
  }
}

class DailyWorkLogRecord {
  final String date;
  final String hoursText;
  final int jobsCount;
  final String earnings;
  final String tier;
  final String status;

  const DailyWorkLogRecord({
    required this.date,
    required this.hoursText,
    required this.jobsCount,
    required this.earnings,
    required this.tier,
    this.status = 'COMPLETED',
  });

  factory DailyWorkLogRecord.fromJson(Map<String, dynamic> json) {
    return DailyWorkLogRecord(
      date: json['date']?.toString() ?? '',
      hoursText: json['hoursText']?.toString() ?? '0.0 hrs',
      jobsCount: (json['jobsCount'] as num?)?.toInt() ?? 0,
      earnings: json['earnings']?.toString() ?? '₹0',
      tier: json['tier']?.toString() ?? 'COPPER',
      status: json['status']?.toString() ?? 'COMPLETED',
    );
  }
}

class AnalyticsOverviewModel {
  final String filter;
  final double totalEarnings;
  final double netEarnings;
  final int completedJobs;
  final int totalOnlineMinutes;
  final double totalOnlineHours;
  final int avgHourlyRate;
  final String currentTier;
  final List<ChartDataPoint> chartData;
  final List<DailyWorkLogRecord> workLogs;

  const AnalyticsOverviewModel({
    required this.filter,
    required this.totalEarnings,
    required this.netEarnings,
    required this.completedJobs,
    required this.totalOnlineMinutes,
    required this.totalOnlineHours,
    required this.avgHourlyRate,
    required this.currentTier,
    required this.chartData,
    required this.workLogs,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map ? Map<String, dynamic>.from(json['summary']) : {};
    final chartList = <ChartDataPoint>[];
    if (json['chartData'] is List) {
      for (var pt in json['chartData']) {
        if (pt is Map<String, dynamic>) {
          chartList.add(ChartDataPoint.fromJson(pt));
        }
      }
    }

    final logsList = <DailyWorkLogRecord>[];
    if (json['workLogs'] is List) {
      for (var l in json['workLogs']) {
        if (l is Map<String, dynamic>) {
          logsList.add(DailyWorkLogRecord.fromJson(l));
        }
      }
    }

    return AnalyticsOverviewModel(
      filter: json['filter']?.toString() ?? 'today',
      totalEarnings: (summary['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      netEarnings: (summary['netEarnings'] as num?)?.toDouble() ?? 0.0,
      completedJobs: (summary['completedJobs'] as num?)?.toInt() ?? 0,
      totalOnlineMinutes: (summary['totalOnlineMinutes'] as num?)?.toInt() ?? 0,
      totalOnlineHours: (summary['totalOnlineHours'] as num?)?.toDouble() ?? 0.0,
      avgHourlyRate: (summary['avgHourlyRate'] as num?)?.toInt() ?? 0,
      currentTier: summary['currentTier']?.toString() ?? 'COPPER',
      chartData: chartList,
      workLogs: logsList,
    );
  }
}
