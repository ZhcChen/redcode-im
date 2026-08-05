# RedCode IM 剩余任务清单

更新时间：2026-08-06

本文档是当前仓库剩余任务的唯一 active 总入口。IM 2.0 的产品合同仍以
`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md` 的 U1-U13
定义为基准（该计划已标记 superseded，客户端主线由
`docs/plans/2026-08-04-005-feat-native-client-rebuild-plan.md` 承接）；执行顺序、
验收标准和停止条件以当前 active 计划的执行状态总账为准（`2026-08-03-001` 已并入并
标记 superseded）。更早的剩余任务分解仅作历史追踪，不再决定当前优先级。

## 入口文档

- 剩余任务完整执行分解（历史归档）：`docs/reports/remaining-task-breakdown-2026-07-05.md`
- IM 2.0 正式开发总计划（已 superseded）：`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md`
- 原生客户端重建执行计划（当前客户端主线）：`docs/plans/2026-08-04-005-feat-native-client-rebuild-plan.md`
- Flutter U8 设备验收记录：`docs/reviews/2026-08-02-im-2-0-u8-device-acceptance-review.md`
- H5 Flutter parity 计划（历史归档）：`docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- E2EE G4 复审整改与最终收口计划（当前唯一执行入口）：`docs/plans/2026-08-06-u10-e2ee-g4-remediation-closure-plan.md`
- E2EE 原生客户端最终验证（已完成）：`docs/plans/2026-08-05-u10-e2ee-native-clients-final-verification-plan.md`
- E2EE 产品契约（历史总计划）：`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
- API 性能基线：`docs/reports/performance/api-compose-baseline-2026-07-01.md`
- 测试入口：`docs/reference/testing/README.md`
- Flutter `app/` 已于 2026-08-04 废弃，目录已随阶段 3 删除（git 历史可追溯）；
  原生双端 `android-app` / `ios-app` 已恢复为 2.0 客户端主线。

## 当前结论

- 当前主线：U10 G4.1 复审整改 -> 四视角重新复审 -> 干净基线全量与 live 重放
  -> 最终 Go/No-Go 裁决 -> 原生功能迁移总收口 -> 多平台发布。
- 当前立即任务：U1 恢复手册与供应链日期门禁已关闭；唯一 checkpoint 为
  `U2.1`，加固 G3 候选窗口幂等 cleanup。
- 当前下一阶段：按 `U2 -> U7` 关闭恢复真实性、两类 cleanup、H5 production
  Chrome 审计、持久证据和真实 release workflow，再执行 `U8 -> U9`。
- 当前发布阻断项：U10 G4 最终裁决、原生功能迁移总收口、签名/版本/升级/回滚链路。
- 朋友圈、扫一扫、附近的人、音视频通话和游戏默认不阻断 2.0 核心首发；只有本总账明确标记为“2.0 首发必需”的 P1 切片才成为发布门禁。
- `ANDROID-P1-01 聊天扩展` 的既有实现与验证证据随 `android-app` 基座恢复保留，
  作为原生功能迁移的输入。
- `h5-app` 已具备聊天、搜索、联系人 store、群设置和设置页面等基础能力；后续以
  `im-ui-html/` 设计源与原生双端为参考继续对齐。
- Flutter `app/` 已废弃（2026-08-04），不再作为移动端主线；其 U1-U9 完成证据保留
  为历史基线，`app/` 目录删除前仅保留 git 历史可追溯。
- Android / iOS 原生双端已于 2026-08-04 恢复为 2.0 客户端主线，基座构建与单测
  通过；功能迁移由后续原生专项计划承接。
- Google / Apple 登录不进入当前主线；默认普通账号密码注册/登录。
- 邮箱注册/登录只作为后台配置能力保留；当前自动化不依赖真实邮箱资源或邮箱
  验证码二次验证。
- 对象存储、Push、IPInfo 在本地测试走 `external-mock`，不访问线上 B2、FCM、
  APNs。
