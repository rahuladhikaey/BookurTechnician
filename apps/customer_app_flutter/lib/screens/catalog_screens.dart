import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';
import 'booking_status_map_screen.dart';

class CategoryServicesScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const CategoryServicesScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryServicesScreen> createState() => _CategoryServicesScreenState();
}

class _CategoryServicesScreenState extends ConsumerState<CategoryServicesScreen> {
  String _selectedSubcategoryId = 'ALL';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final categoryList = state.categories.isNotEmpty ? state.categories : MockData.categoriesList;
    final category = categoryList.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => MockData.categoriesList.firstWhere(
        (c) => c.id == widget.categoryId,
        orElse: () => categoryList.isNotEmpty
            ? categoryList.first
            : const Category(id: '', name: 'Services', subcategories: []),
      ),
    );

    final allSubcategories = category.subcategories;
    final filteredSubcategories = _selectedSubcategoryId == 'ALL'
        ? allSubcategories
        : allSubcategories.where((s) => s.id == _selectedSubcategoryId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextNavy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: kTextNavy,
      ),
      bottomNavigationBar: state.cartItems.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
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
                            '${state.cartItems.length} item${state.cartItems.length > 1 ? 's' : ''} added',
                            style: const TextStyle(fontSize: 12, color: kSecondaryText, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${state.cartItems.fold<double>(0, (sum, i) => sum + i.price).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextNavy),
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
                          Icon(Icons.arrow_forward, size: 16),
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
          // Subcategory Filter Chips
          if (allSubcategories.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Services'),
                      selected: _selectedSubcategoryId == 'ALL',
                      selectedColor: kBrandPrimary,
                      labelStyle: TextStyle(
                        color: _selectedSubcategoryId == 'ALL' ? Colors.white : kPrimaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                      onSelected: (_) => setState(() => _selectedSubcategoryId = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    ...allSubcategories.map((sub) {
                      final isSel = _selectedSubcategoryId == sub.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(sub.name),
                          selected: isSel,
                          selectedColor: kBrandPrimary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : kPrimaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) => setState(() => _selectedSubcategoryId = sub.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Subcategories and Services List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredSubcategories.length,
              itemBuilder: (_, i) {
                final sub = filteredSubcategories[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: kBrandPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sub.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextNavy),
                          ),
                          const Spacer(),
                          Text(
                            '${sub.services.length} options',
                            style: const TextStyle(fontSize: 11.5, color: kSecondaryText),
                          ),
                        ],
                      ),
                    ),
                    ...sub.services.map((service) => _ServiceCard(service: service)),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final ServiceItem service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final inCart = state.cartItems.any((s) => s.id == service.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/service_detail', arguments: service.id),
              child: Text(service.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBrandPrimary,
                      decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 4),
            Text('₹${service.price.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextNavy)),
            Text('${service.durationMinutes} mins • ${service.warrantyText}',
                style: const TextStyle(fontSize: 11, color: kTextGray)),
            const SizedBox(height: 4),
            Builder(builder: (_) {
              final count = state.getServiceAvailabilityCount(service.id);
              final hasTechs = count > 0;
              return Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasTechs ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasTechs
                        ? '$count ${count == 1 ? "technician" : "technicians"} available nearby'
                        : 'No technicians available nearby',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: hasTechs ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            }),
          ])),
          ElevatedButton(
            onPressed: () => ref.read(bookingProvider.notifier).toggleCartItem(service),
            style: ElevatedButton.styleFrom(
              backgroundColor: inCart ? const Color(0xFFDCFCE7) : kBlack,
              foregroundColor: inCart ? kSuccessGreen : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: inCart ? const BorderSide(color: kSuccessGreen, width: 1.5) : BorderSide.none,
              ),
              elevation: 0,
            ),
            child: Text(inCart ? 'Added' : 'Add'),
          ),
        ]),
      ),
    );
  }
}

// ─── Service Detail Screen ────────────────────────────────────────────────────

