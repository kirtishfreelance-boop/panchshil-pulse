import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything that survives an app restart: the auth token, the cached user,
/// the active site, and the theme preference.
class SessionStore {
  SessionStore(this._prefs);

  static const _kToken = 'pulse.token';
  static const _kUser = 'pulse.user';
  static const _kSiteId = 'pulse.site_id';
  static const _kThemeMode = 'pulse.theme_mode';
  static const _kSeenOnboarding = 'pulse.seen_onboarding';
  static const _kApiBaseUrl = 'pulse.api_base_url';

  final SharedPreferences _prefs;

  static Future<SessionStore> create() async =>
      SessionStore(await SharedPreferences.getInstance());

  String? get token => _prefs.getString(_kToken);
  Future<void> setToken(String? value) async {
    if (value == null) {
      await _prefs.remove(_kToken);
    } else {
      await _prefs.setString(_kToken, value);
    }
  }

  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(Map<String, dynamic>? value) async {
    if (value == null) {
      await _prefs.remove(_kUser);
    } else {
      await _prefs.setString(_kUser, jsonEncode(value));
    }
  }

  int? get siteId => _prefs.getInt(_kSiteId);
  Future<void> setSiteId(int? value) async {
    if (value == null) {
      await _prefs.remove(_kSiteId);
    } else {
      await _prefs.setInt(_kSiteId, value);
    }
  }

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  bool get seenOnboarding => _prefs.getBool(_kSeenOnboarding) ?? false;
  Future<void> setSeenOnboarding(bool value) => _prefs.setBool(_kSeenOnboarding, value);

  /// Overrides the compile-time API base URL. Lets one build be pointed at a
  /// laptop on the LAN, a staging host, or production without reinstalling.
  String? get apiBaseUrl => _prefs.getString(_kApiBaseUrl);
  Future<void> setApiBaseUrl(String? value) async {
    final trimmed = value?.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs.remove(_kApiBaseUrl);
    } else {
      await _prefs.setString(_kApiBaseUrl, trimmed);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kSiteId);
  }
}
