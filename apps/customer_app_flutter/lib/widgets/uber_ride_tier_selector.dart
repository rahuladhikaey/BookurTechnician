import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/radar_matching_sheet.dart';
import '../screens/profile_completion_wizard_screen.dart';
import '../services/api_client.dart';

enum BookingMode { instantDispatch, scheduleForLater }

enum ServiceTier {
  expressDispatch(
    title: 'Instant Fast Dispatch',
    subtitle: 'Nearest partner dispatched in < 15 mins',
    eta: '4-7 mins away',
    multiplier: 1.0,
    badge: 'FASTEST',
    icon: Icons.bolt_rounded,
  ),
  masterSpecialist(
    title: 'Master Specialist Pro',
    subtitle: '5+ yrs exp, top 1% rated technician',
    eta: '8-12 mins away',
    multiplier: 1.25,
    badge: 'TOP RATED',
    icon: Icons.verified_rounded,
  ),
  standardService(
    title: 'Standard Certified',
    subtitle: 'Background-verified partner with standard toolkit',
    eta: '10-15 mins away',
    multiplier: 0.95,
    badge: 'POPULAR',
    icon: Icons.build_circle_outlined,
  ),
  emergencySos(
    title: 'Emergency SOS 24/7',
    subtitle: 'Highest priority dispatch for urgent breakdowns',
    eta: '2-4 mins away',
    multiplier: 1.45,
    badge: 'PRIORITY',
    icon: Icons.notification_important_rounded,
  );

  final String title;
  final String subtitle;
  final String eta;
  final double multiplier;
  final String badge;
  final IconData icon;

  const ServiceTier({
    required this.title,
    required this.subtitle,
    required this.eta,
    required this.multiplier,
    required this.badge,
    required this.icon,
  });
}

class UberRideTierSelectorSheet extends ConsumerStatefulWidget {
  final ServiceItem service;
  final List<ServiceItem>? bundleServices;

  const UberRideTierSelectorSheet({
    super.key,
    required this.service,
    this.bundleServices,
  });

  static Future<void> show(
    BuildContext context, {
    required ServiceItem service,
    List<ServiceItem>? bundleServices,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UberRideTierSelectorSheet(
        service: service,
        bundleServices: bundleServices,
      ),
    );
  }

  @override
  ConsumerState<UberRideTierSelectorSheet> createState() => _UberRideTierSelectorSheetState();
}

class _UberRideTierSelectorSheetState extends ConsumerState<UberRideTierSelectorSheet> {
  ServiceTier _selectedTier = ServiceTier.expressDispatch;
  BookingMode _bookingMode = BookingMode.instantDispatch;
  String _selectedDate = 'Today';
  String _selectedSlot = 'Immediate (Next Available)';
  String _paymentMethod = 'ONLINE'; // 'ONLINE' or 'CASH'
  bool _includeProtectionPlan = true;
  final double _protectionPlanFee = 49.0;

  final List<String> _dateOptions = ['Today', 'Tomorrow', 'In 2 Days'];
  final List<String> _slotOptions = [
    'Immediate (Next Available)',
    '10:00 AM - 12:00 PM',
    '12:00 PM - 02:00 PM',
    '02:00 PM - 04:00 PM',
    '04:00 PM - 06:00 PM',
    '06:00 PM - 08:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDynamicSlots(_selectedDate);
  }

