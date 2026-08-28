import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';

enum ServiceSortOption {
  recommended('Recommended', Icons.auto_awesome_rounded),
  priceLowToHigh('Price: Low to High', Icons.arrow_upward_rounded),
  priceHighToLow('Price: High to Low', Icons.arrow_downward_rounded),
  topRated('Top Rated (4.8+)', Icons.star_rounded);

  final String label;
  final IconData icon;
  const ServiceSortOption(this.label, this.icon);
}

enum PriceFilterOption {
  all('All Prices'),
  under500('Under ₹500'),
  range500to1000('₹500 - ₹1,000'),
  above1000('₹1,000+');

  final String label;
  const PriceFilterOption(this.label);
}

class AllServicesScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  const AllServicesScreen({super.key, this.initialCategoryId});

  @override
  ConsumerState<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends ConsumerState<AllServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'ALL';
  String _selectedSubcategoryId = 'ALL';
  ServiceSortOption _selectedSort = ServiceSortOption.recommended;
  PriceFilterOption _selectedPriceFilter = PriceFilterOption.all;
  bool _onlyHighRated = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null && widget.initialCategoryId!.isNotEmpty) {
      _selectedCategoryId = widget.initialCategoryId!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategoryId != 'ALL' ||
      _selectedSubcategoryId != 'ALL' ||
      _selectedSort != ServiceSortOption.recommended ||
      _selectedPriceFilter != PriceFilterOption.all ||
      _onlyHighRated;

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryId = 'ALL';
      _selectedSubcategoryId = 'ALL';
      _selectedSort = ServiceSortOption.recommended;
      _selectedPriceFilter = PriceFilterOption.all;
      _onlyHighRated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final categories = state.categories.isNotEmpty ? state.categories : MockData.categoriesList;

    // Collect all services along with their parent category and subcategory info
    final List<_ServiceWithContext> allContextualServices = [];
    for (final cat in categories) {
      for (final sub in cat.subcategories) {
        for (final srv in sub.services) {
          allContextualServices.add(
            _ServiceWithContext(
              service: srv,
              category: cat,
              subcategory: sub,
            ),
          );
        }
      }
    }

    // Filter services
    var filtered = allContextualServices.where((item) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = item.service.name.toLowerCase().contains(query);
        final matchDesc = item.service.description.toLowerCase().contains(query);
        final matchCat = item.category.name.toLowerCase().contains(query);
        final matchSub = item.subcategory.name.toLowerCase().contains(query);
        if (!matchName && !matchDesc && !matchCat && !matchSub) return false;
      }

      // 2. Category Filter
      if (_selectedCategoryId != 'ALL' && item.category.id != _selectedCategoryId) {
        return false;
      }

      // 3. Subcategory Filter
      if (_selectedSubcategoryId != 'ALL' && item.subcategory.id != _selectedSubcategoryId) {
        return false;
      }

      // 4. Price Filter
      switch (_selectedPriceFilter) {
        case PriceFilterOption.under500:
          if (item.service.price >= 500) return false;
          break;
        case PriceFilterOption.range500to1000:
          if (item.service.price < 500 || item.service.price > 1000) return false;
          break;
        case PriceFilterOption.above1000:
          if (item.service.price <= 1000) return false;
          break;
        case PriceFilterOption.all:
          break;
      }

      // 5. Rating Filter
      if (_onlyHighRated && item.service.rating < 4.8) {
        return false;
      }

      return true;
    }).toList();

    // Sort services
    switch (_selectedSort) {
      case ServiceSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.service.price.compareTo(b.service.price));
        break;
      case ServiceSortOption.priceHighToLow:
        filtered.sort((a, b) => b.service.price.compareTo(a.service.price));
        break;
      case ServiceSortOption.topRated:
        filtered.sort((a, b) => b.service.rating.compareTo(a.service.rating));
        break;
      case ServiceSortOption.recommended:
        // Default order
        break;
    }

    // Determine current subcategories list for secondary filter
    final activeCategory = _selectedCategoryId == 'ALL'
        ? null
        : categories.firstWhere(
            (c) => c.id == _selectedCategoryId,
            orElse: () => categories.first,
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'All Services',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kTextNavy,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: kTextNavy,
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 16, color: kBrandPrimary),
              label: const Text(
                'Reset',
                style: TextStyle(color: kBrandPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_bag_outlined, color: kTextNavy, size: 24),
                if (state.cartItems.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: kErrorRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${state.cartItems.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: state.cartItems.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: kBorderColor, width: 1)),
                  boxShadow: [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -3)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${state.cartItems.length} item${state.cartItems.length > 1 ? 's' : ''} in cart',
                            style: const TextStyle(fontSize: 12, color: kSecondaryText, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${state.cartItems.fold<double>(0, (sum, i) => sum + i.price).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDeepNavy),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Row(
                        children: [
                          Text('View Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // 1. Search & Filter Header Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search any service (e.g. AC, Fan, Wiring)...',
                    hintStyle: const TextStyle(fontSize: 13.5, color: kSecondaryText),
                    prefixIcon: const Icon(Icons.search_rounded, color: kBrandPrimary, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: kSecondaryText),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBrandPrimary, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Primary Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        id: 'ALL',
                        title: 'All Services',
                        count: allContextualServices.length,
                        isSelected: _selectedCategoryId == 'ALL',
                      ),
                      const SizedBox(width: 8),
                      ...categories.map((cat) {
                        final count = cat.subcategories.fold<int>(0, (sum, sub) => sum + sub.services.length);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(
                            id: cat.id,
                            title: cat.name,
                            count: count,
                            isSelected: _selectedCategoryId == cat.id,
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Secondary Subcategory Filter Chips (if specific category selected)
                if (activeCategory != null && activeCategory.subcategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSubcategoryChip(
                          id: 'ALL',
                          title: 'All ${activeCategory.name}',
                          isSelected: _selectedSubcategoryId == 'ALL',
                        ),
                        const SizedBox(width: 6),
                        ...activeCategory.subcategories.map((sub) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildSubcategoryChip(
                              id: sub.id,
                              title: sub.name,
                              isSelected: _selectedSubcategoryId == sub.id,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Quick Filter Pills Row (Sort, Price, Ratings)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Sort Dropdown Button
                      _buildSortFilterPill(),

                      const SizedBox(width: 8),

                      // Price Filter Chips
                      ...PriceFilterOption.values.map((priceOpt) {
                        final isSel = _selectedPriceFilter == priceOpt;
                        if (priceOpt == PriceFilterOption.all && !isSel) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(priceOpt.label),
                            selected: isSel,
                            selectedColor: const Color(0xFFEFF6FF),
                            checkmarkColor: kBrandPrimary,
                            side: BorderSide(
                              color: isSel ? kBrandPrimary : const Color(0xFFCBD5E1),
                              width: isSel ? 1.5 : 1,
                            ),
                            labelStyle: TextStyle(
                              color: isSel ? kBrandPrimary : kPrimaryText,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            backgroundColor: Colors.white,
                            onSelected: (_) {
                              setState(() {
                                if (_selectedPriceFilter == priceOpt) {
                                  _selectedPriceFilter = PriceFilterOption.all;
                                } else {
                                  _selectedPriceFilter = priceOpt;
                                }
                              });
                            },
                          ),
                        );
                      }),

                      // Top Rated Only Filter Chip
                      FilterChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text('4.8+ Rating'),
                          ],
                        ),
                        selected: _onlyHighRated,
                        selectedColor: const Color(0xFFFEF3C7),
                        checkmarkColor: const Color(0xFFD97706),
                        side: BorderSide(
                          color: _onlyHighRated ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                          width: _onlyHighRated ? 1.5 : 1,
                        ),
                        labelStyle: TextStyle(
                          color: _onlyHighRated ? const Color(0xFF92400E) : kPrimaryText,
                          fontWeight: _onlyHighRated ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            _onlyHighRated = selected;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Results Header Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Text(
                  '${filtered.length} service${filtered.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kDeepNavy,
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kBrandPrimary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _selectedSort.label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: kSecondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 3. Service Cards List View
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: kBrandPrimary,
                    onRefresh: () async {
                      await ref.read(bookingProvider.notifier).loadCatalog();
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _AllServiceCardItem(item: item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String title,
    required int count,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text('$title ($count)'),
      selected: isSelected,
      selectedColor: kBrandPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : kPrimaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 12.5,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? kBrandPrimary : const Color(0xFFCBD5E1),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _selectedCategoryId = id;
          _selectedSubcategoryId = 'ALL';
        });
      },
    );
  }

  Widget _buildSubcategoryChip({
    required String id,
    required String title,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      selectedColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 11.5,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) {
        setState(() {
          _selectedSubcategoryId = id;
        });
      },
    );
  }

  Widget _buildSortFilterPill() {
    return PopupMenuButton<ServiceSortOption>(
      initialValue: _selectedSort,
      onSelected: (option) {
        setState(() {
          _selectedSort = option;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => ServiceSortOption.values.map((opt) {
        return PopupMenuItem<ServiceSortOption>(
          value: opt,
          child: Row(
            children: [
              Icon(
                opt.icon,
                size: 18,
                color: _selectedSort == opt ? kBrandPrimary : kSecondaryText,
              ),
              const SizedBox(width: 10),
              Text(
                opt.label,
                style: TextStyle(
                  fontWeight: _selectedSort == opt ? FontWeight.bold : FontWeight.normal,
                  color: _selectedSort == opt ? kBrandPrimary : kPrimaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _selectedSort != ServiceSortOption.recommended ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedSort != ServiceSortOption.recommended ? kBrandPrimary : const Color(0xFFCBD5E1),
            width: _selectedSort != ServiceSortOption.recommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedSort.icon,
              size: 15,
              color: _selectedSort != ServiceSortOption.recommended ? kBrandPrimary : kSecondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              _selectedSort.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _selectedSort != ServiceSortOption.recommended ? FontWeight.bold : FontWeight.w500,
                color: _selectedSort != ServiceSortOption.recommended ? kBrandPrimary : kPrimaryText,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: kSecondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: kSecondaryText),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Matching Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find any services matching your search or filters. Try adjusting your selections.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kSecondaryText, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceWithContext {
  final ServiceItem service;
  final Category category;
  final Subcategory subcategory;

  const _ServiceWithContext({
    required this.service,
    required this.category,
    required this.subcategory,
  });
}

class _AllServiceCardItem extends ConsumerWidget {
  final _ServiceWithContext item;
  const _AllServiceCardItem({required this.item});

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
    final inCart = state.cartItems.any((s) => s.id == item.service.id);
    final service = item.service;

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
            // Service Thumbnail Banner
            AspectRatio(
              aspectRatio: 16 / 7.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    service.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: const Icon(Icons.build_outlined, size: 36, color: kSecondaryText),
                    ),
                  ),
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
                  // Category Tag Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.category.name} • ${item.subcategory.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Title
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Rating & Warranty
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 17),
                      const SizedBox(width: 3),
                      Text(
                        '${service.rating.toStringAsFixed(1)} ',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryText,
                        ),
                      ),
                      Text(
                        '(${_formatReviews(service.reviewsCount > 100 ? service.reviewsCount : 1200)})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kSecondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${service.durationMinutes} mins',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kSecondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (service.warrantyText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${service.warrantyText}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: kSuccessGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Price & Action Button Row
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
                              fontSize: 10.5,
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
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: kDeepNavy,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (service.basePrice > service.price) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${service.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
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

                      // Add / Added Button
                      SizedBox(
                        height: 38,
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                inCart ? Icons.check_circle_rounded : Icons.add_rounded,
                                size: 16,
                                color: inCart ? kSuccessGreen : Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                inCart ? 'Added' : 'Add',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
