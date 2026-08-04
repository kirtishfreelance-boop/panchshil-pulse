import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../events/event_details_screen.dart';
import '../events/event_list_screen.dart';
import '../events/event_ticket_screen.dart';
import '../events/widgets/event_card.dart';
import 'scan_qr_screen.dart';

/// The Pulse tab: the brand's editorial rail (Play, Pursuit, Panache) plus the
/// user's own passes.
class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  static const _strands = <_Strand>[
    _Strand('Pulse Play', 'Sport, fitness and everything that gets you moving.',
        'assets/pulse/pulse_play.png', AppColors.primary),
    _Strand('Pulse Pursuit', 'Learning, craft and the things worth getting good at.',
        'assets/pulse/pulse_pursuit.png', AppColors.accent),
    _Strand('Pulse Panache', 'Culture, food and evenings worth dressing up for.',
        'assets/pulse/pulse_panache.png', Color(0xFF7C3AED)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final events = context.read<EventProvider>();
      events.loadMine();
      if (!events.upcoming.hasData) events.loadUpcoming();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = context.watch<EventProvider>();
    final tickets = (events.mine.data ?? const <Event>[])
        .where((e) => !e.isPast && e.isRegistered)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          theme.brightness == Brightness.dark
              ? 'assets/pulse_logo_dark.png'
              : 'assets/pulse_logo.png',
          height: 26,
          errorBuilder: (_, __, ___) => const Text('Pulse'),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan a pass',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScanQrScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            events.loadMine(),
            events.loadUpcoming(refresh: true),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Three strands, one calendar', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Everything Panchshil programmes across its parks, grouped by mood.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            ..._strands.map((s) => _StrandCard(strand: s)),

            const SizedBox(height: 24),
            SectionHeader(
              title: 'Your upcoming passes',
              actionLabel: 'All events',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventListScreen()),
              ),
            ),
            if (events.mine.isLoading && !events.mine.hasData)
              const CardListSkeleton(count: 2, height: 84)
            else if (tickets.isEmpty)
              const EmptyState(
                title: 'No upcoming passes',
                message: 'Register for an event and your pass lands here.',
                icon: Icons.confirmation_number_outlined,
              )
            else
              ...tickets.map((e) => _TicketRow(event: e)),

            const SizedBox(height: 24),
            SectionHeader(
              title: 'Happening soon',
              actionLabel: 'See all',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventListScreen()),
              ),
            ),
            ...(events.upcoming.data ?? const <Event>[]).take(3).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: EventCard(
                      event: e,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventDetailsScreen(eventId: e.id),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Strand {
  const _Strand(this.title, this.blurb, this.asset, this.tint);

  final String title;
  final String blurb;
  final String asset;
  final Color tint;
}

class _StrandCard extends StatelessWidget {
  const _StrandCard({required this.strand});

  final _Strand strand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: strand.tint.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strand.tint.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                strand.asset,
                height: 30,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.auto_awesome_rounded, color: strand.tint, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strand.title,
                    style: theme.textTheme.titleMedium?.copyWith(color: strand.tint),
                  ),
                  const SizedBox(height: 3),
                  Text(strand.blurb, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventTicketScreen(event: event)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.qr_code_rounded,
                    size: 21, color: AppColors.success),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${eventWhen(event.startsAt, null)} · ${countdown(event.startsAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
