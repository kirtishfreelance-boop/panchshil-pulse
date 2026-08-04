import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/site.dart';
import 'async_value.dart';

class SiteProvider extends ChangeNotifier {
  SiteProvider(this._api);

  final ApiClient _api;

  AsyncValue<List<Site>> _sites = const AsyncValue.idle();
  List<ServiceCategory> _services = const [];
  int? _currentSiteId;

  AsyncValue<List<Site>> get sites => _sites;
  List<ServiceCategory> get services => _services;
  int? get currentSiteId => _currentSiteId;

  Site? get currentSite {
    final list = _sites.data;
    if (list == null || _currentSiteId == null) return null;
    for (final s in list) {
      if (s.id == _currentSiteId) return s;
    }
    return null;
  }

  /// The office-park picker runs before sign-in, so it uses the open endpoint.
  Future<void> loadPublicSites() async {
    _sites = const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.publicSites);
      _sites = AsyncValue.data(listFrom(json, 'sites', Site.fromJson));
    } on ApiException catch (e) {
      _sites = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadAllowedSites() async {
    _sites = _sites.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(Api.allowedSites);
      _currentSiteId = (json['current_site_id'] as num?)?.toInt();
      _sites = AsyncValue.data(listFrom(json, 'sites', Site.fromJson));
    } on ApiException catch (e) {
      _sites = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadServices() async {
    try {
      final json = await _api.get(Api.serviceCategories);
      _services = listFrom(json, 'service_categories', ServiceCategory.fromJson);
      notifyListeners();
    } on ApiException {
      _services = const [];
    }
  }

  void setCurrentSite(int? id) {
    _currentSiteId = id;
    notifyListeners();
  }
}
