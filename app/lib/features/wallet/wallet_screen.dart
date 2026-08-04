import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WalletProvider>().load(),
    );
  }

  Future<void> _topUp() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TopUpSheet(),
    );
    if (amount == null || !mounted) return;

    final wallet = context.read<WalletProvider>();
    try {
      final session = await wallet.initiateTopUp(amount);
      // A production build hands off to the Easebuzz SDK here; the dev gateway
      // settles immediately and returns the new balance.
      await wallet.confirmTopUp(
        txnId: session['txn_id'] as String,
        amount: amount,
      );
      if (!mounted) return;
      context.read<AuthProvider>().applyWalletDelta(amount);
      showPulseSnack(context, '${money(amount)} added to your wallet.');
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WalletProvider>();
    final state = provider.summary;
    final summary = state.data ?? const WalletSummary();

    return Scaffold(
      appBar: AppBar(title: const Text('My wallet')),
      body: RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _BalanceCard(
              balance: summary.balance,
              points: summary.loyaltyPoints,
              onTopUp: _topUp,
            ),
            const SizedBox(height: 28),
            Text('Recent activity', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (state.isLoading && !state.hasData)
              const CardListSkeleton(count: 4, height: 66)
            else if (state.hasError && !state.hasData)
              ErrorView(
                message: state.error!,
                onRetry: () => provider.load(refresh: true),
              )
            else if (summary.transactions.isEmpty)
              const EmptyState(
                title: 'No transactions yet',
                message: 'Top-ups, bookings and event payments show up here.',
                icon: Icons.receipt_long_outlined,
              )
            else
              ...summary.transactions.map((t) => _TxnTile(txn: t)),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.points,
    required this.onTopUp,
  });

  final double balance;
  final int points;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available balance',
              style: TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              money(balance, paise: true),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  '$points privilege points',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTopUp,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add money'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      );
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});

  final WalletTransaction txn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = txn.isCredit ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                txn.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.note ?? (txn.isCredit ? 'Credit' : 'Debit'),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (txn.reference != null) txn.reference!,
                      relativeTime(txn.createdAt),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${txn.isCredit ? '+' : '−'}${money(txn.amount.abs())}',
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _controller = TextEditingController();
  static const _presets = [500.0, 1000.0, 2000.0, 5000.0];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _amount {
    final value = double.tryParse(_controller.text.trim());
    return (value != null && value > 0) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add money', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Top up your Pulse wallet for events, bookings and the food court.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Padding(
                padding: EdgeInsets.fromLTRB(18, 15, 8, 15),
                child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: _presets
                .map((p) => ActionChip(
                      label: Text(money(p)),
                      onPressed: () => setState(
                        () => _controller.text = p.toStringAsFixed(0),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed:
                _amount == null ? null : () => Navigator.of(context).pop(_amount),
            child: Text(_amount == null ? 'Enter an amount' : 'Add ${money(_amount!)}'),
          ),
        ],
      ),
    );
  }
}
