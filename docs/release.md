# 打包与网关部署

## 现在的依赖关系

App 自己不签名、不取片、不解密：目录、搜索、详情、评论、续作、播放地址与本地媒体都由 `tools/hongguo-gateway` 提供。调试时它跑在电脑上，App 通过 `adb reverse tcp:8765 tcp:8765` 访问 `127.0.0.1:8765`。

所以：**直接把现在的 APK 装到别人手机上，没有网关就跑不起来**（会提示“无法连接网关 …”）。正式给用户装，必须选下面的 A 或 B。

网关地址在编译期注入，运行期不需要改代码：

```powershell
# 本地默认（联调包）
flutter build apk --release

# 指向局域网电脑或已部署的服务器
flutter build apk --release `
  --dart-define=ZOVV_GATEWAY=https://api.example.com `
  --dart-define=ZOVV_GATEWAY_TOKEN=换成足够长的随机串
```

## 本次部署记录（已上线）

- 服务器：`140.143.201.224`（Ubuntu 26.04，2 核 2G，4Mbps），Node.js 22 + ffmpeg 8。
- 网关：`/opt/zovv-gateway`，systemd 服务 `zovv-gateway`，监听 `127.0.0.1:8765`。
- 反向代理：Caddy，App 接口为 `https://api.getagentconsole.space`（443 端口）；域名 HTTP 跳转 HTTPS。
- 环境变量 `/etc/zovv-gateway.env`（0600）：
  `HONGGUO_MEDIA_TRIAL=1`、`ZOVV_BIND=127.0.0.1`、`ZOVV_PUBLIC_ORIGIN=https://api.getagentconsole.space`、
  `ZOVV_GATEWAY_TOKEN=…`、`ZOVV_INDEX_ON_START=0`、`ZOVV_INDEX_FILE=/opt/zovv-gateway/data/catalog-index.json`、
  `ZOVV_FFMPEG=/usr/bin/ffmpeg`、`NODE_OPTIONS=--max-old-space-size=768`。
- 目录索引：本地准备好的 1357 部随包上传；**不在服务器上后台抓取**（抓取会和取片抢同一个 App 接口，实测会导致取片连败）。
- App 构建：`.\scripts\build-remote-apk.ps1`（默认指向该服务器，令牌从 `artifacts/gateway/deploy-token.txt` 读取）。

常用运维命令：

详情优化已部署：`/opt/zovv-gateway/details-service.cjs`；部署前适配器备份位于 `/opt/zovv-gateway/backups/details-before/server.cjs`。故障诊断可按响应中的 `requestId` 查 `journalctl -u zovv-gateway`。详情缓存有 16 MiB 上限，重启会清空；缓存状态从 `/health` 的 `details` 读取。回滚时恢复备份的 server.cjs 并重启服务即可，新模块可保留。

```bash
systemctl status zovv-gateway
journalctl -u zovv-gateway -n 50
tail -f /var/log/caddy/zovv.log
curl -s http://127.0.0.1/health
```

### HTTPS 配置（当前）

Cloudflare 灰云 A 记录指向现有服务器。证书通过 Certbot 的 Cloudflare DNS 验证签发，`certbot.timer` 自动续期，部署钩子 `/etc/letsencrypt/renewal-hooks/deploy/zovv-caddy.sh` 更新 Caddy 证书并 reload。令牌位于服务器 `/etc/letsencrypt/cloudflare.ini`，权限 0600，不纳入源码。Android 远程构建脚本默认使用该 HTTPS 域名；本地联调仍可显式指定 localhost。媒体 URL 同步使用 HTTPS 域名。

### 早期仅 HTTP 的情况（已被上述配置替代）

该机器没有已备案域名。用 `sslip.io` 之类域名申请证书时，80 端口的 ACME 校验被腾讯云拦截到
`dnspod.qcloud.com/static/webblock.html`，TLS-ALPN 也超时，Let's Encrypt 与 ZeroSSL 都签不下来。
所以当前用 **HTTP + 共享令牌**。升级路径：

1. 有备案域名后，把 Caddy 站点改成该域名即可自动 HTTPS（App 改 `ZOVV_GATEWAY=https://…`）。
2. 或在 8443 上自签证书，并把证书作为 trust anchor 打进 App（`network_security_config`）。
3. 或用 Cloudflare Tunnel 之类的外置入口。

### 安全提醒

- 服务器 root 口令已在聊天中出现过，建议立刻 `passwd` 更换，并改用密钥登录。
- 令牌随 APK 分发，属于共享口令；泄漏后改 `/etc/zovv-gateway.env` 并重启服务即可作废旧包。
- 4Mbps 带宽大约够 1 个 720p 观众；多人同时看会卡。

## A. 联调包（自己用，最快）

网关留在电脑，手机和电脑同一 Wi-Fi：

