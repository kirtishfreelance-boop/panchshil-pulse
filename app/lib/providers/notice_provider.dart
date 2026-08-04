import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/notice.dart';
import 'async_value.dart';

class NoticeProvider extends ChangeNotifier {
  NoticeProvider(this._api);

  final ApiClient _api;

  AsyncValue<List<Notice>> _notices = const AsyncValue.idle();
  List<String> _categories = const [];
  String? _activeCategory;

  AsyncValue<List<Notice>> get notices => _notices;
  List<String> get categories => _categories;
  String? get activeCategory => _activeCategory;

  Future<void> load({String? category, bool refresh = false}) async {
    _activeCategory = category;
    _notices = refresh ? _notices.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(
        Api.notices,
        query: category == null ? null : {'category': category},
      );
      final cats = json['categories'];
      if (cats is List) _categories = cats.whereType<String>().toList(growable: false);
      _notices = AsyncValue.data(listFrom(json, 'noticeboards', Notice.fromJson));
    } on ApiException catch (e) {
      _notices = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<Notice> fetch(int id) async {
    final json = await _api.get(Api.notice(id));
    return Notice.fromJson(json['noticeboard'] as Map<String, dynamic>);
  }
}
