# Android 原生播放验证

独立测试入口：`tools/android_player_smoke.dart`。正常产品入口仍为 `lib/main.dart`。仅在安卓模拟器运行，不进行 iOS 构建。

验证原生解码尺寸、时长、播放、拖动、倍速；动态 HLS 从 2 秒窗口扩展至 12 秒时继续更新；相同身份缓存复用；16 轮写入后的 150MiB LRU 淘汰及释放后清理。合成样本不代表真实接口或公网性能。

## 准备

在 `artifacts/performance/android-fixture.mp4` 生成 12 秒、640×360、约 12Mbps 的 H.264 MP4，使用 `testsrc2`、`libx264`、`nal-hrd=cbr`、`+faststart`。大小应约 17MB，以便 16 轮写入触发淘汰。

在 `artifacts/performance/android-hls-fixture` **目录内**生成 12 秒、320×180 的 HLS EVENT 样本：H.264、25fps、`-g 25 -hls_time 2 -hls_segment_type fmp4 -hls_playlist_type event`，清单名 `index.m3u8`，分片名 `segment-%05d.m4s`。初始化文件 `init.mp4` 必须同目录。生成的媒体不加入产品资源或版本库。

在项目根目录启动 `node tools/android-player-fixture.cjs`，另一个终端执行：

```powershell
. ./scripts/enter-dev.ps1
adb -s emulator-5554 reverse tcp:8766 tcp:8766
flutter run --no-pub -d emulator-5554 -t tools/android_player_smoke.dart
```

以日志 `ZOVV_SMOKE PASS native playback, cache reuse, eviction and clear` 为完成依据。出现 FAIL 必须修复并重跑，构建成功不等于验收通过。测试后停止测试服务，重新以 `lib/main.dart` 构建、安装产品 App；测试入口的 APK 不交付。

最新证据及真实片源限制见 [android-optimization-progress.md](android-optimization-progress.md)。
