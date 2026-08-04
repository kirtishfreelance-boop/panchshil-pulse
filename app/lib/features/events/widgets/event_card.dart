import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pulse_widgets.dart';
import '../../../models/event.dart';

/// Full-width event card used on the Events list and Home.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = AppColors.tintFor(event.categoryName ?? event.id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PulseImage(url: event.coverImage, height: 150, width: double.infinity),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _DateBadge(date: event.startsAt),
                ),
                if (event.isRegistered)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Registered',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.categoryName != null)
                        PulseChip(label: event.categoryName!, color: tint),
                      const Spacer(),
                      Text(
                        event.isPast ? 'Ended' : countdown(event.startsAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: event.isPast
                              ? theme.colorScheme.onSurfaceVariant
                              : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.schedule_rounded,
                    text: eventWhen(event.startsAt, event.endsAt),
                  ),
                  if (event.venue != null) ...[
                    const SizedBox(height: 5),
                    _MetaRow(icon: Icons.place_outlined, text: event.venue!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        event.isPaid ? money(event.amount) : 'Free',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: event.isPaid ? theme.colorScheme.onSurface : AppColors.success,
                        ),
                      ),
                      if (event.isPaid)
                        Text(
                          ' per person',
                          style: theme.textTheme.bodySmall,
                        ),
                      const Spacer(),
                      if (event.isSoldOut)
                        const PulseChip(label: 'Sold out', color: AppColors.danger)
                      else if (event.seatsLeft != null && event.seatsLeft! <= 20)
                        PulseChip(
                          label: '${event.seatsLeft} seats left',
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              date.day.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            Text(
              dayMonth(date).split(' ').last.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal card for the Home carousel rail.
class EventMiniCard extends StatelessWidget {
  const EventMiniCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulseImage(url: event.coverImage, height: 104, width: double.infinity),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eventWhen(event.startsAt, null),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        event.isPaid ? money(event.amount) : 'Free',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: event.isPaid
                              ? theme.colorScheme.onSurface
                              : AppColors.success,
                        ),
                      ),
                      const Spacer(),
                      if (event.isRegistered)
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
