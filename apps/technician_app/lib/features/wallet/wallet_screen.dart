import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/dio_client.dart';
import '../../core/security/secure_storage.dart';
import '../../core/theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final DioClient _dioClient = DioClient(SecureStorage());
  bool _isLoading = true;
  double _balance = 0.0;
  double _pendingPayout = 0.0;
  double _codBalance = 0.0;
  String _savedUpiId = '';
  List<Map<String, dynamic>> _transactions = [];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dioClient.dio.get('/technician/wallet', queryParameters: {
        'technicianId': widget.userId,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        final d = res.data['data'];
        setState(() {
          _balance = (d['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _pendingPayout = (d['pendingPayout'] as num?)?.toDouble() ?? 0.0;
          _codBalance = (d['codBalance'] as num?)?.toDouble() ?? 0.0;
          _savedUpiId = d['savedUpiId']?.toString() ?? '';
          _transactions = List<Map<String, dynamic>>.from(d['transactions'] ?? []);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Graceful fallback
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showWithdrawModal() {
    _amountController.text = _balance > 0 ? _balance.toInt().toString() : '500';
    _upiController.text = _savedUpiId.isNotEmpty ? _savedUpiId : 'partner@upi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Instant Withdrawal to Bank / UPI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Available to withdraw: ₹${_balance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFFCF9F6),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _upiController,
                decoration: InputDecoration(
                  labelText: 'Your Bank UPI VPA ID',
                  hintText: 'e.g. 9876543210@upi or name@okhdfcbank',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFFCF9F6),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                    final upi = _upiController.text.trim();

                    if (amt <= 0 || amt > _balance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an amount within your available balance.')),
                      );
                      return;
                    }
                    if (upi.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid UPI VPA ID.')),
                      );
                      return;
                    }

                    Navigator.pop(modalCtx);
                    await _executeWithdrawal(amt, upi);
                  },
                  child: const Text('SUBMIT INSTANT PAYOUT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeWithdrawal(double amount, String upiId) async {
    setState(() => _isLoading = true);
    try {
      final res = await _dioClient.dio.post('/technician/withdraw', data: {
        'amount': amount,
        'upiId': upiId,
        'technicianId': widget.userId,
      });

      if (res.statusCode == 200 && res.data['success'] == true) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('₹${amount.toStringAsFixed(0)} transferred to $upiId! (Ref: ${res.data['data']?['payoutReference'] ?? 'SUCCESS'})'),
              backgroundColor: AppColors.onlineGreen,
            ),
          );
        }
        await _fetchWalletData();
        return;
      } else {
        final err = res.data['error'] ?? 'Withdrawal failed. Please check balance.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString()), backgroundColor: AppColors.offlineRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal request failed: $e'), backgroundColor: AppColors.offlineRed),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings & Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchWalletData,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchWalletData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AVAILABLE BALANCE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _pendingPayout > 0
                                      ? 'Pending: ₹${_pendingPayout.toStringAsFixed(2)} | COD: ₹${_codBalance.toStringAsFixed(2)}'
                                      : 'COD Dues: ₹${_codBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Instant UPI Settlement',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Withdraw Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _balance > 0 ? _showWithdrawModal : null,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, size: 22, color: Color(0xFFF46B12)),
                              SizedBox(width: 8),
                              Text(
                                'INSTANT WITHDRAW TO UPI / BANK',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'REAL-TIME TRANSACTION LEDGER',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No transactions yet in your ledger.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ..._transactions.map((t) => _buildTransactionItem(
                              t['title']?.toString() ?? 'Service Transaction',
                              '${t['isCredit'] == true ? '+' : '-'}₹${(t['amount'] as num?)?.abs().toStringAsFixed(0) ?? '0'}',
                              t['date']?.toString() ?? 'Recent',
                              t['isCredit'] == true,
                            )),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount, String date, bool isCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit ? AppColors.onlineGreenLight : AppColors.offlineRedLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.onlineGreen : AppColors.offlineRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isCredit ? AppColors.onlineGreen : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
