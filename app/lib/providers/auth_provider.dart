import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/session_store.dart';
import '../models/user.dart';

enum AuthStatus { unknown, signedOut, needsRegistration, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, this._session) {
    _api.onUnauthorized = () => signOut(expired: true);
  }

  final ApiClient _api;
  final SessionStore _session;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _pendingMobile;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get pendingMobile => _pendingMobile;
  bool get busy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  /// Restores a cached session on cold start, then refreshes it in the background.
  Future<void> bootstrap() async {
    final token = _session.token;
    final cached = _session.user;

    if (token == null || cached == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _user = AppUser.fromJson(cached);
    _status = AuthStatus.signedIn;
    notifyListeners();

    try {
      final json = await _api.get(Api.account);
      await _adoptUser(json['user'] as Map<String, dynamic>);
    } catch (_) {
      // Offline start: keep the cached user rather than bouncing to login.
    }
  }

  Future<void> _adoptUser(Map<String, dynamic> json) async {
    _user = AppUser.fromJson(json);
    await _session.setUser(json);
    if (_user?.siteId != null) await _session.setSiteId(_user!.siteId);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  /// Returns the dev-mode OTP when the backend echoes it, otherwise null.
  Future<String?> requestOtp(String mobile) async {
    _setBusy(true);
    try {
      final json = await _api.get(Api.generateOtp, query: {'mobile': mobile});
      _pendingMobile = json['mobile'] as String? ?? mobile;
      return json['otp'] as String?;
    } finally {
      _setBusy(false);
    }
  }

  /// True when the OTP belonged to an existing account and we are now signed in.
  Future<bool> verifyOtp(String otp) async {
    _setBusy(true);
    try {
      final json = await _api.get(
        Api.verifyOtp,
        query: {'mobile': _pendingMobile, 'otp': otp},
      );

      if (json['registered'] == true) {
        await _session.setToken(json['token'] as String);
        await _adoptUser(json['user'] as Map<String, dynamic>);
        return true;
      }

      _status = AuthStatus.needsRegistration;
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> register({
    required String firstname,
    String? lastname,
    String? email,
    String? companyName,
    String? designation,
    String? gender,
    required int siteId,
  }) async {
    _setBusy(true);
    try {
      final json = await _api.post(Api.createUser, body: {
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'mobile': _pendingMobile,
        'company_name': companyName,
        'designation': designation,
        'gender': gender,
        'site_id': siteId,
      });
      await _session.setToken(json['token'] as String);
      await _adoptUser(json['user'] as Map<String, dynamic>);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    _setBusy(true);
    try {
      final json = await _api.patch(Api.account, body: changes);
      await _adoptUser(json['user'] as Map<String, dynamic>);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> refreshUser() async {
    try {
      final json = await _api.get(Api.account);
      await _adoptUser(json['user'] as Map<String, dynamic>);
    } catch (_) {
      // A refresh failure should never blank the screen the user is on.
    }
  }

  /// Applies a locally-known balance change without a round trip.
  void applyWalletDelta(double delta) {
    final current = _user;
    if (current == null) return;
    _user = current.copyWith(walletBalance: current.walletBalance + delta);
    notifyListeners();
  }

  Future<void> switchSite(int siteId) async {
    final json = await _api.get(Api.changeSite, query: {'site_id': siteId});
    await _adoptUser(json['user'] as Map<String, dynamic>);
  }

  /// [expired] marks a session the server rejected, so the login screen can
  /// explain why the user landed back there.
  bool sessionExpired = false;

  Future<void> signOut({bool expired = false}) async {
    await _session.clear();
    _user = null;
    _pendingMobile = null;
    sessionExpired = expired;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