- API、PG、Redis、external-mock 和性能压测保持 Compose-first；测试栈 PG/Redis
  不映射宿主端口，Redis 只启动一个实例供 session/pubsub/cache 共用。
- Superpowers 不作为当前 active 工作流；当前以根目录 `AGENTS.md` 的
  `agent-light-workflow` 轻量五阶段与 CE 兼容映射为准。

## 当前立即队列

- [x] `IM2-R1.0` 双 iOS Patrol 可靠编排（历史 Flutter 交付物，已下线）
  - 单一脚本生成 marker、校验两个不同 Simulator、分配独立端口并隔离 A/B 构建产物。
  - 验证两端实际账号、角色和消息前缀，覆盖超时、失败清理、日志与 xcresult 留存。
  - 曾提供 `make app.test.patrol.dual` 入口并纳入 `make app.test.scripts` 契约测试；
    相关 Makefile 目标已随 Flutter 下线移除。
  - 2026-08-03 连续两轮真实运行通过，marker、A/B 构建身份、日志和 `xcresult` 均独立留存。
- [x] `IM2-U8` Flutter 移动 P0 设备验收收口（历史 Flutter 交付物，2026-08-04 已 DONE）
  - 已通过 iOS integration/auth/API contract、Patrol 登录、双 iOS 私聊/群聊实时互发，以及 iOS/Android 跨端私聊、双向已读和 Android 前后台离线恢复。
  - R1.1 已通过长 composer、焦点优先返回、上下安全区几何门禁、动态横竖屏缩放、Simulator 最高系统字号和 Reduced Motion；最高字号暴露的登录页 182px 横向 overflow 已修复。真实软键盘与系统横屏截图仍按人工清单 PENDING。
  - R1.2 已建立统一权限裁决并通过 iOS 相册/麦克风永久拒绝降级 Patrol；首次弹窗、设置恢复、通知和真机采集仍按清单 PENDING/SKIPPED。
  - R1.3 已通过双 iOS 私聊双向已读、群聊已读/未读成员详情、联系人备注/删除/重新申请、真实 UI 建群、群消息双向实时互发、个人禁言/解禁、全体禁言/恢复、成员移除实时退页、管理员任命后对端权限实时刷新、前后台重连、API/WebSocket 网络路径中断恢复、离线文本消息恢复，以及图片、文件、语音附件签名、直传、commit、广播和对端下载；接收端语音播放器启动已验证，图片/文件/语音失败重试、重启恢复和本地文件丢失已由单测覆盖。待补系统 PHPicker、系统文件选择器、真实麦克风采集和系统 Wi-Fi/蜂窝切换人工验收。
  - 真实账号 P0 页面导航、反馈长页滚动、上下安全区、最高系统字号与 Reduced Motion 已在 iPhone 17 Pro Simulator 通过；待补系统键盘、真实横屏截图和权限首次拒绝/恢复等系统级人工项。
  - Simulator 无法证明的相机/麦克风质量、APNs 和后台通知只记录真机 SKIPPED/PASS，不伪造结果。
  - 验收记录：`docs/reviews/2026-08-02-im-2-0-u8-device-acceptance-review.md`。
- [x] `IM2-U9` H5 P0 parity（2026-08-04 已 DONE）
  - 已按已有/缺失/漂移/平台不适用建立矩阵并关闭 38 个 P0 路由；H5 check/unit/E2E
    与 Flutter/H5 互操作通过（历史 Flutter 基线）。
  - 验收记录：`docs/reviews/2026-08-04-im-2-0-u9-h5-parity-audit.md`。
