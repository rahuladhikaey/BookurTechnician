class TechnicianBanner {
  final String bannerId;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaText;
  final String targetType; // 'ONLINE_TOGGLE', 'JOBS', 'PERFORMANCE', 'EARNINGS', 'CUSTOM'
  final String targetId;
  final int displayOrder;
  final bool isActive;

  const TechnicianBanner({
    required this.bannerId,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.targetType,
    this.targetId = '',
    required this.displayOrder,
    this.isActive = true,
  });

  factory TechnicianBanner.fromJson(Map<String, dynamic> json) {
    return TechnicianBanner(
      bannerId: json['bannerId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      ctaText: json['ctaText'] as String? ?? '',
      targetType: json['targetType'] as String? ?? 'JOBS',
      targetId: json['targetId'] as String? ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bannerId': bannerId,
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'ctaText': ctaText,
      'targetType': targetType,
      'targetId': targetId,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  // 4 Default Promotional Slides if offline or before network response
  static List<TechnicianBanner> getDefaultBanners() {
    return const [
      TechnicianBanner(
        bannerId: 'tech_banner_1',
        title: 'Earn More With BookurTechnician',
        subtitle: 'Stay online and get more service requests',
        ctaText: 'GO ONLINE →',
        imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000',
        targetType: 'ONLINE_TOGGLE',
        displayOrder: 1,
        isActive: true,
      ),
      TechnicianBanner(
        bannerId: 'tech_banner_2',
        title: 'Get More Jobs Near You',
        subtitle: 'Accept nearby service requests and grow your earnings',
        ctaText: 'VIEW JOBS →',
        imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=1000',
        targetType: 'JOBS',
        displayOrder: 2,
        isActive: true,
      ),
      TechnicianBanner(
        bannerId: 'tech_banner_3',
        title: 'Build Your Technician Profile',
        subtitle: 'Complete more jobs. Maintain a great rating. Get more opportunities.',
        ctaText: 'VIEW PERFORMANCE →',
        imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=1000',
        targetType: 'PERFORMANCE',
        displayOrder: 3,
        isActive: true,
      ),
      TechnicianBanner(
        bannerId: 'tech_banner_4',
        title: 'Track Your Earnings',
        subtitle: 'See today\'s jobs, weekly earnings and payout history',
        ctaText: 'VIEW EARNINGS →',
        imageUrl: 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?w=1000',
        targetType: 'EARNINGS',
        displayOrder: 4,
        isActive: true,
      ),
    ];
  }
}
