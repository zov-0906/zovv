import 'package:shared_preferences/shared_preferences.dart';

import '../domain/watch_progress.dart';

class LocalLibraryStorage implements LibraryStorage {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'drama.library.v1';
  @override
  Future<String?> read() => _preferences.getString(_key);
  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}