- [ ] `IM2-U10` E2EE 发布门禁
  - 唯一执行入口：`docs/plans/2026-08-06-u10-e2ee-g4-remediation-closure-plan.md`。
    N1-N7、应用主链、三端互解、恢复/rekey、跨端附件和泄漏扫描的历史验收已完成，
    U7 P0-1 已关闭；G4 最终全量门禁重放仍待执行。
  - G1 既有隔离候选演练有效，但 G4.1 重新打开恢复实例真实客户端行为、外部
    副作用清理与持久证据缺口；U7 P0-2 暂不维持关闭。
  - G2 六端 SBOM、漏洞与许可证门禁有效，但需补严格日历日期校验和真实
    `Build Release Artifacts` workflow 运行证据；严格日期校验已由 `10f0f724`
    关闭，U7 P0-3 仍待真实 workflow 证据。
  - G3.1 已完成 H5 production-mode 候选构建、16 个 release 正负场景、严格 CSP、
    source/lock/resource 绑定、真实本地响应头检查及 GitHub OIDC provenance 配置。
  - G3.2/G3.3 的真实 Caddy/响应头/WebCrypto 能力证据有效，但 G4.1 重新打开
    production `E2eeSecureStateStorage` Chrome 集成、幂等 cleanup 和持久证据缺口；
    U7 P0-4 暂不维持关闭。
  - 当前执行顺序固定为 `U1 -> U2 -> U3 -> U4 -> U5 -> U6 -> U7 -> U8 -> U9`；
    四视角重审 P0/P1 清零前禁止进入全量重放，最终裁决前保持 No-Go。
  - 未关闭时阻断 2.0 发布。
- [ ] `IM2-U11` P1 可选纵向切片
  - 朋友圈、扫一扫、附近的人、音视频通话、游戏均需独立子计划；当前均未批准为核心首发必需。
- [x] `IM2-U12` Flutter 桌面 P0（历史归档）
  - Flutter 客户端主线已废弃；`desktop/` 仅保留为历史实现参考，不再作为 2.0
    桌面端主线规划。
- [ ] `IM2-U13` 多平台发布切换
  - 原生双端功能迁移、U10 和获批首发 P1 关闭后，完成 Android/iOS 构建矩阵、
    签名凭据、checksum、来源追踪、升级与回滚。

## 历史已完成与暂停队列

- [x] `FLUTTER-P0-01` Flutter 首版 API 合同联调收口
  - 已新增 Flutter contract integration 入口。
  - 已完成 Flutter REST path 与 `api/src/routes.rs` 机械化对照：85/85 闭合。
  - 曾提供可复跑入口 `make app.test.api-paths`（已随 Flutter 下线移除）。
  - 已通过 Pixel 8 Pro 真实 API auth、network、contract 联调。
  - 验收报告：`docs/reports/flutter-first-release-readiness-2026-07-23.md`。
- [x] `CROSS-P1-01` H5/API/Android 联调脚本扩展
  - `make android-app.test.interop` 已自动启动并等待 Compose API dev 栈。
  - 已串联 H5 live smoke、Android live smoke 与 Android 本地能力定向测试。
  - 已覆盖认证、联系人、好友、建群、文本、富媒体、头像缓存、权限恢复状态机和
    语音播放状态机。
  - 实现与证据随 `android-app` 基座恢复保留，作为原生功能迁移输入。
- [x] `ANDROID-P1-01` 聊天扩展
  - 内置 emoji、表情包列表、表情资源缓存、贴纸发送、聊天背景、聊天设置。
  - 已通过 unit/connected/lint/build/Pixel 8 Pro smoke/live/interop/coverage 验证。
- [ ] `ANDROID-P1-02` 设置、账号和配置（随原生功能迁移专项承接）
  - 个人资料、昵称更新、头像上传入口、账号安全、修改密码、协议文档、关于、
    反馈、配置、版本检查。

## H5 历史基线

- [x] H5 全量验收与文档收口。
- [x] 浏览器 E2E / smoke 扩展。
- [x] 本地消息搜索页面。
- [x] 头像上传浏览器能力。
- [x] 浏览器存储增强。
- [x] H5 parity Unit 8 最终勾选。

以上是 1.x/既有 parity 基线，不代表已满足 2.0 原生双端 P0。当前剩余项统一由
原生功能迁移专项与 `IM2-U10` 管理。