1. 电脑上启动网关（会自动抓取目录索引）：

   ```powershell
   cd D:\zovvWorkspace\zovv
   .\scripts\start-hongguo.ps1 -Device <手机在 adb 里的设备号>
   ```

2. 让网关监听局域网地址（默认只监听 127.0.0.1）：

   ```powershell
   $env:ZOVV_BIND='0.0.0.0'
   .\scripts\start-hongguo.ps1
   ```

   只在家里/公司内网这样用；不要把 8765 直接映射到公网而不加 token。

3. 编译时指向电脑 IP：

   ```powershell
   flutter build apk --release --dart-define=ZOVV_GATEWAY=http://192.168.1.10:8765
   ```

4. HTTP 明文只在 Android 的 network security config 里放行。调试包已放行 `127.0.0.1`；用局域网 IP 时，在 `android/app/src/debug/res/xml/local_gateway_network.xml` 增加 `<domain>192.168.1.10</domain>`。**release 包不要开明文**，直接用 HTTPS（见 B）。

## B. 部署网关（推荐：能装给别的用户）

一台有公网 IP 的服务器（1 核 2G 足够原型规模）：

1. 拷贝 `tools/hongguo-gateway`（含 `node_modules` 或重新 `npm i`）到服务器，Node.js 22+。
2. 设置环境变量并启动：

   ```bash
   export ZOVV_GATEWAY_TOKEN="$(openssl rand -hex 24)"
   export ZOVV_PUBLIC_ORIGIN="https://api.example.com"
   export HONGGUO_MEDIA_TRIAL=1
   node server.cjs
   ```

   `ZOVV_PUBLIC_ORIGIN` 决定 `/playback` 返回的媒体地址；`ZOVV_GATEWAY_TOKEN` 打开鉴权后，除 `/health` 外都要带 `Authorization: Bearer <token>`（媒体地址也在内）。

3. 用 Caddy 做 HTTPS 反代（自动证书）：

   ```
   api.example.com {
     reverse_proxy 127.0.0.1:8765
     request_body { max_size 2MB }
   }
   ```

4. App 编译时带上地址与同一个 token（见上面的命令）。token 会随包分发，属于“共享口令”级别，不要当作用户鉴权。

5. 运维注意：
   - 网关进程要有重启策略（systemd `Restart=always` 或 pm2）。
   - 单个出口 IP 大量请求更容易被来源风控；先小范围试用，观察 `/health` 的 `prefetches` 与 stderr 的 `[media]` 日志。
   - 媒体缓存是内存态（默认 4 集 / 320MB / 15 分钟），重启即清空；不要把它当 CDN。
   - 日志会包含剧集编号与错误文本，公网部署前确认没有敏感信息。

## C. 完全客户端化（工作量最大）

把签名（SM3 / Medusa / Gorgon / AES）、取片、解密、目录与搜索全部迁进 Dart：

- 优点：不依赖服务器，装完即用。
- 代价：`vendor/app-source.js` 的签名算法要逐段移植并用真实样本回归；解密依赖 FFmpeg（需换 `ffmpeg-kit` 之类原生库）；包体变大；上游一改签名就要重新发版。
- 结论：原型阶段不建议，优先 B；等产品定型、确定合法片源后再评估。

## 打包清单（release 前逐项确认）

| 项 | 现状 | 要求 |
|---|---|---|
| `applicationId` | `com.zovv.zovv` | 换成自己的域名反写 |
| 签名 | release 复用 debug 签名 | 生成正式 keystore，写进 `key.properties` |
| 版本 | `0.2.0+2` | 按发布节奏递增 |
| 网关地址 | 默认 localhost | `--dart-define=ZOVV_GATEWAY=https://…` |
| 网关令牌 | 未设置 | 公网必须设置 `ZOVV_GATEWAY_TOKEN` |
| 调试开关 | `ZOVV_DEMO_SOURCE`、`ZOVV_SEARCH_PROBE`、`ZOVV_SIMULATED_DELAY_MS` | 发布构建不要带 |
| 明文 HTTP | 仅 debug 放行 localhost | release 只走 HTTPS |
| 图标/启动图 | 已替换 ZOVV 图标 | 确认各密度与自适应图标 |
| 法律与隐私 | 片源为第三方，未做隐私政策 | 上架前补齐；当前仅本机联调 |

## 已实现的接缝

- `lib/core/config/zovv_gateway.dart`：`ZOVV_GATEWAY` / `ZOVV_GATEWAY_TOKEN`，`endpoint()` 组 URL、`sameOrigin()` 校验媒体地址。
- `HongguoDramaRepository`：统一走配置的网关；连接失败提示里带上网关地址，便于用户/客服定位。
- 网关：可选 `ZOVV_GATEWAY_TOKEN` 鉴权、`ZOVV_PUBLIC_ORIGIN` 控制媒体地址、`ZOVV_BIND` 可扩展监听地址。
