import 'package:flutter/material.dart';

import '../core/storage/session_store.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._session) : _mode = _session.themeMode;

  final SessionStore _session;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _session.setThemeMode(mode);
  }

  Future<void> toggle(BuildContext context) =>
      setMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);
}
