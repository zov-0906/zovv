# 设计与素材

## 设计参考

- Apple macOS 27 UI Kit：https://www.figma.com/community/file/1651309434229735362/macos-27
- 一泽 Eze 流光玻璃参考：https://x.com/eze_is_1/status/2112907849743691984
- 用户提供的本地动效视频：XDown.app_pi4VG39kpZaqOefQ_720p.mp4（仅研究参考，不随 App 打包）。

参考通透表面、细边高光、滑动选中项和轻微动效；未复制桌面窗口布局，未宣称完全复现 Apple 原生光学折射效果。

## 液态玻璃与加载

### 后续页面必须复用的交互规范

- 次级操作、展开收起与集数格使用 `GlassButton`：中性色文字、线性图标、0.7px 高光、12–16 圆角、最小 44 触控高度；选中使用局部强调色，按下缩放至 0.97，减少动态效果时关闭缩放。
- 评论、续作、选集使用 `GlassSheet`；关于面板复用同一 `GlassSurface`。浅色与夜间都从 `context.palette` 取色，不单独写默认紫色按钮或描边胶囊。
- 详情附加操作固定为两列等宽，文字允许换行；简介通过 `AnimatedSize` 展开收起，避免高度突变。详情滚过封面后，返回控件和状态栏随正文主题切换。
- `AppTheme` 提供文字按钮、描边按钮、浮动提示及弹层的统一兜底。新增功能的空状态、重试与错误状态也必须遵循同一套控件。
- Android 图标使用项目已经打包的线性 Material 图标；不能只引用 `CupertinoIcons` 而未提供其字体资源。

参考视频的关键帧已抽到 `artifacts/reference/mp4-frames`：接近纸白的底色、白色半透明胶囊、发丝级高光边、极轻阴影，以及一条缓慢穿过表面的淡彩流光。

表面刻意做得更“扁”：圆角从胶囊退到 11–18，模糊 sigma 降到 12，阴影统一为 `0 5 14`、透明度 5%（深色 22%），边框 0.7px。选中态用“白/深灰底 + 加粗 + 一颗强调色小圆点”表达，不靠大阴影和高光堆叠。

- `core/widgets/glass_surface`：玻璃底座，可选 `tint`（凹陷槽）、`sheen`（单次流光）、`breathe`（低频流光）。
- `core/widgets/liquid_segmented_control`、`glass_chip`：手写控件，替代 Cupertino 分段器与 Material ChoiceChip。
- `core/widgets/iridescent_sheen`：流光实现。默认单次；`breathe` 每 6.4 秒一次，`loop` 只给会消失的占位。呼吸与循环在应用退后台时停止，在 widget 测试里整体关闭（`core/motion.dart`），避免无谓耗电与 `pumpAndSettle` 失效。
- `core/widgets/zovv_loader`：手绘加载标记（玻璃弧 + 高光点 + 两颗卫星）；启动进度条为手绘 `_StartupTrace`。
- `core/widgets/skeleton`：灰底扫光占位（浅色 `#E3E7F0` / 深色 `#1B1F27`）。
- `core/widgets/playback_scrubber`：手绘播放进度条（细轨 + 白色填充 + 带光晕的旋钮），替代 Material Slider；播放器底部控件收进一块扁平深色玻璃面板，选集面板改成 5 列集数格。

## 主题

`ZovvPalette`（ThemeExtension）集中定义 canvas / ink / muted / line / accent 与玻璃四件套，`AppTheme.light` / `AppTheme.dark` 各自装配。页面统一用 `context.palette.x` 取色；只有播放器固定使用纸黑夜色，不随主题切换。

外观在“关于 ZOVV”里切换：跟随系统 / 浅色 / 夜间，写入 `zovv.theme_mode.v1`（`core/theme/theme_controller.dart`），读取失败时回落到跟随系统。

## 视频

Sintel © Blender Foundation，Creative Commons Attribution 3.0。
官方项目：https://durian.blender.org/
官方预告片：https://download.blender.org/durian/trailer/
播放器展示作品署名。片单名称、简介为虚构内容，与示例视频无对应剧情关系。

## 海报

本地海报为 Unsplash 风景图片，作为演示占位素材：

| 文件 | 原图 |
|---|---|
| evening.jpg | https://images.unsplash.com/photo-1470252649378-9c29740c9fa8 |
| night.jpg | https://images.unsplash.com/photo-1519608487953-e999c86e7455 |
| sea.jpg | https://images.unsplash.com/photo-1518837695005-2083093ee35b |
| mountain.jpg | https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05 |
| moon.jpg | https://images.unsplash.com/photo-1511300636408-a63a89df3482 |
| forest.jpg | https://images.unsplash.com/photo-1441974231531-c6227db76b6e |

正式短剧接入时使用对应授权剧目的海报。ZOVV 标识为代码绘制，未拷贝红果项目的品牌、源代码或片源算法。
