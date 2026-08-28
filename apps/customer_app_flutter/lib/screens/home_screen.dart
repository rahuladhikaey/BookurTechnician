import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';
import '../analytics.dart';
import 'address_picker_screen.dart';
import '../widgets/floating_assistant_button.dart';
import 'ai_assistant_sheet.dart';
import '../models/customer_profile_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _BottomNav(current: '/home'),
      body: state.isCatalogLoading
          ? const Center(child: CircularProgressIndicator(color: kBrandPrimary))
          : Stack(
              children: [
                _HomeBody(state: state),
                const FloatingAssistantButton(bottomOffset: 16),
              ],
            ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final AppState state;
  const _HomeBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: const Color(0xFF2146A8),
      onRefresh: () async {
        await ref.read(bookingProvider.notifier).refreshAllData();
      },
      child: ListView(
        padding: EdgeInsets.zero, // Zero padding to allow full-width Hero Banner at the top
        children: [
          // 1. Layered Hero Banner Carousel
          HomeHeroBanner(
            banners: state.heroBanners,
            addressTitle: state.selectedAddressTitle,
            address: state.address,
            isAcquiringLocation: state.isAcquiringLocation,
          ),
          
          const SizedBox(height: 16),

          // Incomplete Profile Banner (if incomplete & not guest)
          if (!state.isGuest && !state.profile.isProfileComplete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCompletionBanner(profile: state.profile),
            ),

          if (!state.isGuest && !state.profile.isProfileComplete)
            const SizedBox(height: 12),

          // Live New Service Announcement Banner (from Admin)
          if (state.newServiceAnnouncement != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('📢', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.newServiceAnnouncement!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      onPressed: () => ref.read(bookingProvider.notifier).clearNewServiceAnnouncement(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

          if (state.newServiceAnnouncement != null)
            const SizedBox(height: 12),

          // Active booking banner (if any)
          if (state.activeBooking != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActiveBookingBanner(booking: state.activeBooking!),
            ),

          // 2. Service Categories Heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Service Categories',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kPrimaryText),
                ),
                TextButton(
                  onPressed: () => _showAllCategoriesSheet(
                    context,
                    state.categories.isNotEmpty ? state.categories : MockData.categoriesList,
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(color: kBrandPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          
          // 3. Compact Dynamic Categories Grid (2x4 / Dynamic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final displayCategories = state.categories.isNotEmpty ? state.categories : MockData.categoriesList;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: displayCategories.length.clamp(0, 8),
                  itemBuilder: (context, index) {
                    final cat = displayCategories[index];
                    final meta = _getCategoryMeta(cat.id, cat.name);

                    return _CategoryGridCard(
                      title: cat.name,
                      imageUrl: null, // Use crisp vector icon
                      icon: meta.icon,
                      color: meta.bgColor,
                      iconColor: meta.iconColor,
                      onTap: () => Navigator.pushNamed(context, '/category', arguments: cat.id),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 4. In the Popular service Carousel Section
          InPopularServiceSection(banners: state.spotlightBanners),

          const SizedBox(height: 28),

          // 5. Book Ur Service's Section (Curated service cards)
          BookUrServicesSection(
            services: state.categories.isNotEmpty
                ? state.categories.expand((c) => c.subcategories.expand((s) => s.services)).toList()
                : MockData.categoriesList.expand((c) => c.subcategories.expand((s) => s.services)).toList(),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── 1. HomeHeroBanner Widget ──────────────────────────────────────────────
class HomeHeroBanner extends StatefulWidget {
  final List<PromotionalBanner> banners;
  final String addressTitle;
  final String address;
  final bool isAcquiringLocation;

  const HomeHeroBanner({
    super.key,
    required this.banners,
    required this.addressTitle,
    required this.address,
    this.isAcquiringLocation = false,
  });

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    final banners = widget.banners.isNotEmpty ? widget.banners : MockData.default3DHeroBanners;
    _currentIndex = banners.isNotEmpty ? 1000 : 0;
    _pageController = PageController(initialPage: _currentIndex);
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant HomeHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banners.length != oldWidget.banners.length) {
      _stopAutoSlide();
      final banners = widget.banners.isNotEmpty ? widget.banners : MockData.default3DHeroBanners;
      setState(() {
        _currentIndex = banners.isNotEmpty ? 1000 : 0;
        _pageController = PageController(initialPage: _currentIndex);
      });
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    final banners = widget.banners.isNotEmpty ? widget.banners : MockData.default3DHeroBanners;
    if (banners.length <= 1) return;
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!_isUserInteracting && _pageController.hasClients) {
        final nextIndex = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerList = widget.banners.isNotEmpty ? widget.banners : MockData.default3DHeroBanners;
    final bannerCount = bannerList.length;

    // Fire impression analytics for the current visible index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (bannerList.isNotEmpty) {
        final activeIndex = _currentIndex % bannerCount;
        AnalyticsHelper.trackHeroBannerView(bannerList[activeIndex]);
      }
    });

    return Container(
      height: 330,
      decoration: const BoxDecoration(
        color: kBrandPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: [
            // PageView Background 3D Images & Scrims
            GestureDetector(
              onPanDown: (_) {
                setState(() => _isUserInteracting = true);
              },
              onPanCancel: () {
                setState(() => _isUserInteracting = false);
              },
              onPanEnd: (_) {
                setState(() => _isUserInteracting = false);
              },
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final activeBanner = bannerList[index % bannerList.length];
                  final isAsset = activeBanner.imageUrl.startsWith('assets/');

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // High quality 3D Banner image
                      isAsset
                          ? Image.asset(
                              activeBanner.imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            )
                          : Image.network(
                              activeBanner.imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) => Image.asset(
                                'assets/images/banner_3d_1.png',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            ),
                      // Top-down dark scrim gradient for Location & Search bar readability
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x99000000),
                              Color(0x55000000),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                      // Bottom-up dark scrim gradient for promotional text readability
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xCC000000),
                            ],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Top Content Column (Location + Search Bar always layered on top)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A. Location Selector Row overlay (white text)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddressPickerScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.addressTitle.isNotEmpty ? widget.addressTitle : 'Current Location',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    if (widget.isAcquiringLocation) ...[
                                      const SizedBox(width: 6),
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  widget.address,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // B. Rotating Search Bar Suggestion overlay
                    const RotatingSearchBar(),
                  ],
                ),
              ),
            ),

            // Bottom Content Column (Promotional campaigns + indicator overlay)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Promotional Details (title, subtitle, badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kBrandSecondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                bannerList[_currentIndex % bannerList.length].badgeText.toUpperCase(),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bannerList[_currentIndex % bannerList.length].title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bannerList[_currentIndex % bannerList.length].subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // CTA Book Now Button
                      ElevatedButton(
                        onPressed: () {
                          final currentBanner = bannerList[_currentIndex % bannerList.length];
                          AnalyticsHelper.trackHeroCtaClick(currentBanner);
                          if (currentBanner.serviceId.isNotEmpty) {
                            AnalyticsHelper.trackHeroBannerClick(currentBanner);
                            Navigator.pushNamed(context, '/service_detail', arguments: currentBanner.serviceId);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bannerList[_currentIndex % bannerList.length].ctaText,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 12, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Carousel indicator dots: active dot is expanded pill, others are small circles
                  if (bannerCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(bannerCount, (index) {
                        final isActive = (index == (_currentIndex % bannerCount));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45),
                          ),
                        );
                      }),
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

// Search suggestions rotation bar with live interactive search sheet trigger
class RotatingSearchBar extends ConsumerStatefulWidget {
  const RotatingSearchBar({super.key});

  @override
  ConsumerState<RotatingSearchBar> createState() => _RotatingSearchBarState();
}

class _RotatingSearchBarState extends ConsumerState<RotatingSearchBar> {
  final List<String> _suggestions = [
    'Search for "AC service"',
    'Search for "Electrician"',
    'Search for "Fan installation"',
    'Search for "Refrigerator service"',
    'Search for "Washing machine repair"',
  ];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % _suggestions.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLiveServiceSearchSheet(context, ref),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, color: kBrandPrimary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _suggestions[_index],
                  key: ValueKey<String>(_suggestions[_index]),
                  style: const TextStyle(
                    color: kSecondaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kLightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Search',
                style: TextStyle(color: kBrandPrimary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Service Search Modal Bottom Sheet ─────────────────────────────────
void _showLiveServiceSearchSheet(BuildContext context, WidgetRef ref) {
  final state = ref.read(bookingProvider);
  final allServices = state.categories.isNotEmpty
      ? state.categories.expand((c) => c.subcategories.expand((s) => s.services)).toList()
      : MockData.categoriesList.expand((c) => c.subcategories.expand((s) => s.services)).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (modalCtx) {
      String query = '';
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = allServices.where((s) {
            final q = query.toLowerCase().trim();
            if (q.isEmpty) return true;
            return s.name.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q) ||
                s.warrantyText.toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),

                // Search Input Field
                TextField(
                  autofocus: true,
                  onChanged: (val) => setModalState(() => query = val),
                  decoration: InputDecoration(
                    hintText: 'Search AC, electrician, fan, laptop, repair...',
                    prefixIcon: const Icon(Icons.search, color: kBrandPrimary),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setModalState(() => query = ''))
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['AC', 'Electrician', 'Fan', 'Washing', 'Laptop', 'Refrigerator'].map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(tag, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: kBorderColor),
                          onPressed: () => setModalState(() => query = tag),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  '${filtered.length} Services Available',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kSecondaryText),
                ),
                const SizedBox(height: 10),

                // Results list
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: kSecondaryText),
                              SizedBox(height: 8),
                              Text('No services found matching your query', style: TextStyle(color: kSecondaryText, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 16, color: kBorderColor),
                          itemBuilder: (c, i) {
                            final item = filtered[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 50,
                                    height: 50,
                                    color: kLightBlue,
                                    child: const Icon(Icons.build, color: kBrandPrimary),
                                  ),
                                ),
                              ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText)),
                              subtitle: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                  Text(' ${item.rating} • ${item.durationMinutes} mins', style: const TextStyle(fontSize: 11.5, color: kSecondaryText)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: kSuccessGreen, size: 12),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  Navigator.pushNamed(context, '/service_detail', arguments: item.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBlack,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ─── All Categories Sheet ───────────────────────────────────────────────────
void _showAllCategoriesSheet(BuildContext context, List<Category> categories) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (modalCtx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Service Categories',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kPrimaryText),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(modalCtx)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: categories.length,
                itemBuilder: (ctx, index) {
                  final cat = categories[index];
                  final meta = _getCategoryMeta(cat.id, cat.name);
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(modalCtx);
                      Navigator.pushNamed(context, '/category', arguments: cat.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: meta.bgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(meta.icon, color: meta.iconColor, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: kPrimaryText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CategoryMeta {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  const _CategoryMeta({required this.icon, required this.bgColor, required this.iconColor});
}

_CategoryMeta _getCategoryMeta(String id, String name) {
  final lower = '${id.toLowerCase()} ${name.toLowerCase()}';
  if (lower.contains('wiring') || lower.contains('project')) {
    return const _CategoryMeta(
      icon: Icons.home_repair_service_rounded,
      bgColor: Color(0xFFE0F2FE),
      iconColor: Color(0xFF0284C7),
    );
  }
  if (lower.contains('electr') || lower.contains('fan') || lower.contains('switch')) {
    return const _CategoryMeta(
      icon: Icons.bolt_rounded,
      bgColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFD97706),
    );
  }
  if (lower.contains('ac') || lower.contains('cool') || lower.contains('air')) {
    return const _CategoryMeta(
      icon: Icons.ac_unit_rounded,
      bgColor: Color(0xFFE0F7FA),
      iconColor: Color(0xFF0097A7),
    );
  }
  if (lower.contains('refrig') || lower.contains('fridge') || lower.contains('freezer')) {
    return const _CategoryMeta(
      icon: Icons.kitchen_rounded,
      bgColor: Color(0xFFDCFCE7),
      iconColor: Color(0xFF16A34A),
    );
  }
  if (lower.contains('wash') || lower.contains('laundry')) {
    return const _CategoryMeta(
      icon: Icons.local_laundry_service_rounded,
      bgColor: Color(0xFFF3E8FF),
      iconColor: Color(0xFF9333EA),
    );
  }
  if (lower.contains('laptop') || lower.contains('computer') || lower.contains('pc')) {
    return const _CategoryMeta(
      icon: Icons.laptop_chromebook_rounded,
      bgColor: Color(0xFFE0E7FF),
      iconColor: Color(0xFF4F46E5),
    );
  }
  if (lower.contains('cctv') || lower.contains('camera') || lower.contains('security')) {
    return const _CategoryMeta(
      icon: Icons.videocam_rounded,
      bgColor: Color(0xFFFEE2E2),
      iconColor: Color(0xFFDC2626),
    );
  }
  if (lower.contains('appliance') || lower.contains('micro') || lower.contains('purifier') || lower.contains('ro')) {
    return const _CategoryMeta(
      icon: Icons.microwave_rounded,
      bgColor: Color(0xFFFFF7ED),
      iconColor: Color(0xFFEA580C),
    );
  }
  return const _CategoryMeta(
    icon: Icons.home_repair_service_outlined,
    bgColor: Color(0xFFF1F5F9),
    iconColor: Color(0xFF0F172A),
  );
}

// ─── 2. Compact Grid Category Item Widget ────────────────────────────────────
class _CategoryGridCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _CategoryGridCard({
    required this.title,
    this.imageUrl,
    required this.icon,
    required this.color,
    this.iconColor = kTextNavy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        icon,
                        color: iconColor,
                        size: 26,
                      ),
                    )
                  : Icon(
                      icon,
                      color: iconColor,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: kTextNavy,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. In the Popular service Carousel Section ─────────────────────────────
class InPopularServiceSection extends StatefulWidget {
  final List<PromotionalBanner> banners;
  const InPopularServiceSection({super.key, required this.banners});

  @override
  State<InPopularServiceSection> createState() => _InPopularServiceSectionState();
}

class _InPopularServiceSectionState extends State<InPopularServiceSection> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _currentPage = 1200; // High initial page for continuous bidirectional looping
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.92, // Slight viewport inset for modern peek effect
    );
    _startTimer();
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!_isInteracting && _pageController.hasClients) {
        _pageController.animateToPage(
          _pageController.page!.round() + 1,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _resetTimer() {
    _startTimer();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerList = widget.banners.isNotEmpty ? widget.banners : MockData.defaultPopularBanners;
    final count = bannerList.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (bannerList.isNotEmpty) {
        AnalyticsHelper.trackSpotlightBannerView(bannerList[_currentPage % count]);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'In the Popular service',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: kDeepNavy,
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Horizontally swipeable PageView Carousel
        SizedBox(
          height: 185,
          child: GestureDetector(
            onPanDown: (_) {
              setState(() => _isInteracting = true);
              _autoSlideTimer?.cancel();
            },
            onPanCancel: () {
              setState(() => _isInteracting = false);
              _resetTimer();
            },
            onPanEnd: (_) {
              setState(() => _isInteracting = false);
              _resetTimer();
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                final banner = bannerList[index % count];
                final isAsset = banner.imageUrl.startsWith('assets/');

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GestureDetector(
                      onTap: () {
                        AnalyticsHelper.trackSpotlightBannerClick(banner);
                        if (banner.serviceId.isNotEmpty) {
                          Navigator.pushNamed(context, '/service_detail', arguments: banner.serviceId);
                        } else if (banner.categoryId.isNotEmpty) {
                          Navigator.pushNamed(context, '/category', arguments: banner.categoryId);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Imagery
                          isAsset
                              ? Image.asset(
                                  banner.imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                )
                              : Image.network(
                                  banner.imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) => Image.asset(
                                    'assets/images/popular_banner_1.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                ),

                          // Dark gradient overlay for optimal text contrast
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00000000),
                                  Color(0x730B1F63),
                                  Color(0xE60B1635),
                                ],
                                stops: [0.25, 0.60, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),

                          // Top-left Category Badge
                          Positioned(
                            left: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                banner.badgeText.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF0B1635),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          // Bottom Promotional Details & White CTA Button
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        banner.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        banner.subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    AnalyticsHelper.trackSpotlightCtaClick(banner);
                                    if (banner.serviceId.isNotEmpty) {
                                      Navigator.pushNamed(context, '/service_detail', arguments: banner.serviceId);
                                    } else if (banner.categoryId.isNotEmpty) {
                                      Navigator.pushNamed(context, '/category', arguments: banner.categoryId);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: kDeepNavy,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    elevation: 2,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        banner.ctaText,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: kDeepNavy,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward, size: 12, color: kDeepNavy),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Indicator Row: active dot is elongated pill, inactive are circular dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            final isActive = index == (_currentPage % count);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive ? kBrandPrimary : const Color(0xFFD1D5DB),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── 5. Book Ur Service's Section ───────────────────────────────────────────
class BookUrServicesSection extends ConsumerWidget {
  final List<ServiceItem> services;
  const BookUrServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (services.isEmpty) return const SizedBox.shrink();

    final displayServices = services.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title & View All Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Book Ur Service's",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: kDeepNavy,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/all_services'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All (${services.length})',
                        style: const TextStyle(
                          color: kBrandPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kBrandPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Display Max 4 service cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: displayServices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final service = displayServices[index];
            return _BookUrServiceCard(service: service);
          },
        ),

        // "View All Services" Action Card after the 4 cards
        if (services.length > 4) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/all_services'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A1E40AF),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: kBrandPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x331E40AF),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View All Services (${services.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: kDeepNavy,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Explore full catalog with filters & fast booking',
                            style: TextStyle(
                              fontSize: 12,
                              color: kSecondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: kBrandPrimary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Service Card Layout Component ──────────────────────────────────────────
class _BookUrServiceCard extends ConsumerWidget {
  final ServiceItem service;
  const _BookUrServiceCard({required this.service});

  String _formatReviews(int count) {
    if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return '${k}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final inCart = state.cartItems.any((s) => s.id == service.id);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/service_detail', arguments: service.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0B1F63),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Large Service/Technician Image (Rounded top corners, 16:9 ratio)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    service.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: const Icon(Icons.build_outlined, size: 40, color: kSecondaryText),
                    ),
                  ),
                  // Top gradient scrim
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x2B000000), Color(0x00000000)],
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Card Details Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Name
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Rating Row: ★ 4.8 (12.4K)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${service.rating.toStringAsFixed(1)} ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryText,
                        ),
                      ),
                      Text(
                        '(${_formatReviews(service.reviewsCount > 100 ? service.reviewsCount : 12400)})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kSecondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (service.warrantyText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${service.warrantyText}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kSuccessGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Price & Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Starts at',
                            style: TextStyle(
                              fontSize: 11,
                              color: kSecondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${service.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kDeepNavy,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (service.basePrice > service.price) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${service.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kSecondaryText,
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      // Add Button
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(bookingProvider.notifier).toggleCartItem(service);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inCart ? const Color(0xFFDCFCE7) : kBlack,
                            foregroundColor: inCart ? kSuccessGreen : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: inCart ? const BorderSide(color: kSuccessGreen, width: 1.5) : BorderSide.none,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                inCart ? Icons.check_circle_rounded : Icons.add_rounded,
                                size: 16,
                                color: inCart ? kSuccessGreen : Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                inCart ? 'Added' : 'Add',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: inCart ? kSuccessGreen : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ─── ProfileCompletionBanner Widget ──────────────────────────────────────────
class _ProfileCompletionBanner extends StatelessWidget {
  final CustomerProfile profile;
  const _ProfileCompletionBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDD5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚠ Incomplete profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9A3412)),
                    ),
                    Text(
                      '${profile.profileCompletion}% complete',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFFC2410C)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Add your ${profile.missingFieldsReadable} for quick dispatch.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF7C2D12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/profile_completion_wizard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(50, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Complete', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─── ActiveBookingBanner Widget ─────────────────────────────────────────────
class _ActiveBookingBanner extends StatelessWidget {
  final Booking booking;
  const _ActiveBookingBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/tracking', arguments: booking.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kGreenSuccess.withValues(alpha: 0.1),
          border: Border.all(color: kGreenSuccess, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: kGreenSuccess),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Active Booking', style: TextStyle(fontWeight: FontWeight.bold, color: kGreenSuccess)),
            Text(booking.services.map((s) => s.name).join(', '),
                style: const TextStyle(fontSize: 12, color: kTextGray)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: kTextGray),
        ]),
      ),
    );
  }
}

// ─── Bottom Navigation Bar (Royal Blue + Black Brand System) ─────────────────
class _BottomNav extends ConsumerWidget {
  final String current;
  const _BottomNav({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(bookingProvider).cartItems.length;

    final navItems = [
      _NavItemData(route: '/home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItemData(route: '/history', icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Bookings'),
      _NavItemData(route: '/cart', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, label: 'Cart', badgeCount: cartCount),
      _NavItemData(route: '/assistant', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Help', isAssistant: true),
      _NavItemData(route: '/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kBlack,
        border: Border(top: BorderSide(color: Color(0xFF27272A), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: navItems.map((item) {
            final isSelected = item.route == current;
            return InkWell(
              onTap: () {
                if (item.isAssistant) {
                  AiAssistantSheet.show(context);
                } else if (item.route != current) {
                  Navigator.pushNamed(context, item.route);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          size: 22,
                        ),
                        if (item.badgeCount != null && item.badgeCount! > 0)
                          Positioned(
                            top: -4,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              alignment: Alignment.center,
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;
  final bool isAssistant;

  const _NavItemData({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.isAssistant = false,
  });
}
