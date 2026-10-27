package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.net.Uri;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.database.StandaloneDatabaseProvider;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import androidx.media3.datasource.cache.CacheDataSource;
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor;
import androidx.media3.datasource.cache.SimpleCache;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;
import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** ZOVV-only media cache. Manifests must always reflect the current server job. */
@OptIn(markerClass = UnstableApi.class)
public final class ZovvVideoCache {
  public static final long MAX_BYTES = 150L * 1024 * 1024;
  private static final Object LOCK = new Object();
  @Nullable private static SimpleCache cache;
  private static int readers;
  private ZovvVideoCache() {}

  private static SimpleCache get(Context context) {
    synchronized (LOCK) {
      if (cache == null) {
        Context app = context.getApplicationContext();
        cache = new SimpleCache(new File(app.getCacheDir(), "zovv-video"),
            new LeastRecentlyUsedCacheEvictor(MAX_BYTES), new StandaloneDatabaseProvider(app));
      }
      return cache;
    }
  }

  public static boolean isManifest(String value) {
    try {
      String path = URI.create(value).getPath().toLowerCase(Locale.ROOT);
      return path.endsWith(".m3u8") || path.endsWith(".mpd");
    } catch (RuntimeException ignored) { return true; }
  }

  public static String key(String identity, String value) {
    if (identity == null || !identity.matches("[a-zA-Z0-9:_-]{1,256}")) return value;
    String path = URI.create(value).getPath();
    String name = path.substring(path.lastIndexOf('/') + 1);
    if (!(name.equals("init.mp4") || name.endsWith(".m4s") || name.endsWith(".ts"))) {
      name = "movie.mp4";
    }
    return identity + "/" + name;
  }

  static DataSource.Factory factory(Context context, DataSource.Factory upstream,
      @Nullable String identity) {
    if (identity == null || !identity.matches("[a-zA-Z0-9:_-]{1,256}")) return upstream;
    try {
      DataSource.Factory cached = new CacheDataSource.Factory()
          .setCache(get(context)).setUpstreamDataSourceFactory(upstream)
          .setCacheKeyFactory(spec -> key(identity, spec.uri.toString()))
          .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR);
      return () -> new RoutingSource(upstream, cached);
    } catch (RuntimeException ignored) { return upstream; }
  }

  public static MethodChannel register(Context context, BinaryMessenger messenger) {
    MethodChannel channel = new MethodChannel(messenger, "zovv/video-cache",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue());
    channel.setMethodCallHandler((call, result) -> {
      if (!call.method.equals("stats") && !call.method.equals("clear")) {
        result.notImplemented(); return;
      }
      Map<String, Object> values = new HashMap<>();
      try {
        synchronized (LOCK) {
          SimpleCache current = get(context);
          boolean busy = readers > 0;
          if (call.method.equals("clear") && !busy) {
            for (String key : new HashSet<>(current.getKeys())) current.removeResource(key);
          }
          values.put("available", true);
          values.put("bytes", current.getCacheSpace());
          values.put("limit", MAX_BYTES);
          values.put("busy", busy);
          values.put("cleared", call.method.equals("clear") && !busy);
        }
      } catch (Exception ignored) { values.put("available", false); }
      result.success(values);
    });
    return channel;
  }

  private static final class RoutingSource implements DataSource {
    private final DataSource.Factory upstream, cached;
    private final List<TransferListener> listeners = new ArrayList<>();
    @Nullable private DataSource delegate;
    private boolean counted;
    RoutingSource(DataSource.Factory upstream, DataSource.Factory cached) {
      this.upstream = upstream; this.cached = cached;
    }
    @Override public void addTransferListener(TransferListener listener) {
      listeners.add(listener); if (delegate != null) delegate.addTransferListener(listener);
    }
    @Override public long open(DataSpec spec) throws IOException {
      boolean manifest = isManifest(spec.uri.toString());
      synchronized (LOCK) {
        delegate = (manifest ? upstream : cached).createDataSource();
        counted = !manifest;
        if (counted) readers++;
      }
      for (TransferListener listener : listeners) delegate.addTransferListener(listener);
      try { return delegate.open(spec); }
      catch (IOException | RuntimeException error) { close(); throw error; }
    }
    @Override public int read(byte[] buffer, int offset, int length) throws IOException {
      if (delegate == null) throw new IOException("Data source is not open");
      return delegate.read(buffer, offset, length);
    }
    @Nullable @Override public Uri getUri() { return delegate == null ? null : delegate.getUri(); }
    @Override public Map<String, List<String>> getResponseHeaders() {
      return delegate == null ? Collections.emptyMap() : delegate.getResponseHeaders();
    }
    @Override public void close() throws IOException {
      try { if (delegate != null) delegate.close(); }
      finally {
        delegate = null;
        synchronized (LOCK) { if (counted) { readers--; counted = false; } }
      }
    }
  }
}
