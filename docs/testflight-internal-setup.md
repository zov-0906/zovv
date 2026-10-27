# TestFlight 内部测试配置

Bundle ID：`com.zovv.zovv`。App 已由用户在 App Store Connect 创建。

## 当前状态

- 新流程 `.github/workflows/ios-testflight.yml`，手动触发，运行检查、正式签名、导出仅供内部 TestFlight 使用的 IPA 并上传。
- 不自动提交 App Store 审核，不触发外部测试。上传成功后仍需等待苹果处理，并在 TestFlight 内部测试组中分配构建。
- Apple 签名资料尚未提供，未运行 macOS 正式构建和上传；本地仅完成脚本语法、Info.plist 和图标检查。
- iOS 全尺寸图标已从 Flutter 默认图标替换为项目已有 ZOVV 标志，与 Android 当前矢量图标一致。1024px 图标为不透明 RGB，不预裁圆角；同步替换 Android 遗留 mipmap 默认图标。显示名统一为 ZOVV。

## 1. 分发证书

进入 Apple Developer → Certificates, Identifiers & Profiles → Certificates → ＋，选择 **Apple Distribution**。

上传本机生成的 `artifacts/ios-signing/ZOVV-Distribution.certSigningRequest`，下载 `.cer`。

不要删除 `artifacts/ios-signing` 中的私钥与密码。CSR 不含私钥；下载的证书必须与这次 CSR 对应。用 `scripts/export-apple-p12.py <证书路径>` 合并证书与私钥；输出 P12 及密码只存忽略目录，不打印密码。

## 2. 描述文件

Profiles → ＋ → Distribution 下的 **App Store Connect**（旧界面可能为 App Store）。选择 `com.zovv.zovv`、刚创建的 Apple Distribution 证书，名称建议 `ZOVV App Store`，下载 `.mobileprovision`。不要选 Development、Ad Hoc 或 Developer ID。

## 3. App Store Connect API Key

App Store Connect → 用户和访问 → 集成 → App Store Connect API → 团队密钥。若尚未启用，由账户持有人申请访问。创建供上传使用的密钥，角色选 **App Manager**。记录 Key ID 和 Issuer ID，下载 `.p8`（仅可下载一次）。不需要提供 Apple ID 密码或双重认证码。

## 4. GitHub Secrets

仓库 Settings → Secrets and variables → Actions 添加：

| Secret | 内容 |
| --- | --- |
| IOS_DISTRIBUTION_P12_BASE64 | P12 文件的 Base64 |
| IOS_P12_PASSWORD | P12 导出密码 |
| IOS_PROFILE_BASE64 | 描述文件的 Base64 |
| ASC_KEY_ID | API Key ID |
| ASC_ISSUER_ID | API Issuer ID |
| ASC_PRIVATE_KEY_BASE64 | P8 文件的 Base64 |
| ZOVV_GATEWAY_TOKEN | 现有接口令牌，继续复用 |

资料通过本地文件和加密 Secrets 配置，不提交仓库，不发聊天。工作流运行期间在临时钥匙串安装证书，结束清理签名资料；仅保存调试符号，不公开发布 IPA。

## 5. 首次上传与手机安装

同步审核后的移动端代码、图标和工作流到发布检出，再推送 GitHub，手动运行 **iOS TestFlight internal**。首次 macOS 构建可能暴露 iOS 插件、签名或 SDK 兼容问题，需要按实际构建结果修复。

苹果处理完成后，在 TestFlight 回答适用的出口合规问题；项目含视频媒体解密逻辑，不能未经核实直接声明完全不使用非豁免加密。App Store Connect 的内部测试组添加具有适当权限的用户并分配构建，手机 TestFlight 接受邀请安装。内部测试用户权限按实际需要配置，不为普通测试者授予管理员权限。

本轮不部署服务器身份/调度/HLS 实验。App 连接现有公网 HTTPS 网关；服务端新功能与本地实验的差异需在真机验证时单独记录。