## Android / iOS 原生模块

状态：已恢复为 2.0 客户端主线（2026-08-04，`2026-08-04-005`）。`android-app`
（Kotlin/Compose，minSdk 24，JDK 21）与 `ios-app`（Swift/SwiftUI，iOS 15+，
GRDB/SQLite）基座构建与单测通过；功能迁移、E2EE 接入与真机/APNs 补验由后续原生
专项承接。历史执行计划（2026-07-02-002、2026-07-03-001、2026-07-04-001、
2026-07-04-002）保留为参考。

## API / 架构剩余任务

- [ ] `ARCH-P2-01` 性能矩阵扩展
  - `BCRYPT_COST=12` auth 指标、account limit settings 缓存、注册/登录存在性检查
    优化、WS 100/500/1000 订阅者、多房间广播、慢客户端和满队列行为。
- [ ] `ARCH-P2-02` broker/event bus 抽象
  - 保留 Redis PubSub 实现。
  - 分布式 profile 引入 NATS Core。
  - 需要持久化、重放、消费者 ack 时再引入 NATS JetStream。
  - Kafka 暂不作为 IM 实时消息主链路。
- [ ] `API-SEC-P2-01` 表情下载 URL 授权补齐
  - `/emoji-packs/download-url` 校验 object key 是否属于当前用户已拥有或可访问的表情包。
  - 拒绝仅满足 `emoji-items/` / `emoji-packs/` 前缀但无授权关系的 key。
- [ ] `ARCH-P2-03` Compose-first 环境扩展
  - 新增中间件同步 dev/test/perf profile。
  - 测试栈 PG/Redis/external-mock 不映射宿主端口。
  - Redis 测试栈保持一个实例，session/pubsub/cache 三个通道指向同一 Redis。
  - Compose 资源限制用于固定测试指标。
- [ ] `ARCH-P2-04` 最终性能报告
  - 原生双端/H5/API 主链路验收后，重跑 release small/standard/large。

## 真机补验

Android 真机待补验：
- [ ] 相机拍摄图片/视频。
- [ ] 麦克风录音质量、权限、后台中断。
- [ ] 厂商 ROM 文件选择器差异。
- [ ] FCM 真实 token 获取。
- [ ] 云端 Push 投递。
- [ ] 前台/后台/冷启动通知导航。
- [ ] 厂商 ROM 后台限制。
- [ ] Play 签名、release 包安装和发布链路。

iOS 真机待补验由 `ios-app` 原生专项承接（真机 APNs/麦克风/相机等 Simulator 无法
验证项），入口见 `make ios-app.smoke.device` / `make ios-app.apns.preflight.local`。

## 横向回归和发布准备

- [ ] `RELEASE-P3-01` 全模块回归
  - `make api.test`
  - `make android-app.test.unit`
  - `make ios-app.test`
  - `make h5-app.check`
  - `make h5-app.test.unit`
  - `make h5-app.test.live`
  - `make h5-app.test.e2e`
  - `cd admin && bun run type:check`
  - `cd desktop && bun run test`
  - `cd website && bun run test`
- [x] `RELEASE-P3-02` 原生切换条件
  - 原生双端已于 2026-08-04 恢复为主线；该条目历史条件已不再适用，随 Flutter
    主线废弃归档。
- [ ] `RELEASE-P3-03` 发布与回滚文档
  - H5 联调基线、API 兼容边界、缓存清理和回滚步骤、Push/对象存储/消息总线
    回滚开关。

## 执行规则

- 每个功能切片完成后更新对应模块文档和剩余任务总账。
- 行为变更必须补单测、integration、smoke 或明确记录不可自动化原因。
- 真机项只记录 SKIPPED，不伪造通过。
- 每个可独立验收切片通过测试后，按 Conventional Commits 提交并推送。
- 只 stage 本轮相关文件，避免混入用户或历史无关改动。
- API、PG、Redis、external-mock、性能压测全部保持 Compose-first。
