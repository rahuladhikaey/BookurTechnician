import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';
import 'tracking_screen.dart';

class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  ConsumerState<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    await ref.read(bookingProvider.notifier).loadBookingHistory();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final Set<String> seenIds = {};
    final List<Booking> allBookings = [];

    if (state.activeBooking != null) {
      allBookings.add(state.activeBooking!);
      seenIds.add(state.activeBooking!.id);
    }
    for (var b in state.bookingHistory) {
      if (!seenIds.contains(b.id)) {
        allBookings.add(b);
        seenIds.add(b.id);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kBrandPrimary),
            onPressed: _fetchHistory,
            tooltip: 'Refresh Bookings',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kBrandPrimary,
        onRefresh: _fetchHistory,
        child: _isLoading && allBookings.isEmpty
            ? const Center(child: CircularProgressIndicator(color: kBrandPrimary))
            : (allBookings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: kBrandPrimary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 60, color: kBrandPrimary),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No Bookings Yet',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kTextDark),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You haven\'t booked any services yet. Explore expert technicians near you and book instantly with guaranteed service warranty!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: kTextGray, height: 1.45),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('EXPLORE SERVICES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: allBookings.length,
                    itemBuilder: (_, i) => _BookingCard(booking: allBookings[i]),
                  )),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(booking.status);
    final statusColor = _statusColor(booking.status);
    final isLive = booking.status != BookingStatus.completed && booking.status != BookingStatus.cancelled;

    final serviceTitle = booking.services.isNotEmpty 
        ? booking.services.map((s) => s.name).join(', ') 
        : 'Technician Service';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLive ? kBrandPrimary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLive ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (isLive) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingTrackingScreen(bookingId: booking.id),
                ),
              );
            } else {
              Navigator.pushNamed(context, '/invoice', arguments: booking.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: ID and Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kBrandPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.build_circle_outlined, size: 18, color: kBrandPrimary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          booking.id,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Service Name
                Text(
                  serviceTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),

                // Address (if available)
                if (booking.address.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          booking.address,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Date & Time + Price Row
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      '${booking.date} • ${booking.timeSlot}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '₹${booking.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kBrandPrimary),
                    ),
                  ],
                ),

                const Divider(height: 22, color: Color(0xFFF1F5F9)),

                // Action buttons / OTP footer
                Row(
                  children: [
                    if (isLive && booking.otpCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 13, color: Color(0xFFB45309)),
                            const SizedBox(width: 4),
                            Text(
                              'Start OTP: ${booking.otpCode}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        if (isLive) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingTrackingScreen(bookingId: booking.id),
                            ),
                          );
                        } else {
                          Navigator.pushNamed(context, '/invoice', arguments: booking.id);
                        }
                      },
                      icon: Icon(isLive ? Icons.near_me_rounded : Icons.receipt_long_rounded, size: 14, color: kBrandPrimary),
                      label: Text(
                        isLive ? '📍 Track Live Location' : 'View Invoice',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kBrandPrimary),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return 'Searching Technician';
      case BookingStatus.techAssigned: return 'Tech Assigned';
      case BookingStatus.techAccepted: return 'Tech Accepted';
      case BookingStatus.techOnTheWay: return 'On the Way';
      case BookingStatus.techArrived: return 'Arrived';
      case BookingStatus.serviceStarted: return 'In Progress';
      case BookingStatus.forwarded: return 'Forwarded';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
    }
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.completed: return const Color(0xFF16A34A);
      case BookingStatus.cancelled: return const Color(0xFFDC2626);
      case BookingStatus.techOnTheWay:
      case BookingStatus.techArrived:
      case BookingStatus.serviceStarted: return const Color(0xFFD97706);
      default: return kBrandPrimary;
    }
  }
}

// ─── Invoice Screen ───────────────────────────────────────────────────────────

class InvoiceScreen extends ConsumerWidget {
  final String bookingId;
  const InvoiceScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final booking = [...state.bookingHistory, if (state.activeBooking != null) state.activeBooking!]
        .firstWhere((b) => b.id == bookingId,
            orElse: () => const Booking(id: '', services: [], date: '', timeSlot: '',
                status: BookingStatus.completed, baseCost: 0, gstTax: 0, grandTotal: 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Column(children: [
            const Icon(Icons.receipt_long, size: 48, color: kBrandPrimary),
            const SizedBox(height: 8),
            Text('Invoice #${booking.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${booking.date} • ${booking.timeSlot}', style: const TextStyle(color: kTextGray, fontSize: 13)),
          ])),
          const SizedBox(height: 24),
          const Divider(),
          ...booking.services.map((s) => _InvoiceRow(s.name, '₹${s.price.toStringAsFixed(2)}')),
          const Divider(height: 24),
          _InvoiceRow('Visit Fee', '₹${booking.visitFee.toStringAsFixed(2)}'),
          if (booking.discount > 0)
            _InvoiceRow('Discount', '-₹${booking.discount.toStringAsFixed(2)}', green: true),
          _InvoiceRow('GST (18%)', '₹${booking.gstTax.toStringAsFixed(2)}'),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('₹${booking.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kBrandPrimary)),
          ]),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kGreenSuccess.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.verified, color: kGreenSuccess),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment Confirmed', style: TextStyle(fontWeight: FontWeight.bold, color: kGreenSuccess)),
                Text('Transaction complete', style: TextStyle(fontSize: 12, color: kTextGray)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool green;
  const _InvoiceRow(this.label, this.value, {this.green = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kTextGray)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: green ? kGreenSuccess : kTextNavy)),
      ]),
    );
  }
}


