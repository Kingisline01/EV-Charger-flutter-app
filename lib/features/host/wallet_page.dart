import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/wallet_repo.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final WalletRepo _walletRepo = WalletRepo();
  final AuthRepo _authRepo = AuthRepo();

  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _loading = true);
    final userId = _authRepo.currentUserId() ?? '';
    final bal = await _walletRepo.getBalance(userId);
    final txs = await _walletRepo.getTransactions(userId);
    if (mounted) {
      setState(() {
        _balance = bal;
        _transactions = txs;
        _loading = false;
      });
    }
  }

  Future<void> _showPayoutDialog() async {
    final amountCtrl = TextEditingController(text: _balance >= 200 ? '200' : '');
    final upiCtrl = TextEditingController(text: 'host@okaxis');

    final requested = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Request Instant UPI Payout'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Balance: ${Formatters.currency(_balance)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (Min ₹200)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI ID or VPA',
                hintText: 'name@oksbi / name@upi',
                prefixIcon: Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Direct transfer to your verified bank UPI VPA without platform delay.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt < 200) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Minimum payout is ₹200')),
                  );
                }
                return;
              }
              if (amt > _balance) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Amount exceeds available wallet balance')),
                  );
                }
                return;
              }
              try {
                await _walletRepo.requestPayout(amount: amt, upiId: upiCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(Formatters.friendlyError(e))),
                  );
                }
              }
            },
            child: const Text('Confirm Transfer'),
          ),
        ],
      ),
    );

    if (requested == true) {
      _loadWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payout initiated! Settling via UPI.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet Balance Hero Card (Stitch Screen 4)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF006948), Color(0xFF00855D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
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
                      'HOST EARNINGS WALLET',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('UPI AUTO-SETTLED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  Formatters.currency(_balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Available for instant withdrawal to bank UPI',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _balance >= 200 ? _showPayoutDialog : null,
                  child: const Text('Request Instant UPI Payout (Min ₹200)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Monthly Metrics Grid (Stitch Screen 4)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('This Month Gross', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(Formatters.currency(_balance * 2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      const Text('28 sessions completed', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Escrow', style: TextStyle(fontSize: 11, color: AppTheme.secondary)),
                      SizedBox(height: 4),
                      Text('₹378.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 2),
                      Text('Releases in 14h', style: TextStyle(fontSize: 10, color: AppTheme.secondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payout account indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance, color: AppTheme.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Default Payout: host@okaxis (Verified)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                Text('Change', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Transaction History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (_transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text('No transactions yet'),
                  ],
                ),
              ),
            )
          else
            ..._transactions.map((tx) {
              final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
              final isPositive = amount > 0;
              final kind = tx['kind'] ?? 'adjustment';
              final note = tx['note'] ?? '';
              final createdAtStr = tx['created_at'];
              final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPositive ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    kind == 'earning' ? 'Booking Earning' : 'Payout Transfer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '$note\n${Formatters.dateTime(createdAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '${isPositive ? '+' : ''}${Formatters.currency(amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isPositive ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
