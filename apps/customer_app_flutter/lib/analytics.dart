import 'package:flutter/foundation.dart';
import 'models.dart';

class AnalyticsHelper {
  static void trackEvent(String eventName, Map<String, dynamic> params) {
    // Print/log standard analytic events to Console
    final paramString = params.entries.map((e) => '${e.key}=${e.value}').join(', ');
    debugPrint('AnalyticsEvent: $eventName | Params: $paramString');
  }

  static void trackHeroBannerView(PromotionalBanner banner) {
    trackEvent(
      'HERO_BANNER_VIEW',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static void trackHeroBannerClick(PromotionalBanner banner) {
    trackEvent(
      'HERO_BANNER_CLICK',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'target_service_id': banner.serviceId,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static void trackHeroCtaClick(PromotionalBanner banner) {
    trackEvent(
      'HERO_CTA_CLICK',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'target_service_id': banner.serviceId,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static void trackSpotlightBannerView(PromotionalBanner banner) {
    trackEvent(
      'SPOTLIGHT_BANNER_VIEW',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static void trackSpotlightBannerClick(PromotionalBanner banner) {
    trackEvent(
      'SPOTLIGHT_BANNER_CLICK',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'service_id': banner.serviceId,
        'category_id': banner.categoryId,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static void trackSpotlightCtaClick(PromotionalBanner banner) {
    trackEvent(
      'SPOTLIGHT_CTA_CLICK',
      {
        'banner_id': banner.id,
        'title': banner.title,
        'service_id': banner.serviceId,
        'category_id': banner.categoryId,
        'customer_id': 'guest_user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
