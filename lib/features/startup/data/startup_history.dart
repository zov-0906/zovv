import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StartupHistory {
  Future<bool> hasCompleted();
  Future<void> markCompleted();
}

/// Presentation preference; never represents login or actual permissions.
class LocalStartupHistory implements StartupHistory {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'startup.presentation_completed.v1';
  @override
  Future<bool> hasCompleted() async {
    try {
      return await _preferences.getBool(_key) ?? false;
    } on PlatformException catch (error) {
      debugPrint('Could not read startup preference: ${error.code}');
      return false;
    }
  }

  @override
  Future<void> markCompleted() async {
    try {
      await _preferences.setBool(_key, true);
    } on PlatformException catch (error) {
      debugPrint('Could not save startup preference: ${error.code}');
    }
  }
}
