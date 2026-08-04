import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';

/// The scannable pass shown at the venue gate.
class EventTicketScreen extends StatelessWidget {
  const EventTicketScreen({
    super.key,
    required this.event,
    this.ticketCodeOverride,
    this.justRegistered = false,
  });

  final Event event;

  /// Set right after registering, before the event is re-fetched.
  final String? ticketCodeOverride;
  final bool justRegistered;

  String get _code => ticketCodeOverride ?? event.registration?.ticketCode ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guests = event.registration?.guests ?? 0;
    final attended = event.registration?.attended ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your ticket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(
              'My pass for ${event.title}\n'
              '${eventWhen(event.startsAt, event.endsAt)}\n'
              'Ticket: $_code',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (justRegistered) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are registered. Show this pass at the gate.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          _TicketBody(
            event: event,
            code: _code,
            guests: guests,
            attended: attended,
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _code));
              showPulseSnack(context, 'Ticket code copied.');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy ticket code'),
          ),
          const SizedBox(height: 20),
          Text(
            'Keep the screen bright when you reach the gate. One scan per pass — '
            'guests enter with you.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.event,
    required this.code,
    required this.guests,
    required this.attended,
  });

  final Event event;
  final String code;
  final int guests;
  final bool attended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PANCHSHIL PULSE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: _Detail(
                    label: 'When',
                    value: eventWhen(event.startsAt, event.endsAt),
                  ),
                ),
                Expanded(
                  child: _Detail(
                    label: 'Admits',
                    value: '${1 + guests} ${guests == 0 ? 'person' : 'people'}',
                  ),
                ),
              ],
            ),
          ),
          if (event.venue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: _Detail(label: 'Venue', value: event.venue!),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: _PerforatedDivider(),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  code,
                  style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                if (attended)
                  const PulseChip(
                    label: 'Checked in',
                    color: AppColors.success,
                    icon: Icons.verified_rounded,
                  )
                else if (event.isPast)
                  const PulseChip(label: 'Event ended', color: AppColors.danger)
                else
                  const PulseChip(
                    label: 'Valid — not yet scanned',
                    color: AppColors.primary,
                    icon: Icons.schedule_rounded,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// The dashed tear-line between ticket details and the QR block.
class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        const gap = 5.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1.4, color: color),
          ),
        );
      },
    );
  }
}
