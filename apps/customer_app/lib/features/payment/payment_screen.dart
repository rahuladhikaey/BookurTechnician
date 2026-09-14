import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../review/review_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String technicianName;
  final int baseAmount;
  final int sparesAmount;
  final int gstAmount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.technicianName,
    required this.baseAmount,
    required this.sparesAmount,
    required this.gstAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;

  int get totalAmount =>
      widget.baseAmount + widget.sparesAmount + widget.gstAmount;

  void _processPayment() {
    setState(() => _isProcessing = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSuccessDialog();
      }
    });
  }

  void _showSuccessDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldGreen,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹$totalAmount paid via $_selectedPaymentMethod',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricGold,
                    foregroundColor: AppColors.obsidianBlack,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          bookingId: widget.bookingId,
                          technicianName: widget.technicianName,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'RATE SERVICE EXPERIENCE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBlack,
      appBar: AppBar(
        title: const Text('CHECKOUT & INVOICE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice Breakdown Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderGlow),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TAX INVOICE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          widget.bookingId,
                          style: const TextStyle(
                            color: AppColors.electricGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.borderGlow, height: 24),
                    _buildBillRow('Base Service Charge', '₹${widget.baseAmount}'),
                    const SizedBox(height: 10),
                    _buildBillRow('Materials & Spares', '₹${widget.sparesAmount}'),
                    const SizedBox(height: 10),
                    _buildBillRow('GST (18%)', '₹${widget.gstAmount}'),
                    const Divider(color: AppColors.borderGlow, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '₹$totalAmount',
                          style: const TextStyle(
                            color: AppColors.electricGold,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Payment Methods Header
              const Text(
                'SELECT PAYMENT METHOD',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),

              _buildPaymentOption(
                'UPI',
                'Google Pay, PhonePe, Paytm, BHIM',
                Icons.account_balance_wallet_rounded,
                AppColors.neonBlue,
              ),
              _buildPaymentOption(
                'Cards',
                'Credit / Debit Card (Visa, Mastercard, RuPay)',
                Icons.credit_card_rounded,
                AppColors.emeraldGreen,
              ),
              _buildPaymentOption(
                'Cash / QR',
                'Pay directly to technician via cash or QR',
                Icons.qr_code_scanner_rounded,
                AppColors.electricGold,
              ),

              const SizedBox(height: 36),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.obsidianBlack,
                          ),
                        )
                      : Text(
                          'PAY ₹$totalAmount SECURELY',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    String key,
    String subtitle,
    IconData icon,
    Color accentColor,
  ) {
    final isSelected = _selectedPaymentMethod == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.electricGold : AppColors.borderGlow,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? AppColors.electricGold
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
