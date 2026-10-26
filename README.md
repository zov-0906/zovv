# ZOVV Stories

Flutter 短剧平台原型，Android 先行，保留 iOS 平台工程。采用浅色留白、局部玻璃材质和浮动导航。

## 已实现

- 极简启动欢迎页及重播。
- 发现推荐、题材分类、本地剧名搜索。
- 首页列表滚动到底自动加载下一页，页脚显示加载/失败/到底状态。
- 搜索三级兜底：App 搜索 → 公开短剧目录 → 本地已收录索引，并说明结果来源。
- 发现页「继续观看」：按最近观看排序，直接回到上次的分集与进度，无需先进详情页。
- 液态玻璃控件（胶囊分段器 + 题材胶囊）、局部灰色骨架屏、手绘加载动画与启动进度条，项目内不使用原生进度圈。
- 扁平化导航与悬浮按钮、手绘播放进度条与玻璃化选集面板。
- 浅色 / 夜间双主题，可在“关于 ZOVV”切换或跟随系统；播放器固定深色。
- 剧集详情、收藏、选集入口。
- 视频播放暂停、进度拖动、前后切集、上下滑动切集、自动连播、横竖屏。
- 本地收藏、观看记录、断点续播，后台暂停与失败重试；片单页「观看记录」可直接续播。
- 播放时后台预加载下一集，切换不再重新取片；网关对连续取片失败自动重试并与备用地址轮换。
- 详情页附加操作：查找下一季、复制分享链接、收藏到本机、查看公开剧评（只读）。

当前默认来源为 **红果 → App（快速）**，与参考项目截图一致，支持真人剧、漫剧和 AI 剧目录、题材、搜索与完整分集列表。不再默认使用西饭。

目前是本机联调版：需运行 `scripts/start-hongguo.ps1` 并保持电脑服务开启，通过 adb reverse 连接雷电。App 加密媒体下载、解码和本地缓存未启用，等待明确确认；目录可预览，不将目录成功当成视频已可播放。

网关复用参考项目的红果 App 适配组件，相关源码和 GPL 许可位于 tools/hongguo-gateway/vendor。

## 开发与验证

```powershell
. .\scripts\enter-dev.ps1
flutter --no-version-check pub get
flutter --no-version-check analyze lib test
flutter --no-version-check test
.\scripts\run-android.ps1
```

默认连接雷电 `127.0.0.1:5555`，可通过 `-Device <设备ID>` 指定真机。调试版在 Android 中关闭 Impeller，采用兼容渲染器，以适配雷电视频纹理；正式构建不覆盖 Flutter 默认渲染设置。

```powershell
flutter --no-version-check build apk --debug --target-platform android-x64,android-arm64
```

产物：`build/app/outputs/flutter-apk/app-debug.apk`。正式发布还需确定片源、应用标识、签名和服务端。

不看网关、只调界面时，可用内置演示片源构建：

```powershell
flutter --no-version-check build apk --debug --target-platform android-x64,android-arm64 --dart-define=ZOVV_DEMO_SOURCE=true
```

演示片源播放 Blender 开源预告片，不需要本机网关；发布构建不要带这个参数。

## 工程说明

- [架构约定](docs/architecture.md)
- [内容接口接入](docs/content-api.md)
- [素材与设计参考](docs/design-and-assets.md)
- [打包与网关部署](docs/release.md)
- [本机开发环境](开发环境.md)

iOS 工程未在 macOS/Xcode 上构建验证。


