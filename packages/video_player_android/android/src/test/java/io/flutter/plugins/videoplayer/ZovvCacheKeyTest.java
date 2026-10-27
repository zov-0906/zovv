package io.flutter.plugins.videoplayer;
import static org.junit.Assert.*;
import org.junit.Test;

public class ZovvCacheKeyTest {
  @Test public void manifestsAlwaysBypassMediaCache() {
    assertTrue(ZovvVideoCache.isManifest("https://example.com/index.m3u8?v=1"));
    assertTrue(ZovvVideoCache.isManifest("https://example.com/master.MPD"));
    assertFalse(ZovvVideoCache.isManifest("https://example.com/segment-00001.m4s"));
  }
  @Test public void cacheIdentitySeparatesEpisodeQualityVersionAndAsset() {
    String a="https://example.com/stream/token-a/segment-00001.m4s";
    String b="https://example.com/stream/token-b/segment-00001.m4s";
    assertEquals(ZovvVideoCache.key("series:episode:auto:version1",a),
        ZovvVideoCache.key("series:episode:auto:version1",b));
    assertNotEquals(ZovvVideoCache.key("series:episode:auto:version1",a),
        ZovvVideoCache.key("series:episode:1080p:version1",a));
    assertNotEquals(ZovvVideoCache.key("series:episode:auto:version1",a),
        ZovvVideoCache.key("series:other:auto:version1",a));
    assertNotEquals(ZovvVideoCache.key("series:episode:auto:version1",a),
        ZovvVideoCache.key("series:episode:auto:version2",a));
    assertNotEquals(ZovvVideoCache.key("id",a),ZovvVideoCache.key("id","https://example.com/init.mp4"));
    assertEquals(a,ZovvVideoCache.key(null,a));
    assertEquals(150L*1024*1024,ZovvVideoCache.MAX_BYTES);
  }
}
