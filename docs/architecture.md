# 架构约定

按功能划分，保持可替换的数据来源和可测试的本地状态。不在 UI 中写第三方片源请求或签名逻辑。

## 播放性能适配（2026-10-27）

播放模型使用匿名注册下发的设备身份，网关负责原子持久化、并发注册合并及重启复用；手机无需接触设备注册载荷和媒体密钥。身份按主机生成，不随源码、部署包或日志分发。注册失败明确返回错误，不使用随机身份回退。

`ScheduledPlaybackRepository` 表达当前集／下一集优先级及会话归属；可选 `PreloadCancellationRepository` 撤回投机工作。客户端状态与网关所有权分开管理，取消只释放本会话的下一集，不误伤共享观看者。乱序请求通过集序号与预取修订号失效。

倍速、画质、弹幕及连播偏好独立存储；弹幕数据窗口与轨道绘制分离。清晰度交接沿用旧播放，备用播放器可用且尺寸确认后再交换，失败保留旧进度。手机不承担解密、转封装或转码。

Android 原生差异限制在固定版本的 `packages/video_player_android` 和 `AndroidVideoCache` 适配中；150MiB LRU 只存媒体字节，清单每次取新。编码缓冲约 8～20 秒、每播放器目标 16MiB，不能将此误认为包含解码画面的 App 总内存上限。最多当前与备用两个播放器，画质交接前先释放下一集及退休播放器。

网关 HLS 处于实验开关 `ZOVV_STREAM_PLAYBACK` 下，默认 MP4 兼容链路保留。服务端临时分片有磁盘、任务、进程、超时及所有权限制；接口元数据耗时和手机原生首进度分开记录。iOS 适配与验证按用户要求延后，不据安卓结果声明已支持。

```text
lib/
  app/                         初始化、应用依赖组装、启动覆盖层
  core/theme/                  设计颜色与主题
  core/widgets/                玻璃表面、柔光背景、品牌标识
  features/
    startup/                   欢迎页、生命周期、本地播放标记
    drama/
      domain/                  Drama、Episode、PlaybackSource、来源与存储接口
      data/                    红果本机 App 网关、其他适配器、演示适配器、SharedPreferences 存储实现
      application/             目录加载、收藏与观看进度
      presentation/            发现、搜索、片单、详情、玻璃导航
    player/presentation/       视频控制器生命周期与播放交互
```

## 依赖方向

页面依赖 domain 与 application；application 通过 domain 定义的接口获取数据，不依赖具体存储实现。`DramaShell` 组装目录与片单控制器，`ZovvApp` 允许注入 Repository 和 Storage，测试不访问真实平台插件。

`DramaRepository` 是片源边界：`discover()` 提供统一剧目，`resolveEpisode()` 在播放时按需解析地址。额外的详情和搜索能力通过独立接口暴露，列表摘要不提前请求全剧分集。`PlaybackSource` 包含 URI、请求头、可选过期时间和来源说明。真实后台接入见 content-api.md。

`DramaLibraryController` 管理收藏和观看进度，使用串行写入防止慢请求覆盖新记录；公开只读集合。存储错误反馈到片单页，可重试，避免伪装成已成功保存。

`resumeEntries` 只把「有摘要且有可能续播」的记录连成 `ResumeEntry`，发现页与片单页共用这份派生数据，进度为 0 也不补假进度条——分集时长尚未持久化。续播入口在 `DramaShell`：先按 id 复用当前目录条目，目录摘要没有分集时才请求详情，请求期间显示准备遮罩，失败留在原页面并提示，不把目录成功当成可播放。

`PlayerScreen` 独占原生播放器，每次换集递增请求代号，异步初始化完成后核对代号和页面生命周期。离开页面时释放播放器；旧请求返回不会新建页面或替换当前播放。播放中每约 5 秒、暂停、换集、返回及退后台保存进度。回到前台保持暂停，由用户继续。

## 页面与状态

发现、搜索、片单保存在 IndexedStack 中，切换保留滚动和搜索条件；详情和播放器通过 CupertinoPageRoute 进入。当前无需全局业务状态容器。增加账号、订阅和深链接后再统一引入路由守卫和跨模块状态管理。

切换来源类型或题材时只有列表区域进入骨架屏，页头、来源胶囊和题材胶囊保持可见可点；加载失败与空列表也留在列表区域内，不再用整屏转圈或整屏错误页接管。只有“准备播放某一集”这类模态动作才使用遮罩提示。

欢迎页首次展示单一开始按钮，后续启动约 1.8 秒自动进入发现页。关于面板保留重播入口。

## 视觉与平台

局部 BackdropFilter 模糊、细亮边和轻阴影构成玻璃材质。导航选中背景滑动，遵循减少动态效果设置；高对比度模式改用不透明表面。正文和海报不整屏玻璃化。

加载动画全部手写：核心组件在 `core/widgets`（`ZovvLoader`、`SkeletonBlock`、`IridescentSheen`、`LiquidSegmentedControl`、`GlassChip`、`PlaybackScrubber`），项目中不使用 Material 的进度圈、进度条与 Slider。流光默认单次播放，循环只用于会消失的占位内容；`breathe` 的 6 秒级低频流光在应用退后台时暂停、在 widget 测试里关闭（`core/motion.dart`）。

## 主题与取色

颜色集中在 `core/theme/app_theme.dart` 的 `ZovvPalette`（ThemeExtension）：canvas、ink、muted、line、accent 与玻璃填充/描边/阴影。页面通过 `context.palette` 取色，不写死色值；`AppTheme.light` 与 `AppTheme.dark` 各自装配 ThemeData。外观模式由 `ThemeController` 持有并持久化（跟随系统 / 浅色 / 夜间），在“关于 ZOVV”中切换。播放器固定深色，只用 `AppColors.night` 与固定强调色，不随主题变化。

Android debug 使用兼容渲染路径解决雷电 Vulkan 视频纹理切换问题；正式构建保持默认。iOS 目录已保留，未实机验证。不使用 iOS 原生 Liquid Glass API，也没有直接移植 macOS 桌面布局。


默认红果来源使用本机调试网关，详情与播放状态严格分开。加密媒体处理未启用；来源适配组件许可保留在 tools/hongguo-gateway/vendor。

