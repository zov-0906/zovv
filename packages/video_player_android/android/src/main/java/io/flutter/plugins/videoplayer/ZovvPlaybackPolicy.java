package io.flutter.plugins.videoplayer;

import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;

@OptIn(markerClass = UnstableApi.class)
public final class ZovvPlaybackPolicy {
  private ZovvPlaybackPolicy() {}
  public static DefaultLoadControl create(VideoPlayerOptions options) {
    if (options.backBufferDurationMs != null && options.backBufferDurationMs < 0) {
      throw new IllegalArgumentException("backBufferDurationMs must be at least 0");
    }
    int back = options.backBufferDurationMs == null ? 0
        : (int) Math.min(options.backBufferDurationMs, Integer.MAX_VALUE);
    return new DefaultLoadControl.Builder()
        .setBufferDurationsMs(15000, 30000, 3000, 6000)
        .setTargetBufferBytes(24 * 1024 * 1024)
        .setPrioritizeTimeOverSizeThresholds(false)
        .setBackBuffer(back, true).build();
  }
}
