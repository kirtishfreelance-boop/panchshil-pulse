import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import 'event_registration_screen.dart';
import 'event_ticket_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.eventId});

  final int eventId;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Event? _event;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await context.read<EventProvider>().fetchEvent(widget.eventId);
      if (mounted) setState(() => _event = event);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToDeviceCalendar(Event event) async {
    await cal.Add2Calendar.addEvent2Cal(cal.Event(
      title: event.title,
      description: event.description ?? '',
      location: event.venue ?? '',
      startDate: event.startsAt,
      endDate: event.endsAt ?? event.startsAt.add(const Duration(hours: 2)),
    ));
  }

  Future<void> _toggleSaved(Event event) async {
    try {
      await context.read<EventProvider>().toggleCalendar(event);
      await _load();
      if (mounted) {
        showPulseSnack(
          context,
          event.inCalendar ? 'Removed from your calendar.' : 'Saved to your calendar.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading && _event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: CardListSkeleton(count: 2, height: 220),
        ),
      );
    }
    if (_event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Event not found.', onRetry: _load),
      );
    }

    final event = _event!;
    final tint = AppColors.tintFor(event.categoryName ?? event.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: const _CircleBack(),
            actions: [
              _CircleAction(
                icon: event.inCalendar
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: () => _toggleSaved(event),
              ),
              _CircleAction(
                icon: Icons.ios_share_rounded,
                onTap: () => Share.share(
                  '${event.title}\n${eventWhen(event.startsAt, event.endsAt)}'
                  '${event.venue != null ? '\n${event.venue}' : ''}'
                  '\n\nShared from Panchshil Pulse',
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PulseImage(url: event.coverImage, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent, Colors.black38],
                        stops: [0, 0.45, 1],
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
                  Row(
                    children: [
                      if (event.categoryName != null)
                        PulseChip(label: event.categoryName!, color: tint),
                      const SizedBox(width: 8),
                      if (event.isPast)
                        const PulseChip(label: 'Ended', color: AppColors.lightTextSecondary)
                      else
                        PulseChip(
                          label: countdown(event.startsAt),
                          color: AppColors.accent,
                          icon: Icons.schedule_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(event.title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    title: weekdayLong(event.startsAt),
                    subtitle: eventWhen(event.startsAt, event.endsAt),
                  ),
                  if (event.venue != null)
                    _InfoRow(
                      icon: Icons.place_rounded,
                      title: 'Venue',
                      subtitle: event.venue!,
                    ),
                  _InfoRow(
                    icon: Icons.confirmation_number_outlined,
                    title: event.isPaid ? money(event.amount) : 'Free entry',
                    subtitle: event.isPaid
                        ? 'Per person, charged to your Pulse wallet'
                        : 'Open to everyone at your office park',
                  ),
                  if (event.capacity > 0)
                    _InfoRow(
                      icon: Icons.groups_rounded,
                      title: '${event.seatsTaken} of ${event.capacity} seats taken',
                      subtitle: event.isSoldOut
                          ? 'This event is full'
                          : '${event.seatsLeft} still available',
                    ),
                  if (event.description != null) ...[
                    const SizedBox(height: 24),
                    Text('About this event', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ReadMoreText(
                      event.description!,
                      trimLines: 4,
                      trimMode: TrimMode.Line,
                      trimCollapsedText: '  Read more',
                      trimExpandedText: '  Show less',
                      style: theme.textTheme.bodyMedium,
                      moreStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      lessStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _addToDeviceCalendar(event),
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: const Text('Add to device calendar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(event: event, onChanged: _load),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.event, required this.onChanged});

  final Event event;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
                  event.isPaid ? 'Ticket price' : 'Entry',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  event.isPaid ? money(event.amount) : 'Free',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(child: _action(context)),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    if (event.isRegistered) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventTicketScreen(event: event)),
        ),
        icon: const Icon(Icons.qr_code_rounded, size: 19),
        label: const Text('View ticket'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
      );
    }
    if (event.isPast) {
      return const FilledButton(onPressed: null, child: Text('Event ended'));
    }
    if (event.isSoldOut) {
      return const FilledButton(onPressed: null, child: Text('Sold out'));
    }
    return FilledButton(
      onPressed: () async {
        final done = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => EventRegistrationScreen(event: event)),
        );
        if (done == true) await onChanged();
      },
      child: const Text('Register'),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) => _CircleAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(7),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              height: 38,
              width: 38,
              child: Icon(icon, size: 19, color: Colors.white),
            ),
          ),
        ),
      );
}
