# 红果来源接入

当前默认来源为 HongguoDramaRepository，通过本机 tools/hongguo-gateway 连接与参考项目一致的 **红果 → App（快速）** 线路。默认漫剧，支持真人剧、漫剧、AI 剧及题材选择，已验证《和离后我带女儿横扫魔域》与 1000 集详情。没有回退到西饭。

## 本机试用

运行 scripts/start-hongguo.ps1，启动仅监听 127.0.0.1:8765 的 Node 服务，并通过 adb reverse 连接雷电。scripts/run-android.ps1 会自动启动服务。此版本依赖电脑服务持续运行，离开当前调试环境不能独立访问 App 目录。正式发布需设计服务部署。

Android debug 仅对 localhost 放行明文 HTTP，来源站点和视频仍使用 HTTPS。没有关闭 TLS 验证。来源目录请求的匿名进程身份仅在内存中生成，不读取用户平台账号。

界面调试时可以让网关故意变慢：`ZOVV_SIMULATED_DELAY_MS=1600`（0–5000，默认 0）会让目录、搜索、详情接口延迟返回，用于在真机上检查骨架屏和局部 loading，`/health` 不受影响。

## 状态与边界

- /catalog：红果 App 分类与题材，支持 page 分页（每页 15 部）；客户端滚动到底自动续页。
- /search：搜索。App 搜索 → 公开短剧目录 → 本地目录索引三级兜底，响应带 `channel` 与 `notice`。
- /details：按 series_id 获取分集，验证剧集身份和 disable_play 状态。
- /playback：仅尝试官网明确公开的未保护视频。**未启用 App 加密媒体下载、解码或本地缓存，等待明确确认。**
- /health：明确返回 source=红果、channel=App、mediaProcessing=false。

## 搜索兜底

红果 App 搜索接口目前返回 HTTP 200 空响应，官网搜索接口 502。网关按以下顺序兜底，客户端只展示结果与一句说明：

1. `channel=app`：App 搜索正常，结果最准。
2. `channel=directory`：公开短剧目录按剧名检索（含红果编号），只用于定位剧目；详情与播放仍取自红果。
3. `channel=index`：网关启动后后台抓取过的目录页（1357 部起，持续增长），支持多词匹配（如“荒年萌宠”）。

目录兜底可用 `ZOVV_DIRECTORY_SEARCH=off` 关闭。客户端调试时可用 `--dart-define=ZOVV_SEARCH_PROBE=关键词` 预填搜索框，方便没有中文输入法的真机检查。

目录结果只有剧名与编号，网关会用官网 SSR 详情页补齐封面、简介、集数与标签（10 分钟缓存；最多 8 条、并发 3、6 秒预算，超时保留未补全的卡片）。搜索结果页因此能在点开前看到“题材 · 集数”和两行简介。

## 下一集预加载与重试

播放器加载某一集成功后，会用 `/prefetch?sid=&vid=` 让网关在后台准备下一集；切换时 `/playback` 直接命中同一份准备任务或缓存，不再重新签名、重新取片。预取失败只写日志，不影响当前播放。客户端还会在同一次播放会话内缓存已解析的播放地址（按分集）。

App 接口对连续请求较敏感，常见表现是非 JSON 响应，客户端原先会直接看到“App 接口未返回有效数据”。网关现在对取片和搜索最多重试 3 轮、线性退避并每轮重新签名；取片还会依次尝试主地址、备用地址与备用列表。`/health` 的 `prefetches` 计数可确认预加载是否生效。

## 详情页附加能力

- /comments：从官网播放页 SSR 读取公开评论（只读、部分评论、30 秒缓存），客户端以底部弹层展示。
- /sequel：用剧名与季数推断同系列后续季（同基础剧名 + 更高季数），搜索不可用时返回空结果与说明。
- 分享链接为 `https://hongguoduanju.com/player/{sid}/{vid}`，由客户端复制；收藏仍只保存在本机。

目录成功不等于视频播放链路已经完成。当前不支持付费解锁。与来源适配有关的源码及 GPL 许可保留在 tools/hongguo-gateway/vendor，具体来源与修改见同目录 README。

## 客户端边界

DramaRepository 提供 discover 和 resolveEpisode；DetailedDramaRepository 按需加载分集，SearchableDramaRepository 处理远程搜索。首页不会提前加载所有剧目的分集。长剧选集按每页 100 集展示，避免一次渲染千集按钮。

收藏与历史保存在本机，并保存剧目摘要，保证不在首页的搜索收藏仍可恢复。旧西饭记录没有删除，但在当前红果片单中隐藏。

## 正式业务 API 建议

| 接口 | 用途 |
|---|---|
| GET /v1/dramas?category=&query=&cursor= | 推荐、题材、搜索分页 |
| GET /v1/dramas/{id} | 简介与分集 |
| POST /v1/episodes/{id}/playback | 符合访问权限的短时播放凭证 |

本机网关是试用工具，尚无账号系统、云端同步、下载管理或后台管理。
