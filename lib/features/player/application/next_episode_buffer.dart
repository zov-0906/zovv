import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:video_player/video_player.dart';

import '../../drama/domain/drama.dart';

enum NextEpisodeState { idle, preparing, ready, failed }

typedef VideoControllerFactory = VideoPlayerController Function(
  PlaybackSource source,
);

class PreparedEpisode {
  PreparedEpisode(this.index, this.source, this.controller);
  final int index;
  final PlaybackSource source;
  final VideoPlayerController controller;
  bool get usable =>
      controller.value.isInitialized &&
      !controller.value.hasError &&
      (source.expiresAt == null ||
          source.expiresAt!.isAfter(
            DateTime.now().add(const Duration(seconds: 10)),
          ));
}

class _Preparation {
  _Preparation(this.index);
  final int index;
  bool cancelled = false;
  VideoPlayerController? controller;
  late Future<PreparedEpisode?> result;
}

/// Owns at most one paused native player; ownership transfers on [take].
/// Cancelling a source request invalidates its result before native allocation.
class NextEpisodeBuffer {
  NextEpisodeBuffer({
    required this.resolve,
    required this.create,
    required this.onChanged,
  });
  final Future<PlaybackSource> Function(int index) resolve;
  final VideoControllerFactory create;
  final void Function(NextEpisodeState state) onChanged;
  _Preparation? _job;
  _Preparation? _handoff;
  Future<void> _retiring = Future.value();
  bool _disposed = false;

  void prepare(int index) {
    if (_disposed || _job?.index == index) return;
    unawaited(clear());
    final job = _Preparation(index);
    _job = job;
    onChanged(NextEpisodeState.preparing);
    job.result = _prepare(job);
  }

  Future<PreparedEpisode?> _prepare(_Preparation job) async {
    VideoPlayerController? controller;
    var phase = 'source';
    try {
      final source = await resolve(job.index)
          .timeout(const Duration(seconds: 90));
      await _retiring;
      if (_disposed || job.cancelled) return null;
      if (source.expiresAt?.isBefore(
            DateTime.now().add(const Duration(seconds: 10)),
          ) ??
          false) {
        throw const PlaybackUnavailable('预加载地址已过期');
      }
      controller = create(source);
      phase = 'initialize';
      job.controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (_disposed || job.cancelled) {
        await controller.dispose();
        return null;
      }
      await controller.setVolume(0);
      phase = 'seek';
      await controller.seekTo(Duration.zero);
      if (_disposed || job.cancelled) {
        await controller.dispose();
        return null;
      }
      if (controller.value.hasError) throw StateError('Preload failed');
      if (identical(_job, job)) onChanged(NextEpisodeState.ready);
      return PreparedEpisode(job.index, source, controller);
    } catch (error) {
      assert(() {
        debugPrint(
          'ZOVV preload episode=${job.index + 1} phase=$phase error=${error.runtimeType}',
        );
        return true;
      }());
      await controller?.dispose();
      if (!_disposed && !job.cancelled && identical(_job, job)) {
        _job = null;
        onChanged(NextEpisodeState.failed);
      }
      return null;
    }
  }

  Future<PreparedEpisode?> take(int index) async {
    final job = _job;
    if (job == null || job.index != index) {
      await clear();
      return null;
    }
    _job = null;
    _handoff = job;
    final prepared = await job.result;
    if (identical(_handoff, job)) _handoff = null;
    if (job.cancelled) return null;
    if (prepared != null && !prepared.usable) {
      await prepared.controller.dispose();
      return null;
    }
    return prepared;
  }

  Future<void> clear() {
    final job = _job;
    _job = null;
    if (job != null) {
      job.cancelled = true;
      final controller = job.controller;
      if (controller != null) {
        final previous = _retiring;
        _retiring = () async {
          await previous;
          await controller.dispose();
        }();
      }
    }
    return _retiring;
  }

  Future<void> cancelHandoff() {
    final job = _handoff;
    _handoff = null;
    if (job == null) return _retiring;
    job.cancelled = true;
    final controller = job.controller;
    if (controller != null) {
      final previous = _retiring;
      _retiring = () async {
        await previous;
        await controller.dispose();
      }();
    }
    return _retiring;
  }

  Future<void> dispose() {
    _disposed = true;
    unawaited(cancelHandoff());
    return clear();
  }
}