  Future<void> _fetchDynamicSlots(String date) async {
    try {
      final srvId = widget.service.id.isNotEmpty ? widget.service.id : 'srv-default';
      final resp = await ApiClient.get('/catalog/services/$srvId/slots?date=${Uri.encodeComponent(date)}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && data['slots'] is List) {
          final fetched = (data['slots'] as List).map((s) => s['time']?.toString() ?? s.toString()).toList();
          if (fetched.isNotEmpty && mounted) {
            setState(() {
              _slotOptions.clear();
              _slotOptions.addAll(fetched);
              if (!_slotOptions.contains(_selectedSlot)) {
                _selectedSlot = _slotOptions.first;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  double get _baseFare {
    if (widget.bundleServices != null && widget.bundleServices!.isNotEmpty) {
      return widget.bundleServices!.fold(0.0, (sum, s) => sum + s.price);
    }
    return widget.service.price;
  }

  double get _tierFare => _baseFare * _selectedTier.multiplier;
  double get _gst => _tierFare * 0.18;
  double get _grandTotal => _tierFare + _gst + (_includeProtectionPlan ? _protectionPlanFee : 0.0);

  void _onConfirmBooking(AppState state) {
    // 1. Profile Verification Check
    if (!state.profile.isProfileComplete) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: kBlack, size: 24),
              SizedBox(width: 10),
              Text('Complete Profile First', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Text(
            'For driver & technician safety, please add your ${state.profile.missingFieldsReadable} before requesting dispatch.',
            style: const TextStyle(color: kSecondaryText, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: kSecondaryText, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileCompletionWizardScreen(returnToCartOnComplete: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: kWhite),
              child: const Text('Complete Now'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Strict Real-Time Technician Availability Check (Option B)
    final onlineCount = state.getServiceAvailabilityCount(widget.service.id);
    if (onlineCount == 0 && _bookingMode == BookingMode.instantDispatch) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.radar_rounded, color: kBlack, size: 24),
              SizedBox(width: 10),
              Text('No Partner in 15 KM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Text(
            'There are currently 0 verified specialists active within 15 km for "${widget.service.name}".\n\nYou can schedule for later or try again shortly.',
            style: const TextStyle(color: kSecondaryText, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: kWhite),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    // 3. Launch the Uber/Rapido Radar Scanning & Matching Sheet
    Navigator.pop(context); // Close tier selector
    RadarMatchingSheet.show(
      context,
      service: widget.service,
      selectedTier: _selectedTier,
      bookingMode: _bookingMode,
      selectedDate: _selectedDate,
      selectedSlot: _selectedSlot,
      paymentMethod: _paymentMethod,
      grandTotal: _grandTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final count = state.getServiceAvailabilityCount(widget.service.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header: Service Name & Location Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kBlack,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: kSuccessGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$count ONLINE NEARBY',
                                      style: const TextStyle(
                                        color: kWhite,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '• 15 km Uber-grade radius',
                                style: TextStyle(color: kSecondaryText, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.service.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: kBlack,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.address.isNotEmpty
                                ? state.address
                                : 'Select delivery/service address',
                            style: const TextStyle(fontSize: 12.5, color: kSecondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kBlack, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: kBorderColor),

              // Scrollable Options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    // Mode Toggle (Instant Dispatch vs Schedule)
                    _buildModeToggle(),
                    const SizedBox(height: 18),

                    // Schedule Date & Slot (Only if Schedule Mode)
                    if (_bookingMode == BookingMode.scheduleForLater) ...[
                      _buildSchedulePicker(),
                      const SizedBox(height: 18),
                    ],

                    // Uber-Style Service Tiers
                    const Text(
                      'CHOOSE DISPATCH TIER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: kSecondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...ServiceTier.values.map((tier) => _buildTierCard(tier)),
                    const SizedBox(height: 16),

                    // Protection Plan Add-On
                    _buildProtectionCard(),
                    const SizedBox(height: 16),

                    // Payment Method Selector
                    _buildPaymentSelector(),
                    const SizedBox(height: 16),

                    // Upfront Price Breakdown
                    _buildPriceSummary(),
                  ],
                ),
              ),

              // Sticky Bottom Action Bar
              _buildStickyCta(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _bookingMode = BookingMode.instantDispatch),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _bookingMode == BookingMode.instantDispatch ? kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: _bookingMode == BookingMode.instantDispatch ? kWhite : kBlack,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Instant Dispatch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _bookingMode == BookingMode.instantDispatch ? kWhite : kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _bookingMode = BookingMode.scheduleForLater),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _bookingMode == BookingMode.scheduleForLater ? kBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: _bookingMode == BookingMode.scheduleForLater ? kWhite : kBlack,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Schedule Trip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _bookingMode == BookingMode.scheduleForLater ? kWhite : kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT DATE & TIME SLOT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kSecondaryText, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          // Dates
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dateOptions.map((date) {
                final isSelected = _selectedDate == date;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(date),
                    selected: isSelected,
                    selectedColor: kBlack,
                    backgroundColor: kWhite,
                    labelStyle: TextStyle(
                      color: isSelected ? kWhite : kBlack,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? kBlack : kBorderColor),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDate = date);
                        _fetchDynamicSlots(date);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Slots
          DropdownButtonFormField<String>(
            value: _slotOptions.contains(_selectedSlot) ? _selectedSlot : (_slotOptions.isNotEmpty ? _slotOptions.first : null),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: kWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
            ),
            items: _slotOptions
                .map((slot) => DropdownMenuItem(value: slot, child: Text(slot, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedSlot = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(ServiceTier tier) {
    final isSelected = _selectedTier == tier;
    final fare = _baseFare * tier.multiplier;

    return GestureDetector(
      onTap: () => setState(() => _selectedTier = tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kBlack : kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kBlack : kBorderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Tier Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tier.icon,
                color: isSelected ? kWhite : kBlack,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Tier Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tier.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? kWhite : kBlack,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? kWhite : kBlack,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tier.badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? kBlack : kWhite,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${tier.eta} • ${tier.subtitle}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isSelected ? const Color(0xFFA1A1AA) : kSecondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Pricing
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? kWhite : kBlack,
                  ),
                ),
                Text(
                  'incl. GST',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? const Color(0xFFA1A1AA) : kSecondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: kBlack, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30-Day Royal Protection Guarantee',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlack),
                ),
                SizedBox(height: 2),
                Text(
                  '100% damage warranty & free revisit cover (₹49)',
                  style: TextStyle(fontSize: 11, color: kSecondaryText),
                ),
              ],
            ),
          ),
          Switch(
            value: _includeProtectionPlan,
            activeThumbColor: kBlack,
            onChanged: (val) => setState(() => _includeProtectionPlan = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAYMENT METHOD',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kSecondaryText, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'ONLINE'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'ONLINE' ? kBlack : kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _paymentMethod == 'ONLINE' ? kBlack : kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: _paymentMethod == 'ONLINE' ? kWhite : kBlack,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online / UPI',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _paymentMethod == 'ONLINE' ? kWhite : kBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'CASH'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'CASH' ? kBlack : kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _paymentMethod == 'CASH' ? kBlack : kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: _paymentMethod == 'CASH' ? kWhite : kBlack,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pay After Job',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _paymentMethod == 'CASH' ? kWhite : kBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selectedTier.title} Base Fare', style: const TextStyle(color: kSecondaryText, fontSize: 13)),
              Text('₹${_tierFare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15 KM Express Dispatch Fee', style: TextStyle(color: kSecondaryText, fontSize: 13)),
              Text('FREE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kSuccessGreen)),
            ],
          ),
          if (_includeProtectionPlan) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('30-Day Warranty Cover', style: TextStyle(color: kSecondaryText, fontSize: 13)),
                Text('₹${_protectionPlanFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Applicable GST (18%)', style: TextStyle(color: kSecondaryText, fontSize: 13)),
              Text('₹${_gst.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const Divider(height: 18, color: kBorderColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Upfront Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kBlack)),
              Text(
                '₹${_grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCta(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => _onConfirmBooking(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlack,
              foregroundColor: kWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 20, color: kWhite),
                    const SizedBox(width: 8),
                    Text(
                      _bookingMode == BookingMode.instantDispatch
                          ? 'REQUEST ${_selectedTier.title.toUpperCase()}'
                          : 'CONFIRM SCHEDULED DISPATCH',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.2),
                    ),
                  ],
                ),
                Text(
                  '₹${_grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
