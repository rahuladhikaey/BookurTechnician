import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeadAlertDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> leadData;
  final VoidCallback onAccept;
  final VoidCallback? onDecline;

  const LeadAlertDialog({
    super.key,
    required this.leadData,
    required this.onAccept,
    this.onDecline,
  });

  static Future<bool?> show(BuildContext context, Map<String, dynamic> leadData, {required VoidCallback onAccept, VoidCallback? onDecline}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => LeadAlertDialog(
        leadData: leadData,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  @override
  ConsumerState<LeadAlertDialog> createState() => _LeadAlertDialogState();
}

class _LeadAlertDialogState extends ConsumerState<LeadAlertDialog> {
  @override
  Widget build(BuildContext context) {
    final title = widget.leadData['title'] ?? widget.leadData['serviceType'] ?? 'New Service Request';
    final address = widget.leadData['customerAddress'] ?? widget.leadData['address'] ?? 'Customer Premise';
    final distance = widget.leadData['distanceKm'] != null ? '${widget.leadData['distanceKm']} km away' : (widget.leadData['distance'] ?? 'Nearby Customer');
    final payout = widget.leadData['payoutAmount'] != null ? '₹${widget.leadData['payoutAmount']}' : (widget.leadData['payout'] != null ? '₹${widget.leadData['payout']}' : '₹450');
    final slot = widget.leadData['scheduledSlot'] ?? '1 Hour Service Window';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Badge Icon
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF93C5FD), width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Incoming Lead Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🎯 NEW JOB AUTO-ASSIGNED (15KM RADAR)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Slot & Distance info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(slot, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text(distance, style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w800)),
              ],
            ),

            const SizedBox(height: 16),

            // Address snippet card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Guaranteed Payout Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Guaranteed Partner Payout',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                  ),
                  Text(
                    payout,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Direct Open Job Action Button (Auto-Assigned)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  widget.onAccept();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'OPEN WORK DETAILS / START',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
