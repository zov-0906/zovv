import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted appearance preference. Storage failures never block the UI.
abstract interface class ThemePreference {
  Future<ThemeMode?> read();
  Future<void> write(ThemeMode mode);
}

class LocalThemePreference implements ThemePreference {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'zovv.theme_mode.v1';

  @override
  Future<ThemeMode?> read() async {
    try {
      final value = await _preferences.getString(_key);
      return switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
    } catch (error) {
      debugPrint('Could not read theme preference: $error');
      return null;
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _preferences.setString(_key, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (error) {
      debugPrint('Could not save theme preference: $error');
    }
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController({this.preference, ThemeMode initial = ThemeMode.system})
    : _mode = initial;
  final ThemePreference? preference;
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final stored = await preference?.read();
    if (stored == null || stored == _mode) return;
    _mode = stored;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final target = preference;
    if (target != null) unawaited(target.write(mode));
  }
}
