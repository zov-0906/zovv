import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/watch_progress.dart';
import '../domain/drama.dart';

/// One resumable drama: the saved summary joined with its latest progress.
class ResumeEntry {
  const ResumeEntry({required this.drama, required this.progress});
  final Drama drama;
  final WatchProgress progress;

  int get episodeNumber => progress.episodeIndex + 1;
  String get episodeLabel => '第 $episodeNumber 集';

  /// Saved position as m:ss, or h:mm:ss for feature-length material.
  String get positionLabel {
    final seconds = progress.positionSeconds;
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return minutes < 60
        ? '$minutes:$rest'
        : '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
  }

  String get caption => '$episodeLabel · 已看 $positionLabel';
}

class DramaLibraryController extends ChangeNotifier {
  DramaLibraryController(this.storage);
  final LibraryStorage storage;
  final Set<String> _favorites = {};
  final Map<String, WatchProgress> _progress = {};
  final Map<String, Drama> _known = {};
  List<Drama> get knownDramas => List.unmodifiable(_known.values);
  void remember(Drama drama) {
    if (_disposed) return;
    _known[drama.id] = drama;
    if (ready) persist();
  }

  bool ready = false;
  String? error;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Set<String> get favorites => Set.unmodifiable(_favorites);
  WatchProgress? progressFor(String id) => _progress[id];
  List<WatchProgress> get recent =>
      _progress.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Newest first. Records whose summary is unknown cannot be resumed and are
  /// skipped instead of rendering an empty card.
  List<ResumeEntry> get resumeEntries => [
    for (final progress in recent)
      if (_known[progress.dramaId] case final drama?)
        ResumeEntry(drama: drama, progress: progress),
  ];
  Future<void> refresh() async {
    await _writes;
    if (!_disposed) await load();
  }

  Future<void> load() async {
    try {
      final raw = await storage.read();
      if (_disposed) return;
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is! Map<String, dynamic> || value['version'] != 1) {
          throw const FormatException('Invalid library snapshot');
        }
        final favorites = value['favorites'];
        final metadata = value['metadata'];
        if (metadata is List) {
          for (final item in metadata) {
            final drama = Drama.fromSummaryJson(item);
            if (drama != null) _known[drama.id] = drama;
          }
        }
        if (favorites is List) _favorites.addAll(favorites.whereType<String>());
        final progress = value['progress'];
        if (progress is List) {
          for (final item in progress) {
            final parsed = WatchProgress.fromJson(item);
            if (parsed != null) _progress[parsed.dramaId] = parsed;
          }
        }
      }
    } catch (_) {
      if (_disposed) return;
      error = '本地记录读取失败，新记录仍可正常保存';
    }
    if (!_disposed) {
      ready = true;
      notifyListeners();
    }
  }

  void toggleFavorite(String id) {
    if (!ready || _disposed) return;
    if (!_favorites.remove(id)) _favorites.add(id);
    notifyListeners();
    persist();
  }

  void record(WatchProgress progress) {
    if (!ready || _disposed) return;
    _progress[progress.dramaId] = progress;
    notifyListeners();
    persist();
  }

  Future<void> persist() {
    if (!ready || _disposed) return Future.value();
    final payload = jsonEncode({
      'version': 1,
      'metadata': _known.values
          .where(
            (drama) =>
                _favorites.contains(drama.id) ||
                _progress.containsKey(drama.id),
          )
          .map((drama) => drama.toSummaryJson())
          .toList(),
      'favorites': _favorites.toList(),
      'progress': _progress.values.map((item) => item.toJson()).toList(),
    });
    // Serialize writes so a slower previous save cannot overwrite newer data.
    _writes = _writes.then((_) async {
      try {
        await storage.write(payload);
        if (!_disposed && error != null) {
          error = null;
          notifyListeners();
        }
      } catch (_) {
        if (!_disposed) {
          error = '本地保存失败，点击重试';
          notifyListeners();
        }
      }
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
