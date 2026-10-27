import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'dart:convert';

/// Stores only verified media bodies, never playlists, URLs or request headers.
class HlsDiskCache {
  HlsDiskCache(this.directory, {this.limit = 150 * 1024 * 1024});
  final Directory directory;
  final int limit;
  final _pending = <String, Future<Uint8List>>{};
  Future<void> _writes = Future.value();
  int active = 0;
  String key(String identity, String asset) =>
      sha256.convert(utf8.encode('$identity/$asset')).toString();

  Future<void> initialize() async {
    await directory.create(recursive: true);
    for (final entity in await directory.list().toList()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        await entity.delete();
      }
    }
    await _prune(0);
  }

  Future<List<File>> _files() async => (await directory.list().toList())
      .whereType<File>()
      .where((file) => RegExp(r'[/\\][a-f0-9]{64}\.bin$').hasMatch(file.path))
      .toList();

  Future<int> bytes() async {
    var count = 0;
    for (final file in await _files()) {
      count += await file.length();
    }
    return count;
  }

  Future<void> _prune(int incoming) async {
    final files = await _files();
    final stats = <String, FileStat>{};
    for (final file in files) {
      stats[file.path] = await file.stat();
    }
    files.sort(
      (a, b) => stats[a.path]!.modified.compareTo(stats[b.path]!.modified),
    );
    var total = stats.values.fold<int>(0, (sum, stat) => sum + stat.size);
    for (final file in files) {
      if (total + incoming <= limit) break;
      await file.delete();
      total -= stats[file.path]!.size;
    }
  }

  Future<Uint8List> load(
    String identity,
    String asset,
    Future<Uint8List> Function() download,
  ) async {
    final digest = key(identity, asset);
    final existing = _pending[digest];
    if (existing != null) return existing;
    final work = _load(digest, download);
    _pending[digest] = work;
    try {
      return await work;
    } finally {
      _pending.remove(digest);
    }
  }

  Future<Uint8List> _load(
    String digest,
    Future<Uint8List> Function() download,
  ) async {
    final target = File('${directory.path}/$digest.bin');
    try {
      if (await target.exists()) {
        final data = await target.readAsBytes();
        if (data.isNotEmpty) {
          await target.setLastModified(DateTime.now());
          return data;
        }
      }
    } on FileSystemException {
      // Cache failures never prevent a network read.
    }
    final data = await download();
    if (data.isEmpty || data.length > limit) return data;
    final write = _writes.then((_) async {
      final temporary = File('${target.path}.tmp');
      try {
        await _prune(data.length);
        await temporary.writeAsBytes(data, flush: true);
        await temporary.rename(target.path);
      } on FileSystemException {
        try {
          if (await temporary.exists()) await temporary.delete();
        } on FileSystemException catch (_) {
          // Best effort only; startup also removes interrupted temporary files.
        }
      }
    });
    _writes = write.catchError((Object _) {});
    await _writes;
    return data;
  }

  Future<bool> clear() async {
    if (active > 0 || _pending.isNotEmpty) return false;
    await _writes;
    if (active > 0 || _pending.isNotEmpty) return false;
    for (final file in await _files()) {
      await file.delete();
    }
    return true;
  }
}
