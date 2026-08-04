import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../providers/async_value.dart';
import '../../providers/event_provider.dart';
import 'event_calendar_screen.dart';
import 'event_details_screen.dart';
import 'widgets/event_card.dart';

/// Events home: Upcoming / Past / My events, with category filters.
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final events = context.read<EventProvider>();
      events
        ..loadUpcoming()
        ..loadCategories();
    });

    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final events = context.read<EventProvider>();
      if (_tabs.index == 1 && !events.past.hasData) events.loadPast();
      if (_tabs.index == 2 && !events.mine.hasData) events.loadMine();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventCalendarScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'My events'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _UpcomingTab(events: events),
          _EventList(
            state: events.past,
            emptyTitle: 'No past events',
            emptyMessage: 'Events you have missed or attended will be listed here.',
            onRetry: events.loadPast,
          ),
          _EventList(
            state: events.mine,
            emptyTitle: 'You have not registered yet',
            emptyMessage: 'Register for an event and your ticket shows up here.',
            onRetry: events.loadMine,
          ),
        ],
      ),
    );
  }
}

class _UpcomingTab extends StatelessWidget {
  const _UpcomingTab({required this.events});

  final EventProvider events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (events.categories.isNotEmpty)
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: events.activeCategoryId == null,
                  onTap: () => events.filterByCategory(null),
                ),
                ...events.categories.map(
                  (c) => _FilterChip(
                    label: c.name,
                    selected: events.activeCategoryId == c.id,
                    onTap: () => events.filterByCategory(c.id),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _EventList(
            state: events.upcoming,
            emptyTitle: 'Nothing scheduled',
            emptyMessage: 'New events for your park will appear here.',
            onRetry: () => events.loadUpcoming(refresh: true),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
          onSelected: (_) => onTap(),
        ),
      );
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.state,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
  });

  final AsyncValue<List<Event>> state;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasData) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: CardListSkeleton(count: 3, height: 300),
      );
    }
    if (state.hasError && !state.hasData) {
      return ErrorView(message: state.error!, onRetry: onRetry);
    }

    final list = state.data ?? const <Event>[];
    if (list.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.event_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => EventCard(
          event: list[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: list[i].id),
            ),
          ),
        ),
      ),
    );
  }
}
