import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/amenity.dart';
import '../../providers/amenity_provider.dart';
import '../../providers/auth_provider.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AmenityProvider>().loadBookings(),
    );
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      context.read<AmenityProvider>().loadBookings(past: _tabs.index == 1);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cancel(FacilityBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          booking.amountPaid > 0
              ? '${money(booking.amountPaid)} will be returned to your wallet.'
              : 'The slot will be released for others.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final refunded = await context.read<AmenityProvider>().cancelBooking(booking.id);
      if (!mounted) return;
      if (refunded > 0) context.read<AuthProvider>().applyWalletDelta(refunded);
      showPulseSnack(
        context,
        refunded > 0 ? '${money(refunded)} refunded to your wallet.' : 'Booking cancelled.',
      );
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AmenityProvider>();
    final state = provider.bookings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
          ),
        ),
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading && !state.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: CardListSkeleton(count: 3, height: 104),
            );
          }
          if (state.hasError && !state.hasData) {
            return ErrorView(
              message: state.error!,
              onRetry: () => provider.loadBookings(past: _tabs.index == 1),
            );
          }

          final bookings = state.data ?? const <FacilityBooking>[];
          if (bookings.isEmpty) {
            return EmptyState(
              title: _tabs.index == 1 ? 'No past bookings' : 'Nothing booked yet',
              message: _tabs.index == 1
                  ? 'Bookings you have used will be listed here.'
                  : 'Book an amenity and it will appear here.',
              icon: Icons.event_available_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadBookings(past: _tabs.index == 1),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _BookingCard(
                booking: bookings[i],
                onCancel: () => _cancel(bookings[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final FacilityBooking booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseImage(
                url: booking.coverImage,
                height: 56,
                width: 56,
                radius: 12,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.facilityName ?? 'Booking',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (booking.facilityLocation != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        booking.facilityLocation!,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (booking.amountPaid > 0)
                Text(money(booking.amountPaid), style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${weekdayLong(booking.startsAt)} · '
                    '${timeOfDay(booking.startsAt)} – ${timeOfDay(booking.endsAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (booking.isCancellable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.2),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text('Cancel booking'),
              ),
            ),
          ] else if (booking.isPast) ...[
            const SizedBox(height: 10),
            const PulseChip(label: 'Completed', color: AppColors.lightTextSecondary),
          ],
        ],
      ),
    );
  }
}
