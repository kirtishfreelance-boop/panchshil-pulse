import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/amenity.dart';
import '../models/document.dart';
import 'async_value.dart';

/// Amenities, documents and the SOS directory — the three "Discover" modules.
/// They share a provider because each is a small read-mostly surface and the
/// Discover tab loads them together.
class AmenityProvider extends ChangeNotifier {
  AmenityProvider(this._api);

  final ApiClient _api;

  AsyncValue<List<FacilityCategory>> _categories = const AsyncValue.idle();
  AsyncValue<List<Facility>> _facilities = const AsyncValue.idle();
  AsyncValue<List<FacilityBooking>> _bookings = const AsyncValue.idle();
  AsyncValue<List<DocumentFolder>> _folders = const AsyncValue.idle();
  AsyncValue<List<SosContact>> _contacts = const AsyncValue.idle();
  int? _activeCategoryId;

  AsyncValue<List<FacilityCategory>> get categories => _categories;
  AsyncValue<List<Facility>> get facilities => _facilities;
  AsyncValue<List<FacilityBooking>> get bookings => _bookings;
  AsyncValue<List<DocumentFolder>> get folders => _folders;
  AsyncValue<List<SosContact>> get contacts => _contacts;
  int? get activeCategoryId => _activeCategoryId;

  // --- Amenities -----------------------------------------------------------

  Future<void> loadCategories() async {
    _categories = _categories.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(Api.facilityCategories, query: {'fac_type': 'bookable'});
      _categories = AsyncValue.data(
        listFrom(json, 'facility_categories', FacilityCategory.fromJson),
      );
    } on ApiException catch (e) {
      _categories = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadFacilities({int? categoryId}) async {
    _activeCategoryId = categoryId;
    _facilities = _facilities.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(
        Api.availableFacilities,
        query: {
          'fac_type': 'bookable',
          if (categoryId != null) 'category_id': categoryId,
        },
      );
      _facilities = AsyncValue.data(listFrom(json, 'facilities', Facility.fromJson));
    } on ApiException catch (e) {
      _facilities = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<List<FacilitySlot>> slotsFor(int facilityId, DateTime date) async {
    final json = await _api.get(Api.slotsStatus, query: {
      'facility_id': facilityId,
      'date': _ymd(date),
    });
    return listFrom(json, 'slots', FacilitySlot.fromJson);
  }

  /// Returns the amount charged so the caller can adjust the wallet locally.
  Future<double> book(FacilitySlot slot, int facilityId, {String? notes}) async {
    final json = await _api.post(Api.facilityBookings, body: {
      'facility_id': facilityId,
      'starts_at': slot.startsAt.toIso8601String(),
      'ends_at': slot.endsAt.toIso8601String(),
      'notes': notes,
    });
    await loadBookings();
    return (json['amount_paid'] as num?)?.toDouble() ?? 0;
  }

  Future<void> loadBookings({bool past = false}) async {
    _bookings = _bookings.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(
        Api.myBookings,
        query: past ? {'past': 'true'} : null,
      );
      _bookings = AsyncValue.data(listFrom(json, 'bookings', FacilityBooking.fromJson));
    } on ApiException catch (e) {
      _bookings = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  /// Returns the amount refunded to the wallet.
  Future<double> cancelBooking(int bookingId) async {
    final json = await _api.delete(Api.cancelBooking(bookingId));
    await loadBookings();
    return (json['refunded'] as num?)?.toDouble() ?? 0;
  }

  // --- Documents -----------------------------------------------------------

  Future<void> loadFolders() async {
    _folders = _folders.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(Api.documentFolders);
      _folders = AsyncValue.data(listFrom(json, 'folders', DocumentFolder.fromJson));
    } on ApiException catch (e) {
      _folders = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<List<PulseDocument>> documents({int? folderId, String? search}) async {
    final json = await _api.get(Api.documents, query: {
      if (folderId != null) 'folder_id': folderId,
      if (search != null && search.isNotEmpty) 'q': search,
    });
    return listFrom(json, 'documents', PulseDocument.fromJson);
  }

  // --- SOS -----------------------------------------------------------------

  Future<void> loadContacts() async {
    _contacts = _contacts.toLoading();
    notifyListeners();
    try {
      final json = await _api.get(Api.sosContacts);
      _contacts = AsyncValue.data(listFrom(json, 'contacts', SosContact.fromJson));
    } on ApiException catch (e) {
      _contacts = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
