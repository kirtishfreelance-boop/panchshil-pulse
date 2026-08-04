import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import 'event_details_screen.dart';
import 'widgets/event_card.dart';

/// Month grid with event dots, plus the selected day's agenda underneath.
class EventCalendarScreen extends StatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  State<EventCalendarScreen> createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _fetch() {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0);
    context.read<EventProvider>().loadCalendar(from: start, to: end);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendar = context.watch<EventProvider>().calendar;
    final dayEvents = calendar[_selected] ?? const <Event>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Event calendar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(monthYear(_month), style: theme.textTheme.titleLarge),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shiftMonth(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _WeekdayHeader(),
          const SizedBox(height: 6),
          _MonthGrid(
            month: _month,
            selected: _selected,
            calendar: calendar,
            onSelect: (day) => setState(() => _selected = day),
          ),
          const SizedBox(height: 24),
          Text(weekdayLong(_selected), style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (dayEvents.isEmpty)
            const EmptyState(
              title: 'Nothing on this day',
              message: 'Pick another date with a dot under it.',
              icon: Icons.event_available_outlined,
            )
          else
            ...dayEvents.map(
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
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) => Row(
        children: _labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ))
            .toList(),
      );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.calendar,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<Event>> calendar;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1=Mon..7=Sun, which matches the Monday-first header.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final index = row * 7 + col;
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 46));
            }

            final day = DateTime(month.year, month.month, dayNumber);
            final hasEvents = (calendar[day]?.isNotEmpty) ?? false;
            final isSelected = day == selected;
            final isToday = day == todayKey;

            return Expanded(
              child: InkWell(
                onTap: () => onSelect(day),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 46,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 30,
                        width: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.primary, width: 1.4)
                              : null,
                        ),
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 5,
                        width: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasEvents ? AppColors.accent : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
