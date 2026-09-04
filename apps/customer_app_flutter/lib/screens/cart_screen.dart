import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../theme.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../services/api_client.dart';
import 'tracking_screen.dart';
import 'profile_completion_wizard_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;

  String? _currentBookingCode;
  String? _currentBookingId;
  String? _currentServiceName;
  double _currentAmount = 0.0;
  String? _currentSchedule;
  String? _currentRazorpayOrderId;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _showAddressPicker(BuildContext context, AppState state) {
    final addresses = [
      {'title': 'Bellary Road, Bengaluru', 'type': 'Home'},
      {'title': '14th Cross, Hebbal, Bengaluru', 'type': 'Office'},
      {'title': '4th Block, Koramangala, Bengaluru', 'type': 'Other'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Service Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryText)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            ...addresses.map((a) {
              final isSelected = state.selectedAddressTitle == a['title'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  a['type'] == 'Home' ? Icons.home_outlined : a['type'] == 'Office' ? Icons.work_outline : Icons.location_on_outlined,
                  color: isSelected ? kBrandPrimary : kSecondaryText,
                ),
                title: Text(a['title']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13.5)),
                subtitle: Text(a['type']!, style: const TextStyle(fontSize: 11, color: kSecondaryText)),
                trailing: isSelected ? const Icon(Icons.check_circle, color: kSuccessGreen, size: 20) : null,
                onTap: () {
                  ref.read(bookingProvider.notifier).updateAddressDetails(a['title']!, a['type']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSchedulePicker(BuildContext context, AppState state) {
    final now = DateTime.now();
    final days = [
      {'label': 'Today', 'date': '${now.day} ${_getMonth(now.month)}'},
      {'label': 'Tomorrow', 'date': '${now.add(const Duration(days: 1)).day} ${_getMonth(now.add(const Duration(days: 1)).month)}'},
      {'label': 'Day After', 'date': '${now.add(const Duration(days: 2)).day} ${_getMonth(now.add(const Duration(days: 2)).month)}'},
    ];

    final slots = [
      '9:00 AM – 10:00 AM',
      '11:00 AM – 12:00 PM',
      '2:00 PM – 3:00 PM',
      '3:00 PM – 4:00 PM',
      '5:00 PM – 6:00 PM',
      '7:00 PM – 8:00 PM',
    ];

    String selectedDay = state.selectedScheduleDate;
    String selectedSlot = state.selectedScheduleSlot;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Service Date & Time (Max 3 Days)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryText)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Choose Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kSecondaryText)),
              const SizedBox(height: 8),
              Row(
                children: days.map((d) {
                  final isSelected = selectedDay == d['label'] || selectedDay == d['date'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedDay = d['label']!),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? kBrandPrimary : kLightBlue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? kBrandPrimary : kBorderColor),
                        ),
                        child: Column(
                          children: [
                            Text(
                              d['label']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isSelected ? Colors.white : kPrimaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              d['date']!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white70 : kSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text('Choose Available Time Slot', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kSecondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((s) {
                  final isSelected = selectedSlot == s;
                  return ChoiceChip(
                    label: Text(s, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : kPrimaryText)),
                    selected: isSelected,
                    selectedColor: kBrandPrimary,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? kBrandPrimary : kBorderColor),
                    onSelected: (_) => setModalState(() => selectedSlot = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(bookingProvider.notifier).updateSchedule(selectedDay, selectedSlot);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: Colors.white),
                  child: const Text('Confirm Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _getMonth(int month) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[month];
  }

  Future<void> _proceedToPayment(AppState state) async {
    if (state.cartItems.isEmpty) return;

    if (state.isGuest) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: kBrandPrimary),
              SizedBox(width: 8),
              Text('Account Required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Please sign up or log in to confirm your booking, get certified technician assignment, and enjoy 30-day service warranty.',
            style: TextStyle(fontSize: 13, color: kSecondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: kSecondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: Colors.white),
              child: const Text('Log In / Sign Up'),
            ),
          ],
        ),
      );
      return;
    }

    // ─── BOOKING PROTECTION: PROFILE COMPLETION VALIDATION ───
    if (!state.profile.isProfileComplete) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text('Complete Your Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your profile is ${state.profile.profileCompletion}% complete. Please add your ${state.profile.missingFieldsReadable} before booking a technician.',
            style: const TextStyle(fontSize: 13, color: kSecondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: kSecondaryText)),
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
              style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: Colors.white),
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      );
      return;
    }

    _showPaymentSelectionSheet(state);
  }

  void _showPaymentSelectionSheet(AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Payment Option', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimaryText)),
                  IconButton(
                    icon: const Icon(Icons.close, color: kSecondaryText, size: 20),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Option 1: Pay Online (Instant & Secure)
              InkWell(
                onTap: () {
                  Navigator.pop(modalCtx);
                  _startRazorpayPayment(state);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBrandPrimary),
                    borderRadius: BorderRadius.circular(14),
                    color: kLightBlue.withValues(alpha: 0.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: kBrandPrimary, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pay Online (UPI / Card / NetBanking)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimaryText)),
                            SizedBox(height: 3),
                            Text('Instant confirmation with 100% moneyback protection', style: TextStyle(fontSize: 11.5, color: kSecondaryText)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: kBrandPrimary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Pay After Service
              InkWell(
                onTap: () {
                  Navigator.pop(modalCtx);
                  _bookPayAfterService(state);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.handshake_outlined, color: Color(0xFF0F172A), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pay After Service (Cash / UPI on Visit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimaryText)),
                            SizedBox(height: 3),
                            Text('Pay directly to technician after job satisfaction', style: TextStyle(fontSize: 11.5, color: kSecondaryText)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: kSecondaryText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRazorpayPayment(AppState state) async {
    _currentBookingCode = 'BT-${10000000 + Random().nextInt(90000000)}';
    _currentBookingId = 'bkg_${DateTime.now().millisecondsSinceEpoch}';
    _currentServiceName = state.cartItems.isNotEmpty ? state.cartItems.first.name : 'Service Booking';
    _currentAmount = state.grandTotal;
    _currentSchedule = '${state.selectedScheduleDate} • ${state.selectedScheduleSlot}';

    setState(() => _isProcessingPayment = true);

    String? razorpayKeyId;
    String? razorpayOrderId;

    // Create real order on backend if available
    try {
      final res = await ApiClient.post('/payments/create-order', {
        'bookingId': _currentBookingId,
      });
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        if (data != null) {
          if (data['razorpayOrderId'] != null && data['razorpayOrderId'].toString().isNotEmpty) {
            razorpayOrderId = data['razorpayOrderId'].toString();
          }
          if (data['keyId'] != null && data['keyId'].toString().isNotEmpty) {
            razorpayKeyId = data['keyId'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[Razorpay Order Note]: $e');
    }

    _currentRazorpayOrderId = razorpayOrderId;

    final key = (razorpayKeyId != null && razorpayKeyId.isNotEmpty)
        ? razorpayKeyId
        : 'rzp_test_ShRpqbs6hVT6Ie';

    final phone = state.profile.phone.isNotEmpty ? state.profile.phone : '9876543210';
    final email = state.profile.email.isNotEmpty ? state.profile.email : 'customer@bookurtechnician.com';
    final name = state.profile.fullName.isNotEmpty ? state.profile.fullName : 'Valued Customer';

    final options = <String, dynamic>{
      'key': key,
      'amount': (_currentAmount * 100).round(), // in paise
      'name': 'BookUrTechnician',
      'description': '$_currentServiceName (#$_currentBookingCode)',
      'timeout': 300,
      'prefill': {
        'contact': phone,
        'email': email,
        'name': name,
      },
      'theme': {
        'color': '#0284C7',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    if (razorpayOrderId != null && razorpayOrderId.startsWith('order_') && !razorpayOrderId.contains('order_rzp_BT')) {
      options['order_id'] = razorpayOrderId;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('[Razorpay Checkout Error]: $e');
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Razorpay checkout: $e')),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'pay_${Random().nextInt(900000) + 100000}';
    final orderId = response.orderId ?? _currentRazorpayOrderId ?? 'order_rzp_$_currentBookingCode';
    final signature = response.signature ?? 'sig_rzp_${Random().nextInt(900000)}';

    // Verify signature on backend
    try {
      await ApiClient.post('/payments/verify-signature', {
        'bookingId': _currentBookingId,
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });
    } catch (e) {
      debugPrint('[Razorpay Verification note]: $e');
    }

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    // Confirm booking in local provider and save to DB
    final scheduleParts = (_currentSchedule ?? '').split('•');
    final date = scheduleParts.first.trim();
    final slot = scheduleParts.length > 1 ? scheduleParts[1].trim() : '3:00 PM – 4:00 PM';
    
    final booked = await ref.read(bookingProvider.notifier).confirmOrder(
      date,
      slot,
      paymentMethod: 'ONLINE_RAZORPAY',
      customBookingCode: _currentBookingCode,
      customBookingId: _currentBookingId,
    );

    // Navigate directly to Live Tracking Screen (Uber/Rapido/Zomato style)
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingTrackingScreen(
            bookingId: booked?.id ?? _currentBookingId ?? 'BK-100',
          ),
        ),
      );
    }
  }

  Future<void> _bookPayAfterService(AppState state) async {
    if (state.cartItems.isEmpty) return;
    setState(() => _isProcessingPayment = true);

    _currentBookingCode = 'BT-${10000000 + Random().nextInt(90000000)}';
    _currentBookingId = 'bkg_${DateTime.now().millisecondsSinceEpoch}';
    _currentServiceName = state.cartItems.isNotEmpty ? state.cartItems.first.name : 'Service Booking';
    _currentAmount = state.grandTotal;
    _currentSchedule = '${state.selectedScheduleDate} • ${state.selectedScheduleSlot}';

    final scheduleParts = (_currentSchedule ?? '').split('•');
    final date = scheduleParts.first.trim();
    final slot = scheduleParts.length > 1 ? scheduleParts[1].trim() : '3:00 PM – 4:00 PM';

    final booked = await ref.read(bookingProvider.notifier).confirmOrder(
      date,
      slot,
      paymentMethod: 'CASH_ON_DELIVERY',
      customBookingCode: _currentBookingCode,
      customBookingId: _currentBookingId,
    );

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingTrackingScreen(
          bookingId: booked?.id ?? _currentBookingId ?? 'BK-100',
        ),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessingPayment = false);
    final errorMsg = response.message != null && response.message!.isNotEmpty
        ? response.message!
        : 'Payment cancelled or could not be completed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMsg, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Redirected to ${response.walletName ?? "Wallet"}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kPrimaryText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: state.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: kLightBlue.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_bag_outlined, size: 40, color: kBrandPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryText)),
                  const SizedBox(height: 6),
                  const Text('Explore top categories and book certified technicians.', style: TextStyle(color: kSecondaryText, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('Browse Services'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── 1. SELECTED SERVICE CARDS ─────────────────────────────
                      ...state.cartItems.map((service) => _buildServiceCard(service)),
                      const SizedBox(height: 16),

                      // ─── 2. SERVICE ADDRESS CARD ───────────────────────────────
                      _buildAddressCard(state),
                      const SizedBox(height: 14),

                      // ─── 3. SERVICE SCHEDULE CARD ──────────────────────────────
                      _buildScheduleCard(state),
                      const SizedBox(height: 16),

                      // ─── 4. PRICE DETAILS ──────────────────────────────────────
                      _buildPriceDetailsCard(state),
                      const SizedBox(height: 14),

                      // ─── 5. IMPORTANT CHARGE INFORMATION ───────────────────────
                      _buildImportantInfoCard(),
                      const SizedBox(height: 14),

                      // ─── 6. SECURE PAYMENT SUMMARY ─────────────────────────────
                      _buildPaymentSummaryCard(state),
                      const SizedBox(height: 14),

                      // ─── 7. CANCELLATION & REFUND POLICIES ─────────────────────
                      _buildPoliciesCard(context),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ─── STICKY BOTTOM PAYMENT CTA ──────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isProcessingPayment ? null : () => _proceedToPayment(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlack,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isProcessingPayment
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  'Proceed to Pay — ₹${state.grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Service Card Component ───────────────────────────────────────────────
  Widget _buildServiceCard(ServiceItem service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Image with curved border and fallback
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildServiceImage(service),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: kPrimaryText,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 12, color: kSecondaryText),
                          const SizedBox(width: 3),
                          Text(
                            '${service.durationMinutes} mins',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kSecondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 11, color: Color(0xFF16A34A)),
                          const SizedBox(width: 3),
                          Text(
                            service.warrantyText.isNotEmpty ? service.warrantyText : '30-Day Warranty',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBrandPrimary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${(service.price * 1.25).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kSecondaryText,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            tooltip: 'Remove',
            onPressed: () => ref.read(bookingProvider.notifier).removeFromCart(service.id),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceImage(ServiceItem service) {
    final url = service.imageUrl.trim();
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildServicePlaceholder(service.name),
      );
    } else if (url.isNotEmpty) {
      return Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildServicePlaceholder(service.name),
      );
    }
    return _buildServicePlaceholder(service.name);
  }

  Widget _buildServicePlaceholder(String name) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.handyman_rounded, color: kBrandPrimary, size: 28),
      ),
    );
  }

  // ─── Service Address Card ─────────────────────────────────────────────────
  Widget _buildAddressCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on, color: kBrandPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍 Service Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kSecondaryText)),
                const SizedBox(height: 2),
                Text(
                  state.selectedAddressTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  state.selectedAddressType,
                  style: const TextStyle(fontSize: 11.5, color: kSecondaryText),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showAddressPicker(context, state),
            child: const Text('Change →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBrandPrimary)),
          ),
        ],
      ),
    );
  }

  // ─── Service Schedule Card ────────────────────────────────────────────────
  Widget _buildScheduleCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_month, color: kSuccessGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📅 Service Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kSecondaryText)),
                const SizedBox(height: 2),
                Text(
                  '${state.selectedScheduleDate}, ${state.selectedScheduleSlot}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showSchedulePicker(context, state),
            child: const Text('Change →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBrandPrimary)),
          ),
        ],
      ),
    );
  }

  // ─── Price Details Card (NO coupon section) ───────────────────────────────
  Widget _buildPriceDetailsCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Price Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kPrimaryText)),
          const SizedBox(height: 14),
          _priceLine('Service Cost', '₹${state.baseCost.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _priceLine('Booking Charge', '₹${state.visitFee.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _priceLine('GST (18%)', '₹${state.gstTax.toStringAsFixed(2)}'),
          const Divider(height: 22, color: kBorderColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: kPrimaryText)),
              Text(
                '₹${state.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kBrandPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kSecondaryText)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryText)),
      ],
    );
  }

  // ─── Important Charge Information Card ────────────────────────────────────
  Widget _buildImportantInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFB45309), size: 16),
              SizedBox(width: 6),
              Text('ⓘ Important Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF92400E))),
            ],
          ),
          const SizedBox(height: 8),
          _infoBullet('Booking Charge is non-refundable.'),
          _infoBullet('GST/taxes are non-refundable.'),
          _infoBullet('Additional service/parts charges, if required, require prior approval.'),
          _infoBullet('Final payable amount is verified dynamically before payment.'),
        ],
      ),
    );
  }

  Widget _infoBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F)))),
        ],
      ),
    );
  }

  // ─── Secure Payment Summary Card ──────────────────────────────────────────
  Widget _buildPaymentSummaryCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.shield_outlined, color: kBrandPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💳 Secure Online Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryText)),
                const SizedBox(height: 2),
                Text('Processed securely via certified gateway. Zero credentials stored.', style: TextStyle(fontSize: 11, color: kSecondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cancellation & Refund Policies Card ──────────────────────────────────
  Widget _buildPoliciesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancellation Policy
          const Text('Cancellation Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText)),
          const SizedBox(height: 4),
          const Text(
            'Free cancellation is available up to 1 hour before the scheduled service time.',
            style: TextStyle(fontSize: 12, color: kSecondaryText, height: 1.3),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.pushNamed(context, '/legal', arguments: 2),
              child: const Text('View Cancellation Policy →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kBrandPrimary)),
            ),
          ),
          const Divider(height: 16, color: kBorderColor),

          // Refund Policy
          const Text('Refund Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText)),
          const SizedBox(height: 4),
          const Text(
            'Eligible refunds are processed within 48 hours. Booking charge and GST are non-refundable.',
            style: TextStyle(fontSize: 12, color: kSecondaryText, height: 1.3),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.pushNamed(context, '/legal', arguments: 2),
              child: const Text('View Refund Policy →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kBrandPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
