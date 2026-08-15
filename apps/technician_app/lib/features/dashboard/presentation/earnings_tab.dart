import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import 'dashboard_provider.dart';

class EarningsTab extends ConsumerStatefulWidget {
  const EarningsTab({super.key});

  @override
  ConsumerState<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends ConsumerState<EarningsTab> {
  late final TextEditingController _upiController;
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isEditingUpi = false;
  bool _isVerifyingPin = false;

  @override
  void initState() {
    super.initState();
    final savedUpi = ref.read(dashboardProvider).savedUpiId;
    _upiController = TextEditingController(text: savedUpi);
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleSaveUpi() {
    final upi = _upiController.text.trim();
    if (upi.isEmpty || (!upi.contains('@') && upi.length != 10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID (e.g. name@upi) or 10-digit UPI Mobile Number.'),
          backgroundColor: SemanticColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingPin = true;
    });
  }

  void _submitPinAndUpdateUpi() {
    if (_pinController.text.trim() == '1234') {
      final formattedUpi = _upiController.text.trim().contains('@')
          ? _upiController.text.trim()
          : '${_upiController.text.trim()}@upi';

      ref.read(dashboardProvider.notifier).updateUpiId(formattedUpi);

      setState(() {
        _isVerifyingPin = false;
        _isEditingUpi = false;
        _pinController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('UPI Payout ID updated to $formattedUpi successfully!'),
          backgroundColor: SemanticColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect Security PIN. Please try again (Demo: 1234).'),
          backgroundColor: SemanticColors.error,
        ),
      );
    }
  }

  void _openWithdrawModal(BuildContext context, double availableBalance, String currentUpi) {
    _amountController.text = availableBalance.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardHeight + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Instant UPI Withdrawal',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD9E2F2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payout Destination (UPI)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(currentUpi, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                          child: const Text('✓ Verified', style: TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Enter Withdrawal Amount (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick preset chips
                  Row(
                    children: [500, 1000, 2000].map((preset) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text('₹$preset', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          backgroundColor: AppColors.primaryLight,
                          side: const BorderSide(color: Color(0xFFD9E2F2)),
                          onPressed: () {
                            if (preset <= availableBalance) {
                              setModalState(() {
                                _amountController.text = preset.toString();
                              });
                            }
                          },
                        ),
                      );
                    }).toList()
                      ..add(
                        Padding(
                          padding: const EdgeInsets.only(right: 0),
                          child: ActionChip(
                            label: const Text('All Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.primary, width: 1.2),
                            onPressed: () {
                              setModalState(() {
                                _amountController.text = availableBalance.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                      ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                        if (amt <= 0 || amt > availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount within your wallet balance.')),
                          );
                          return;
                        }

                        final success = ref.read(dashboardProvider.notifier).withdrawToUpi(
                              amount: amt,
                              upiId: currentUpi,
                            );

                        if (success) {
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('₹${amt.toStringAsFixed(0)} transferred instantly to $currentUpi!'),
                              backgroundColor: SemanticColors.success,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm Instant UPI Transfer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final netEarnings = dashState.netEarnings;
    final savedUpi = dashState.savedUpiId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Wallet & Instant UPI Payouts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. WALLET BALANCE CARD WITH INSTANT WITHDRAWAL CTA ─────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332146A8),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL WITHDRAWABLE BALANCE',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      Text(
                        '⚡ Instant UPI',
                        style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${netEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: netEarnings > 0 ? () => _openWithdrawModal(context, netEarnings, savedUpi) : null,
                      icon: const Icon(Icons.flash_on_rounded, size: 18, color: AppColors.primary),
                      label: const Text('Withdraw Money via UPI', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Platform Commission: 10% applied', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                      Text('Zero Bank Transfer Delays', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.m),

            // ─── 2. ACTIVE PARTNER INCENTIVES ────────────────────────────────
            const Text('Active Partner Incentives', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Weekly Target Bonus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Reward: ₹1,000', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const Text(
                      'Complete 20 jobs this week and maintain a rating of 4.5★ or above.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Weekly Progress (12 / 20 Jobs)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        Text('8 jobs remaining', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 12 / 20,
                        minHeight: 8,
                        backgroundColor: Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(SemanticColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.m),

            // ─── 3. UPI PAYOUT ROUTING (REPLACES BANK DETAILS) ───────────────
            const Text('UPI Payout Routing & Wallet Destination', style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'No bank account details required. Earnings are directly credited to your UPI ID or mobile number.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: _isVerifyingPin
                    ? Column(
                        children: [
                          const Icon(Icons.lock_outline, color: SemanticColors.warning, size: 36),
                          const SizedBox(height: AppSpacing.s),
                          const Text('Security Check: Verification Required', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Enter your technician wallet passcode PIN to update UPI details:',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          TextField(
                            controller: _pinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              hintText: 'PIN (Demo: 1234)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitPinAndUpdateUpi,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Verify & Confirm UPI Update'),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditingUpi) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Active UPI Payout ID / Number', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(savedUpi, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 12),
                                        SizedBox(width: 4),
                                        Text('Verified', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _upiController.text = savedUpi;
                                  setState(() => _isEditingUpi = true);
                                },
                                icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                                label: const Text('Change UPI ID / Mobile Number'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _upiController,
                              decoration: const InputDecoration(
                                labelText: 'UPI ID or UPI-Linked Mobile Number',
                                hintText: 'e.g. name@upi or 9876543210',
                                prefixIcon: Icon(Icons.payment_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _isEditingUpi = false),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _handleSaveUpi,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Save & Verify'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.m),

            // ─── 4. SETTLED PAYOUT TRANSACTION LOGS ─────────────────────────
            const Text('Settled UPI Payout Logs', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashState.payoutHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = dashState.payoutHistory[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF15803D), size: 18),
                    ),
                    title: Text('Txn Ref: ${item.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Released: ${item.date} • ${item.status}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: Text(
                      '₹${item.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: SemanticColors.success, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
