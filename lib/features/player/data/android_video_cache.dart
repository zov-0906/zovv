import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoCacheSnapshot {
  const VideoCacheSnapshot({
    required this.bytes,
    required this.limit,
    required this.busy,
    required this.cleared,
  });
  final int bytes, limit;
  final bool busy, cleared;
}

/// Android adaptation only. Other platforms keep their existing player path.
abstract final class AndroidVideoCache {
  static const _channel = MethodChannel('zovv/video-cache');
  static Future<VideoCacheSnapshot?> read({bool clear = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      var raw = await _channel.invokeMapMethod<String, dynamic>(
        clear ? 'clear' : 'stats',
      );
      // ExoPlayer's asynchronous release can outlive controller.dispose(). Give
      // retired readers a brief grace period; an active reader still blocks clear.
      if (clear) {
        for (var attempt = 0; raw?['busy'] == true && attempt < 6; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          raw = await _channel.invokeMapMethod<String, dynamic>('clear');
        }
      }
      if (raw?['available'] != true ||
          raw?['bytes'] is! int ||
          raw?['limit'] is! int) {
        return null;
      }
      return VideoCacheSnapshot(
        bytes: raw!['bytes'] as int,
        limit: raw['limit'] as int,
        busy: raw['busy'] == true,
        cleared: raw['cleared'] == true,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
