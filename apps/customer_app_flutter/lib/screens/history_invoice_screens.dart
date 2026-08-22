import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';

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
    final allBookings = [
      if (state.activeBooking != null) state.activeBooking!,
      ...state.bookingHistory,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
            tooltip: 'Refresh Bookings',
          ),
        ],
      ),
      body: RefreshIndicator(
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
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kBrandPrimary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 54, color: kBrandPrimary),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No Bookings Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You haven\'t booked any services yet. Explore expert technicians near you and book instantly!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: kTextGray, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('EXPLORE SERVICES', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (booking.status != BookingStatus.completed && booking.status != BookingStatus.cancelled) {
            Navigator.pushNamed(context, '/tracking', arguments: booking.id);
          } else {
            Navigator.pushNamed(context, '/invoice', arguments: booking.id);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(booking.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(booking.services.map((s) => s.name).join(', '),
                style: const TextStyle(fontSize: 13, color: kTextGray)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_today, size: 12, color: kTextGray),
              const SizedBox(width: 4),
              Text('${booking.date} • ${booking.timeSlot}', style: const TextStyle(fontSize: 12, color: kTextGray)),
              const Spacer(),
              Text('₹${booking.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kBrandPrimary)),
            ]),
          ]),
        ),
      ),
    );
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return 'Confirmed';
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
      case BookingStatus.completed: return kGreenSuccess;
      case BookingStatus.cancelled: return kRedError;
      case BookingStatus.techOnTheWay:
      case BookingStatus.techArrived: return kBrandSecondary;
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
