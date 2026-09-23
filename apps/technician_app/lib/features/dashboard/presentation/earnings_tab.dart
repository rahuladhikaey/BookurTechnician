import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/semantic_colors.dart';
import 'dashboard_provider.dart';
import '../../analytics/presentation/technician_analytics_screen.dart';
import '../../analytics/presentation/technician_analytics_provider.dart';
import '../../analytics/domain/technician_analytics_models.dart';

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
    if (_pinController.text.trim().length >= 4) {
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
          content: Text('Please enter a valid 4-digit Security PIN.'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Instant Payout Transfer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE047)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFB45309), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payout Destination (UPI)', style: TextStyle(fontSize: 11, color: Color(0xFF78350F), fontWeight: FontWeight.w600)),
                              Text(currentUpi, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓ Instant 24x7', style: TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Enter Withdrawal Amount (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      hintText: '0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFDB813), width: 2)),
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
                          label: Text('₹$preset', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                            label: const Text('Full Balance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A))),
                            backgroundColor: const Color(0xFFFDB813),
                            side: const BorderSide(color: Color(0xFFFDB813)),
                            onPressed: () {
                              setModalState(() {
                                _amountController.text = availableBalance.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                      ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                        if (amt <= 0 || amt > availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount within your wallet balance.')),
                          );
                          return;
                        }

                        final success = await ref.read(dashboardProvider.notifier).withdrawToUpi(
                              amount: amt,
                              upiId: currentUpi,
                            );

                        if (success) {
                          if (!context.mounted) return;
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
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFFFDB813), size: 20),
                          SizedBox(width: 8),
                          Text('TRANSFER TO BANK NOW', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ],
                      ),
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB813),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'WALLET',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Earnings & Payouts',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. RAPIDO CAPTAIN WALLET BALANCE CARD ───────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL WITHDRAWABLE BALANCE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB813).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDB813).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xFFFDB813), size: 14),
                            SizedBox(width: 3),
                            Text(
                              'Instant 24x7',
                              style: TextStyle(color: Color(0xFFFDB813), fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${netEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3 KPI Sub-metrics
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Today Net', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('₹${(netEarnings * 0.4).toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 13, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white24),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cash in Hand', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('₹0', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white24),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fee Tier', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('10% Flat', style: TextStyle(color: Color(0xFFFDE047), fontSize: 13, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Withdraw CTA
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: netEarnings > 0
                          ? () {
                              HapticFeedback.mediumImpact();
                              _openWithdrawModal(context, netEarnings, savedUpi);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB813),
                        foregroundColor: const Color(0xFF0F172A),
                        disabledBackgroundColor: Colors.white24,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'WITHDRAW TO BANK NOW',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── 2. TIER BADGE & ANALYTICS BANNER ────────────────────────────
            _buildTierAnalyticsBanner(context),

            const SizedBox(height: 16),

            // ─── 3. REGISTERED UPI & PAYOUT SETTINGS ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registered Payout UPI ID',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF16A34A)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isVerifyingPin) ...[
                    const Text('Enter your 4-digit Security PIN to confirm:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: '4-Digit PIN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isVerifyingPin = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitPinAndUpdateUpi,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                            child: const Text('Confirm PIN'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!_isEditingUpi) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payment_rounded, color: Color(0xFF0F172A), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              savedUpi,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _upiController.text = savedUpi;
                              setState(() => _isEditingUpi = true);
                            },
                            child: const Text(
                              'Edit',
                              style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        labelText: 'New UPI ID / Mobile Number',
                        hintText: 'e.g. name@upi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isEditingUpi = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleSaveUpi,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                            child: const Text('Save UPI'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── 4. SETTLED TRANSACTIONS ─────────────────────────────────────
            const Text(
              'Settled Payout Transactions',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: dashState.payoutHistory.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Color(0xFFCBD5E1), size: 36),
                            SizedBox(height: 8),
                            Text(
                              'No Payouts Recorded Yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF334155)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Transferred amounts to your UPI ID will show in this log with settlement receipts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
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
                          subtitle: Text('Released: ${item.date} • ${item.status}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          trailing: Text(
                            '₹${item.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D), fontSize: 14),
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

  Widget _buildTierAnalyticsBanner(BuildContext context) {
    final analyticsState = ref.watch(technicianAnalyticsProvider);
    final tierInfo = analyticsState.tierInfo;
    final currentTier = tierInfo?.tier ?? TechnicianTier.copper;

    List<Color> gradientColors;
    Color accentColor;
    String badgeEmoji;
    String badgeName;

    switch (currentTier) {
      case TechnicianTier.gold:
        gradientColors = const [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)];
        accentColor = const Color(0xFFFDE68A);
        badgeEmoji = '🥇';
        badgeName = 'Gold VIP Elite';
        break;
      case TechnicianTier.silver:
        gradientColors = const [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B)];
        accentColor = const Color(0xFFE2E8F0);
        badgeEmoji = '🥈';
        badgeName = 'Silver Pro Partner';
        break;
      case TechnicianTier.copper:
        gradientColors = const [Color(0xFF5C2C16), Color(0xFF804A26), Color(0xFFB87333)];
        accentColor = const Color(0xFFFFEDD5);
        badgeEmoji = '🥉';
        badgeName = 'Copper Starter Pass';
        break;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Tier Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(badgeEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badgeName.toUpperCase(),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Platform Fee: ${tierInfo?.discountCommissionPercent.toStringAsFixed(0) ?? "10"}% • Priority Radar Active',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(tierInfo?.todayHours ?? 0.0).toStringAsFixed(1)}h Worked',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Action tile to open full analytics
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFFB45309), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Income & Working Hours Graph',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Track today, yesterday, weekly income & hours worked',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TechnicianAnalyticsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: const Color(0xFFFDB813),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('View Graph', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
