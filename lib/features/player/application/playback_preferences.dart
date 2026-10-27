import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../drama/domain/watch_progress.dart';

class LocalPlaybackStorage implements LibraryStorage {
  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString('player.preferences.v1');
  @override
  Future<void> write(String value) =>
      _preferences.setString('player.preferences.v1', value);
}

/// Playback preferences are independent of media/controller ownership.
class PlaybackPreferences {
  PlaybackPreferences({LibraryStorage? storage})
    : storage = storage ?? LocalPlaybackStorage();
  final LibraryStorage storage;
  static const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  double speed = 1;
  bool autoNext = true;
  String quality = 'auto';
  bool danmaku = false;
  Future<void> _writes = Future.value();
  int _revision = 0;

  Future<void> load() async {
    final revision = _revision;
    try {
      final raw = await storage.read();
      if (raw == null || revision != _revision) return;
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 1) return;
      final savedSpeed = value['speed'];
      if (savedSpeed is num && speeds.contains(savedSpeed.toDouble())) {
        speed = savedSpeed.toDouble();
      }
      if (value['autoNext'] is bool) autoNext = value['autoNext'] as bool;
      if (value['danmaku'] is bool) danmaku = value['danmaku'] as bool;
      if (['auto', '720p', '1080p'].contains(value['quality'])) {
        quality = value['quality'] as String;
      }
    } catch (_) {
      // Missing/corrupt preferences must not block video playback.
    }
  }

  Future<void> save({
    double? speed,
    bool? autoNext,
    String? quality,
    bool? danmaku,
  }) {
    if (speed != null && !speeds.contains(speed)) {
      throw ArgumentError.value(speed, 'speed');
    }
    _revision++;
    if (quality != null && !['auto', '720p', '1080p'].contains(quality)) {
      throw ArgumentError.value(quality, 'quality');
    }
    this.speed = speed ?? this.speed;
    this.autoNext = autoNext ?? this.autoNext;
    this.quality = quality ?? this.quality;
    this.danmaku = danmaku ?? this.danmaku;
    final snapshot = jsonEncode({
      'version': 1,
      'speed': this.speed,
      'autoNext': this.autoNext,
      'quality': this.quality,
      'danmaku': this.danmaku,
    });
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => storage.write(snapshot));
    return _writes;
  }
}
