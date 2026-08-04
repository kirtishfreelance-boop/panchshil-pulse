import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/event.dart';
import 'async_value.dart';

class EventProvider extends ChangeNotifier {
  EventProvider(this._api);

  final ApiClient _api;

  AsyncValue<List<Event>> _upcoming = const AsyncValue.idle();
  AsyncValue<List<Event>> _past = const AsyncValue.idle();
  AsyncValue<List<Event>> _mine = const AsyncValue.idle();
  List<EventCategory> _categories = const [];
  Map<DateTime, List<Event>> _calendar = const {};
  int? _activeCategoryId;

  AsyncValue<List<Event>> get upcoming => _upcoming;
  AsyncValue<List<Event>> get past => _past;
  AsyncValue<List<Event>> get mine => _mine;
  List<EventCategory> get categories => _categories;
  Map<DateTime, List<Event>> get calendar => _calendar;
  int? get activeCategoryId => _activeCategoryId;

  Future<void> loadUpcoming({bool refresh = false}) async {
    if (_upcoming.isLoading) return;
    _upcoming = refresh ? _upcoming.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.events);
      _upcoming = AsyncValue.data(listFrom(json, 'events', Event.fromJson));
    } on ApiException catch (e) {
      _upcoming = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadPast() async {
    _past = const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.events, query: {'past': 'true'});
      _past = AsyncValue.data(listFrom(json, 'events', Event.fromJson));
    } on ApiException catch (e) {
      _past = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadMine() async {
    _mine = const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.myEvents);
      _mine = AsyncValue.data(listFrom(json, 'events', Event.fromJson));
    } on ApiException catch (e) {
      _mine = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      final json = await _api.get(Api.eventCategories);
      _categories = listFrom(json, 'categories', EventCategory.fromJson);
      notifyListeners();
    } on ApiException {
      // Filters are a nicety; the unfiltered list still works without them.
    }
  }

  Future<void> filterByCategory(int? categoryId) async {
    _activeCategoryId = categoryId;
    if (categoryId == null) return loadUpcoming(refresh: true);

    _upcoming = _upcoming.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(Api.categoryEvents, query: {'category_id': categoryId});
      _upcoming = AsyncValue.data(listFrom(json, 'events', Event.fromJson));
    } on ApiException catch (e) {
      _upcoming = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadCalendar({DateTime? from, DateTime? to}) async {
    final start = from ?? DateTime.now();
    final end = to ?? start.add(const Duration(days: 90));
    try {
      final json = await _api.get(Api.eventCalendar, query: {
        'from': _ymd(start),
        'to': _ymd(end),
      });
      final raw = json['calendar_data'];
      final parsed = <DateTime, List<Event>>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          final day = DateTime.tryParse(key as String);
          if (day == null || value is! List) return;
          parsed[DateTime(day.year, day.month, day.day)] = value
              .whereType<Map<String, dynamic>>()
              .map(Event.fromJson)
              .toList(growable: false);
        });
      }
      _calendar = parsed;
      notifyListeners();
    } on ApiException {
      _calendar = const {};
      notifyListeners();
    }
  }

  Future<Event> fetchEvent(int id) async {
    final json = await _api.get(Api.event(id));
    return Event.fromJson(json['event'] as Map<String, dynamic>);
  }

  /// Registers the signed-in user and returns the issued ticket code.
  Future<String> register(int eventId, {int guests = 0, String paymentMethod = 'wallet'}) async {
    final json = await _api.post(
      Api.eventRegister(eventId),
      body: {'guests': guests, 'payment_method': paymentMethod},
    );
    _replaceEverywhere(Event.fromJson(json['event'] as Map<String, dynamic>));
    return json['ticket_code'] as String;
  }

  Future<void> cancelRegistration(int eventId) async {
    await _api.delete(Api.eventRegister(eventId));
    await loadUpcoming(refresh: true);
  }

  Future<void> toggleCalendar(Event event) async {
    if (event.inCalendar) {
      await _api.delete(Api.addToCalendar, query: {'event_id': event.id});
    } else {
      await _api.post(Api.addToCalendar, body: {'event_id': event.id});
    }
    await loadUpcoming(refresh: true);
  }

  Future<Map<String, dynamic>> markAttended(String ticketCode) =>
      _api.post(Api.markAttended, body: {'ticket_code': ticketCode});

  void _replaceEverywhere(Event updated) {
    List<Event>? swap(List<Event>? list) => list
        ?.map((e) => e.id == updated.id ? updated : e)
        .toList(growable: false);

    final up = swap(_upcoming.data);
    if (up != null) _upcoming = AsyncValue.data(up);
    final my = swap(_mine.data);
    if (my != null) _mine = AsyncValue.data(my);
    notifyListeners();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
