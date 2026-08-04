import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../wallet/wallet_screen.dart';
import 'event_ticket_screen.dart';

/// Guest count, payment method and confirmation for a single event.
class EventRegistrationScreen extends StatefulWidget {
  const EventRegistrationScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  int _guests = 0;
  String _method = 'wallet';
  bool _submitting = false;

  int get _maxGuests {
    final left = widget.event.seatsLeft;
    if (left == null) return 5;
    return (left - 1).clamp(0, 5);
  }

  double get _payable =>
      widget.event.isPaid ? widget.event.amount * (1 + _guests) : 0;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      final ticket = await context.read<EventProvider>().register(
            widget.event.id,
            guests: _guests,
            paymentMethod: _method,
          );

      if (!mounted) return;
      if (_method == 'wallet' && _payable > 0) {
        context.read<AuthProvider>().applyWalletDelta(-_payable);
      }

      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => EventTicketScreen(
          event: widget.event,
          ticketCodeOverride: ticket,
          justRegistered: true,
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isPaymentRequired) {
        _showTopUpSheet(e.message);
      } else {
        showPulseSnack(context, e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showTopUpSheet(String message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 42, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Not enough balance',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
              child: const Text('Top up wallet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;
    final balance = context.watch<AuthProvider>().user?.walletBalance ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm registration')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                PulseImage(
                  url: event.coverImage,
                  height: 62,
                  width: 62,
                  radius: 10,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        eventWhen(event.startsAt, event.endsAt),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Bringing guests?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            _maxGuests == 0
                ? 'No guest passes are available for this event.'
                : 'Up to $_maxGuests guests, charged at the same rate.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Guests', style: theme.textTheme.titleSmall),
                ),
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: _guests > 0 ? () => setState(() => _guests--) : null,
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$_guests',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: _guests < _maxGuests ? () => setState(() => _guests++) : null,
                ),
              ],
            ),
          ),

          if (event.isPaid) ...[
            const SizedBox(height: 28),
            Text('Payment method', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _MethodTile(
              title: 'Pulse wallet',
              subtitle: 'Balance ${money(balance)}',
              icon: Icons.account_balance_wallet_rounded,
              selected: _method == 'wallet',
              warning: balance < _payable ? 'Not enough balance' : null,
              onTap: () => setState(() => _method = 'wallet'),
            ),
            const SizedBox(height: 10),
            _MethodTile(
              title: 'UPI / Card / Netbanking',
              subtitle: 'Pay securely through the gateway',
              icon: Icons.credit_card_rounded,
              selected: _method == 'gateway',
              onTap: () => setState(() => _method = 'gateway'),
            ),
            const SizedBox(height: 28),
            _Summary(
              amount: event.amount,
              people: 1 + _guests,
              total: _payable,
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total payable', style: theme.textTheme.labelSmall),
                  Text(
                    _payable == 0 ? 'Free' : money(_payable),
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _confirm,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(_payable == 0 ? 'Confirm' : 'Pay & confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.warning,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : theme.colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    warning ?? subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: warning != null ? AppColors.danger : null,
                      fontWeight: warning != null ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 21,
              color: selected ? AppColors.primary : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.amount, required this.people, required this.total});

  final double amount;
  final int people;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(context, '${money(amount)} × $people', money(amount * people)),
          const SizedBox(height: 10),
          _row(context, 'Convenience fee', 'Waived'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(child: Text('Total', style: theme.textTheme.titleMedium)),
              Text(money(total), style: theme.textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
