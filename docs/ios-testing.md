# iOS 云端构建

Actions → iOS unsigned IPA → Run workflow。仅手动触发，使用 macOS 15、Xcode 26.3、Flutter 3.47.8 和 Swift Package Manager，最低 iOS 15。

仓库 Secret `ZOVV_GATEWAY_TOKEN` 在构建时注入，用户已授权令牌随 IPA 分发；令牌不提交源码、不打印日志。下载该次运行的 Artifacts，解压外层 ZIP 得到 ZOVV-unsigned.ipa，再用爱思及自己的有效签名身份重签后安装。免费签名有效期以工具和 Apple 为准。

接口为 https://api.getagentconsole.space。产物保存7天。未签名IPA不能直接安装，不是TestFlight包。首次Xcode编译结果以Actions日志为准。

已显式选择 Xcode 26.3，避免 macOS 15 默认 Xcode 16.4 无法编译视频插件所用 Swift isolation API。后续镜像移除该版本时，需选择支持同等 Swift API 的新版 Xcode。
