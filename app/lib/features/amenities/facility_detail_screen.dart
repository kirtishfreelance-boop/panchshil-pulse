import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/amenity.dart';
import '../../providers/amenity_provider.dart';
import '../../providers/auth_provider.dart';
import '../wallet/wallet_screen.dart';
import 'my_bookings_screen.dart';

/// Pick a day, pick a slot, confirm. Slots come from the server so two people
/// cannot see the same one as free.
class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({super.key, required this.facility});

  final Facility facility;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  late DateTime _day = DateTime.now();
  List<FacilitySlot>? _slots;
  String? _error;
  FacilitySlot? _selected;
  bool _booking = false;

  static const _daysAhead = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _error = null;
      _selected = null;
    });
    try {
      final slots = await context.read<AmenityProvider>().slotsFor(
            widget.facility.id,
            _day,
          );
      if (mounted) setState(() => _slots = slots);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _confirm() async {
    final slot = _selected;
    if (slot == null) return;

    setState(() => _booking = true);
    try {
      final paid = await context.read<AmenityProvider>().book(slot, widget.facility.id);
      if (!mounted) return;

      if (paid > 0) context.read<AuthProvider>().applyWalletDelta(-paid);

      showPulseSnack(
        context,
        paid > 0
            ? 'Booked. ${money(paid)} charged to your wallet.'
            : 'Booked for ${slot.label} on ${dayMonth(_day)}.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isPaymentRequired) {
        _offerTopUp(e.message);
      } else {
        showPulseSnack(context, e.message, isError: true);
        // The slot was probably taken while the sheet was open.
        await _loadSlots();
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _offerTopUp(String message) {
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
            Text('Not enough balance',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall),
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
    final f = widget.facility;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PulseImage(url: f.coverImage, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  if (f.location != null)
                    _Meta(icon: Icons.place_rounded, text: f.location!),
                  _Meta(
                    icon: Icons.schedule_rounded,
                    text: 'Open ${f.opensLabel} – ${f.closesLabel}, '
                        '${f.slotMinutes}-minute slots',
                  ),
                  if (f.capacity > 0)
                    _Meta(icon: Icons.groups_rounded, text: 'Seats ${f.capacity}'),
                  _Meta(
                    icon: Icons.payments_outlined,
                    text: f.isFree
                        ? 'Free to book'
                        : '${money(f.pricePerSlot)} per slot, charged to your wallet',
                  ),
                  if (f.description != null) ...[
                    const SizedBox(height: 18),
                    Text(f.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                  ],

                  const SizedBox(height: 26),
                  Text('Pick a day', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _daysAhead,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final date = DateTime.now().add(Duration(days: i));
                        final selected = date.day == _day.day &&
                            date.month == _day.month &&
                            date.year == _day.year;
                        return _DayChip(
                          date: date,
                          selected: selected,
                          onTap: () {
                            setState(() => _day = date);
                            _loadSlots();
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Available slots', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildSlots(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected == null
          ? null
          : Container(
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
                        Text(
                          '${dayMonth(_day)}, ${_selected!.label}',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          f.isFree ? 'Free' : money(f.pricePerSlot),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: FilledButton(
                        onPressed: _booking ? null : _confirm,
                        child: _booking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Confirm booking'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSlots() {
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadSlots);
    }
    if (_slots == null) {
      return const CardListSkeleton(count: 2, height: 46);
    }
    if (_slots!.isEmpty) {
      return const EmptyState(
        title: 'No slots that day',
        message: 'Try another date.',
        icon: Icons.event_busy_outlined,
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _slots!.map((slot) {
        final isSelected = _selected?.startsAt == slot.startsAt;
        return _SlotChip(
          slot: slot,
          selected: isSelected,
          onTap: slot.available
              ? () => setState(() => _selected = isSelected ? null : slot)
              : null,
        );
      }).toList(),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.selected, required this.onTap});

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 62,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : theme.colorScheme.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdays[date.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.selected, this.onTap});

  final FacilitySlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;

    final background = selected
        ? AppColors.primary
        : disabled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface;

    final foreground = selected
        ? Colors.white
        : disabled
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : theme.colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
                decoration: slot.mine ? null : (disabled ? TextDecoration.lineThrough : null),
              ),
            ),
            if (slot.mine) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            ],
          ],
        ),
      ),
    );
  }
}
