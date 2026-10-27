import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/player/application/playback_preferences.dart';
import 'package:zovv/features/drama/domain/watch_progress.dart';

import '../startup/memory_library_storage.dart';

class SlowRead implements LibraryStorage {
  final pending = Completer<String?>();
  @override
  Future<String?> read() => pending.future;
  @override
  Future<void> write(String value) async {}
}

void main() {
  test('speed and autoplay persist together across player instances', () async {
    final storage = MemoryLibraryStorage();
    final first = PlaybackPreferences(storage: storage);
    await first.save(speed: 1.5, autoNext: false);
    final second = PlaybackPreferences(storage: storage);
    await second.load();
    expect(second.speed, 1.5);
    expect(second.autoNext, isFalse);
    await Future.wait([second.save(speed: 2), second.save(autoNext: true)]);
    final third = PlaybackPreferences(storage: storage);
    await third.load();
    expect(third.speed, 2);
    expect(third.autoNext, isTrue);
  });
  test('late disk read cannot overwrite a new user choice', () async {
    final storage = SlowRead();
    final prefs = PlaybackPreferences(storage: storage);
    final loading = prefs.load();
    await prefs.save(speed: 2);
    storage.pending.complete('{"version":1,"speed":0.75,"autoNext":false}');
    await loading;
    expect(prefs.speed, 2);
    expect(prefs.autoNext, isTrue);
  });
  test(
    'corrupt values fall back and unsupported speeds are rejected',
    () async {
      final prefs = PlaybackPreferences(
        storage: MemoryLibraryStorage('{"version":1,"speed":99}'),
      );
      await prefs.load();
      expect(prefs.speed, 1);
      expect(() => prefs.save(speed: 99), throwsArgumentError);
    },
  );
}
