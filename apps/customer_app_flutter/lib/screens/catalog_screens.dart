import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';

class CategoryServicesScreen extends ConsumerWidget {
  final String categoryId;
  const CategoryServicesScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final category = state.categories.firstWhere((c) => c.id == categoryId,
        orElse: () => const Category(id: '', name: '', subcategories: []));

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: category.subcategories.length,
        itemBuilder: (_, i) {
          final sub = category.subcategories[i];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(sub.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextNavy)),
            ),
            ...sub.services.map((service) => _ServiceCard(service: service)),
          ]);
        },
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
      padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 4),
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
                      const Text(
                        'Book a Technician',
                        style: TextStyle(
                          fontSize: 10,
                          color: kTextGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              width: 130,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(bookingProvider.notifier).toggleCartItem(service);
                  if (!inCart) Navigator.pushNamed(context, '/cart');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: inCart ? const Color(0xFFEF4444) : kBlack,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  inCart ? 'Remove' : 'Book Now',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