class ServiceDetailScreen extends ConsumerWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final service = state.categories
        .expand((c) => c.subcategories.expand((s) => s.services))
        .firstWhere(
          (s) => s.id == serviceId,
          orElse: () => const ServiceItem(
            id: '',
            name: 'Not Found',
            price: 0,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
          ),
        );
    final inCart = state.cartItems.any((s) => s.id == service.id);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(service.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kTextNavy,
      ),
      bottomNavigationBar: _buildBottomBookingSection(context, ref, service, inCart),
      body: ListView(
        children: [
          // 1. Dynamic Service Header Image
          Image.network(
            service.imageUrl,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 240,
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, size: 48, color: kTextGray),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextNavy,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Pricing
                Row(
                  children: [
                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kBrandPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '₹${(service.price * 1.25).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: kTextGray,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x1A10B981), // 10% opacity Green
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '20% OFF',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Rating & Tag
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${service.rating}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kTextNavy,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${service.reviewsCount} ratings)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: kTextGray,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x1A06B6D4), // 10% opacity brand secondary
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: kBrandSecondary, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: kBrandSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Doorstep description
                const Text(
                  'Professional Service at Your Doorstep',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextNavy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get reliable and convenient technical services at your home with BookurTechnician. Our trained technicians arrive at your selected location, understand the problem, perform the required service, and ensure the work is completed properly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextGray,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                
                // 15km Radius Online & Available Technicians Banner
                _buildNearbyTechniciansSection(service),
                const SizedBox(height: 24),
                
                // 2. Why Choose Section
                _buildWhyChooseSection(),
                const SizedBox(height: 28),
                
                // 3. What Service Includes Section
                _buildInclusionsSection(),
                const SizedBox(height: 28),
                
                // 4. Does Not Include Section
                _buildExclusionsSection(),
                const SizedBox(height: 28),
                
                // 5. How It's Done Section
                _buildHowItWorksSection(),
                const SizedBox(height: 28),
                
                // 6. FAQs Section
                _buildFaqsSection(),
                const SizedBox(height: 28),
                
                // 7. Service Promise Section
                _buildServicePromiseSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyTechniciansSection(ServiceItem service) {
    final int availableCount = (service.price > 1000) ? 3 : (service.price > 400 ? 5 : 6);
    final int estimatedMinutes = (service.price > 1000) ? 25 : 18;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft Blue
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x401E40AF),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Live green pulse
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$availableCount Technicians Online in 15 km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Free for immediate dispatch • Avg arrival $estimatedMinutes mins',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Column(
              children: [
                Text(
                  'FAST DISPATCH',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  '15 km Radius',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseSection() {
    final benefits = [
      'Book a technician at your convenience',
      'Trained and verified professionals',
      'Transparent service charges',
      'Convenient doorstep service',
      'Easy scheduling',
      'Multiple technical services available',
      'Quality-focused service',
      'Service tracking and booking updates',
      'Customer support when you need it',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0A077E9B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A077E9B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Customers Choose BookurTechnician',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kTextNavy,
            ),
          ),
          const SizedBox(height: 14),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✓',
                  style: TextStyle(
                    color: kBrandSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kTextNavy,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInclusionsSection() {
    final inclusions = [
      'Technician visit to your selected location',
      'Inspection of the requested service',
      'Basic diagnosis and assessment',
      'Professional service according to the selected service',
      'Required standard tools used by the technician',
      'Testing after service completion',
      'Final service check',
      'Service completion confirmation',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What This Service Includes',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kTextNavy,
          ),
        ),
        const SizedBox(height: 14),
        ...inclusions.map((inc) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✓',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  inc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextNavy,
                  ),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x80FFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFECB3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Note: Any additional parts, materials, replacement components, or extra work required beyond the selected service may be charged separately after customer approval.',
                  style: TextStyle(
                    fontSize: 11,
                    color: kTextNavy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExclusionsSection() {
    final exclusions = [
      'Unrelated services not selected during booking',
      'Major replacement parts unless specifically mentioned in the service',
      'Additional materials or components required for repair',
      'Structural or civil work',
      'Electrical rewiring beyond the selected service',
      'Damage caused by pre-existing faults or improper installation',
      'Services outside the selected service scope',
      'Any additional work without customer approval',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Does Not Include',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kTextNavy,
          ),
        ),
        const SizedBox(height: 14),
        ...exclusions.map((exc) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextNavy,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    final steps = [
      const _StepData(
        step: '1',
        title: 'Book the Service',
        desc: 'Select the service you need, choose your preferred date and time, confirm your address, and place your booking.',
      ),
      const _StepData(
        step: '2',
        title: 'Technician Assignment',
        desc: 'BookurTechnician assigns a suitable trained technician based on service requirements and availability.',
      ),
      const _StepData(
        step: '3',
        title: 'Technician Arrives',
        desc: 'Your technician arrives at your selected location at the scheduled time and verifies the service request.',
      ),
      const _StepData(
        step: '4',
        title: 'Inspection & Diagnosis',
        desc: 'The technician checks the equipment, system, or service requirement and identifies what needs to be done.',
      ),
      const _StepData(
        step: '5',
        title: 'Service Begins',
        desc: 'The technician performs the selected service using appropriate professional tools and techniques.',
      ),
      const _StepData(
        step: '6',
        title: 'Testing & Final Checks',
        desc: 'After completing the work, the technician tests the service and checks that everything is functioning properly.',
      ),
      const _StepData(
        step: '7',
        title: 'Service Completion',
        desc: 'Once the work is completed, the customer can review the service, provide feedback, and rate the technician.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How It\'s Done?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kTextNavy,
          ),
        ),
        const SizedBox(height: 16),
        ...steps.map((step) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0x1A077E9B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  step.step,
                  style: const TextStyle(
                    color: kBrandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kTextNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kTextGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFaqsSection() {
    final faqs = [
      const _FaqData(
        q: 'What if the service cannot be completed during the scheduled visit?',
        a: 'If the service requires additional time, parts, or work beyond the selected service, the technician will explain the requirement to you. Any additional work or charges will require customer approval before proceeding.',
      ),
      const _FaqData(
        q: 'How can I trust BookurTechnician\'s service?',
        a: 'BookurTechnician connects customers with trained and verified technicians. We focus on professional service, transparent communication, customer safety, and service quality.',
      ),
      const _FaqData(
        q: 'Do I need to provide tools or equipment?',
        a: 'Usually, the technician will bring the standard tools required for the selected service. However, certain specialized parts, materials, or equipment may need to be arranged separately depending on the service requirement.',
      ),
      const _FaqData(
        q: 'How are the prices calculated?',
        a: 'The displayed price is based on the selected service. The final charge may vary if additional parts, materials, specialized work, or services are required. Any additional charge should be communicated to the customer before the extra work is performed.',
      ),
      const _FaqData(
        q: 'How do I contact support?',
        a: 'You can contact BookurTechnician Support through the Help & Support section in the app. Our support team can assist with booking issues, technician-related concerns, payments, cancellations, and service-related queries.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kTextNavy,
          ),
        ),
        const SizedBox(height: 8),
        ...faqs.map((faq) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              faq.q,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kTextNavy,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Text(
                  faq.a,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextGray,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildServicePromiseSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Promise',
            style: TextStyle(
              color: kBrandSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'BookurTechnician — Skilled Technicians. Reliable Service. At Your Doorstep.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We make it simple to book trusted technical professionals whenever you need help at home.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBookingSection(
    BuildContext context,
    WidgetRef ref,
    ServiceItem service,
    bool inCart,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kTextNavy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '₹${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kBrandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${service.durationMinutes} mins',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // 1. Add to Cart Toggle
            OutlinedButton(
              onPressed: () {
                ref.read(bookingProvider.notifier).toggleCartItem(service);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: inCart ? const Color(0xFF334155) : const Color(0xFF16A34A),
                    content: Text(
                      inCart ? 'Removed from cart' : 'Added to cart! Tap Cart to view.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    action: !inCart
                        ? SnackBarAction(
                            label: 'VIEW CART',
                            textColor: Colors.amberAccent,
                            onPressed: () => Navigator.pushNamed(context, '/cart'),
                          )
                        : null,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: inCart ? const Color(0xFFEF4444) : kBrandPrimary, width: 1.5),
                foregroundColor: inCart ? const Color(0xFFEF4444) : kBrandPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              child: Icon(
                inCart ? Icons.shopping_cart : Icons.add_shopping_cart_rounded,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),

            // 2. Direct Book Now Button (Skips Cart -> Direct Location & Payment Sheet)
            ElevatedButton(
              onPressed: () => _showDirectBookingModal(context, ref, service),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 0,
              ),
              child: const Row(
                children: [
                  Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDirectBookingModal(BuildContext context, WidgetRef ref, ServiceItem service) {
    String selectedDate = 'Today';
    String selectedSlot = '3:00 PM – 4:00 PM';
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final appState = ref.watch(bookingProvider);
            final liveAddress = appState.address.isNotEmpty && appState.address != 'Fetching live address...'
                ? appState.address
                : (appState.profile.primaryAddress?.formattedAddress ?? appState.selectedAddressTitle);

            final basePrice = service.price;
            final gstTax = basePrice * 0.18;
            final grandTotal = basePrice + gstTax;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        const Text(
                          'Direct Service Booking',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextNavy),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: kTextGray),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // 1. Service Summary Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: service.imageUrl.startsWith('assets/')
                                    ? Image.asset(
                                        service.imageUrl,
                                        width: 65,
                                        height: 65,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 65,
                                          height: 65,
                                          color: const Color(0xFFEFF6FF),
                                          child: const Icon(Icons.handyman_rounded, color: kBrandPrimary),
                                        ),
                                      )
                                    : Image.network(
                                        service.imageUrl,
                                        width: 65,
                                        height: 65,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 65,
                                          height: 65,
                                          color: const Color(0xFFEFF6FF),
                                          child: const Icon(Icons.handyman_rounded, color: kBrandPrimary),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: kTextNavy),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${service.durationMinutes} mins • ${service.warrantyText}',
                                      style: const TextStyle(fontSize: 11.5, color: kTextGray),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${service.price.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBrandPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Current Live Location & Address Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 18),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Service Location',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(bookingProvider.notifier).autoAcquireGpsLocation();
                                    },
                                    child: const Text('Refresh GPS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appState.selectedAddressTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kTextNavy),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                liveAddress,
                                style: const TextStyle(fontSize: 12, color: kTextGray, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Service Schedule Selection
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Date & Time Slot',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: ['Today', 'Tomorrow'].map((d) {
                                  final isSel = selectedDate == d;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(d),
                                      selected: isSel,
                                      selectedColor: kBrandPrimary,
                                      labelStyle: TextStyle(
                                        color: isSel ? Colors.white : kPrimaryText,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      onSelected: (_) => setModalState(() => selectedDate = d),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  '10:00 AM – 11:00 AM',
                                  '1:00 PM – 2:00 PM',
                                  '3:00 PM – 4:00 PM',
                                  '5:00 PM – 6:00 PM',
                                ].map((slot) {
                                  final isSel = selectedSlot == slot;
                                  return ChoiceChip(
                                    label: Text(slot),
                                    selected: isSel,
                                    selectedColor: const Color(0xFF0F172A),
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : kPrimaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onSelected: (_) => setModalState(() => selectedSlot = slot),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Price Breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Service Charge', style: TextStyle(fontSize: 12.5, color: kTextGray)),
                                  Text('₹${basePrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: kTextNavy)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Visiting & Inspection Fee', style: TextStyle(fontSize: 12.5, color: kTextGray)),
                                  Text('FREE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF16A34A))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('GST (18%)', style: TextStyle(fontSize: 12.5, color: kTextGray)),
                                  Text('₹${gstTax.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: kTextNavy)),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextNavy)),
                                  Text('₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kBrandPrimary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. Direct Payment Action Buttons
                        const Text(
                          'Choose Payment Method:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy),
                        ),
                        const SizedBox(height: 10),

                        // Pay Online (Razorpay / UPI / Card)
                        ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setModalState(() => isProcessing = true);
                                  final code = 'BT-${10000000 + Random().nextInt(90000000)}';
                                  final bkgId = 'bkg_${DateTime.now().millisecondsSinceEpoch}';

                                  final booked = await ref.read(bookingProvider.notifier).confirmDirectServiceBooking(
                                        service: service,
                                        date: selectedDate,
                                        slot: selectedSlot,
                                        paymentMethod: 'ONLINE_RAZORPAY',
                                        customBookingCode: code,
                                        customBookingId: bkgId,
                                      );

                                  if (!ctx.mounted) return;
                                  Navigator.pop(modalCtx); // Close sheet

                                  final startOtp = booked?.otpCode.isNotEmpty == true ? booked!.otpCode : (1000 + Random().nextInt(9000)).toString();

                                  // Direct Dispatch to Live Tracking Page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookingStatusMapScreen(
                                        initialBookingData: {
                                          'id': booked?.id ?? bkgId,
                                          'bookingCode': booked?.id ?? code,
                                          'serviceName': service.name,
                                          'status': 'SEARCHING_TECHNICIAN',
                                          'scheduledSlot': '$selectedDate • $selectedSlot',
                                          'startServiceOtp': startOtp,
                                          'startOtpExpiresAt': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
                                          'fullAddress': liveAddress,
                                          'grandTotal': grandTotal,
                                          'paymentId': 'RZP_ONLINE_DIRECT',
                                        },
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Pay Online (Razorpay / UPI / Card)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Pay After Service (Cash on Delivery / UPI upon completion)
                        OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setModalState(() => isProcessing = true);
                                  final code = 'BT-${10000000 + Random().nextInt(90000000)}';
                                  final bkgId = 'bkg_${DateTime.now().millisecondsSinceEpoch}';

                                  final booked = await ref.read(bookingProvider.notifier).confirmDirectServiceBooking(
                                        service: service,
                                        date: selectedDate,
                                        slot: selectedSlot,
                                        paymentMethod: 'CASH_ON_DELIVERY',
                                        customBookingCode: code,
                                        customBookingId: bkgId,
                                      );

                                  if (!ctx.mounted) return;
                                  Navigator.pop(modalCtx); // Close sheet

                                  final startOtp = booked?.otpCode.isNotEmpty == true ? booked!.otpCode : (1000 + Random().nextInt(9000)).toString();

                                  // Direct Dispatch to Live Tracking Page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookingStatusMapScreen(
                                        initialBookingData: {
                                          'id': booked?.id ?? bkgId,
                                          'bookingCode': booked?.id ?? code,
                                          'serviceName': service.name,
                                          'status': 'SEARCHING_TECHNICIAN',
                                          'scheduledSlot': '$selectedDate • $selectedSlot',
                                          'startServiceOtp': startOtp,
                                          'startOtpExpiresAt': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
                                          'fullAddress': liveAddress,
                                          'grandTotal': grandTotal,
                                          'paymentId': 'PAY_AFTER_SERVICE',
                                        },
                                      ),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.handshake_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Pay After Service (Cash / UPI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
}

class _StepData {
  final String step;
  final String title;
  final String desc;
  const _StepData({required this.step, required this.title, required this.desc});
}

class _FaqData {
  final String q;
  final String a;
  const _FaqData({required this.q, required this.a});
}
