# RedCode IM 剩余任务总账

整理时间：2026-07-05

本文档是当前仓库剩余任务的本地执行总账，作为 `docs/reports/task-list.md` 的详细版。执行时以本文档的优先级顺序推进；模块内更细任务仍以对应模块文档为准。

状态口径：

- `待收口`：本地已有实现或文档改动，但还没有完成最终验证、提交和推送。
- `待执行`：尚未开始当前切片实现。
- `跳过/待补验`：按用户要求或环境限制暂不阻塞主线，但必须保留恢复入口。
- `完成`：实现、测试、文档、提交和推送均已收口。

## 1. 当前结论

- 当前分支：`feat/core-architecture-performance`。
- 当前主线：Android P0 媒体切片已收口，下一步切到 H5 全量验收与浏览器 E2E。
- Flutter `app/` 保留，不移除，继续作为行为对照和回滚基线。
- H5 是后续 backend + frontend 联调优先入口，剩余工作集中在验收入口、浏览器 E2E、本地搜索页、头像上传和浏览器存储增强。
- iOS 原生主链路已完成 Flutter parity；必须依赖 iPhone 真机和 Apple APNs 凭据的项已按要求跳过并记录。
- Android 原生已完成认证、聊天、联系人、群、富媒体、附件缓存、头像缓存、权限恢复和语音播放基线；剩余是聊天扩展、设置账号、通知 Push mock、底座补齐、全量对照和真机补验。
- API 已有 Compose-first 测试和性能基线；分布式消息总线、性能矩阵扩展和 Compose profile 需要作为独立架构重构推进。
- Google / Apple 登录不再进入当前主线；当前测试默认普通账号密码注册/登录。邮箱注册/登录作为后台配置能力保留，测试阶段不依赖真实邮箱或验证码二次验证。
- 本地对象存储、Push、IPInfo 继续走 `external-mock`，禁止为了测试访问线上 B2、FCM、APNs。

## 2. 当前立即任务

### NOW-01 Android 语音播放切片收口

状态：完成

背景：
- 已新增 `AudioPlayback.kt`、`AudioPlaybackUiTest.kt`，并接入 `ChatDetailViewModel`、`RedCodeApp`、`ChatViewModelTest` 和相关文档。
- 已完成播放、暂停、加载中、失败状态；离开聊天详情时释放播放器。
- 已修复播放器初始化失败时旧 `MediaPlayer` 引用未清空的问题。

验证：
- `make android-app.test.unit`
- `make android-app.connected-test`
- `make android-app.lint`
- `make android-app.build.debug`
- `make android-app.smoke.emulator`
- `git diff --check`

完成标准：
- Android 当前 P0 媒体切片全部完成并已推送。
- `docs/reports/task-list.md`、`android-app/docs/remaining-migration-tasks.md`、`android-app/docs/full-migration-task-tree.md` 与实际状态一致。

### NOW-02 切换到 H5 全量验收

状态：待执行

任务：
- 启动 Compose API：`make api.up && make api.wait`。
- 先跑 H5 当前质量门禁：`make h5-app.check`、`make h5-app.test.unit`、`make h5-app.test.live`。
- 根据失败点决定先修测试框架、文档入口还是功能缺口。

完成标准：
- H5 可以作为 backend + frontend 联调基准端。
- H5 live smoke 失败时能定位到 API 容器、H5 service/store 或浏览器端缓存问题。

## 3. P1：H5 联调入口收口

目标：让 `h5-app` 成为后续 API、Android、iOS 功能联调的浏览器基准端。

### H5-P1-01 全量验收与文档收口

状态：完成

任务：
- 已完成 `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md` Unit 8 中的文档和 live smoke 入口收口；浏览器 E2E、搜索跳转和头像上传继续由 H5-P1-02/H5-P1-03/H5-P1-04 执行。
- `h5-app/README.md` 已明确 H5 是 Flutter App 的 Web parity 模块和联调优先入口。
- `docs/reference/testing/README.md` 已补齐 H5 从零启动、API 依赖、端口、环境变量和验收命令。
- 已检查 Makefile 入口：`h5-app.check`、`h5-app.test.unit`、`h5-app.test.live`、`h5-app.up`、`h5-app.wait`。
- H5 端口固定 `8016`，API 端口固定 `8010`。

验收：
- `make h5-app.check`
- `make h5-app.test.unit`
- `make api.up`
- `make api.wait`
- `make h5-app.test.live`

### H5-P1-02 浏览器 E2E / smoke 扩展

状态：待执行

任务：
- 新增 `h5-app/test/e2e/` 或等价浏览器测试入口。
- 覆盖普通账号注册/登录后进入聊天 tab。
- 创建或进入房间，发送文本消息。
- 刷新页面后从本地缓存恢复聊天列表和消息。
- 好友申请闭环：搜索用户、发送申请、接受、打开私聊。
- 群设置关键路径：建群、成员、改名、置顶、免打扰、退出/解散可测部分。
- 截图或稳定 DOM 断言证明关键页面可操作。

验收：
- 浏览器 E2E 可在本机 API + H5 dev server 下稳定运行。
- 失败日志能区分 API、WebSocket、本地 SQLite/Cache API 和页面状态问题。

### H5-P1-03 本地消息搜索页面

状态：待执行

任务：
- 基于已有 `MessageSearchStorage` 和测试补 UI 页面。
- 支持关键词搜索、room 过滤、消息类型过滤和结果分页。
- 点击搜索结果跳转到对应聊天详情。
- 运行时探测 FTS5；不可用时明确 fallback 到 LIKE 或服务端搜索。
- 搜索索引损坏时可重建，不导致 H5 白屏。

验收：
- 单测覆盖索引写入、查询、fallback 和损坏记录隔离。
- 浏览器 smoke 覆盖搜索结果跳转。

### H5-P1-04 头像上传浏览器能力

状态：待执行

任务：
- 用户头像浏览器文件选择。
- 群头像浏览器文件选择。
- 复用 direct upload / commit / avatar cache 链路。
- 上传失败时保留旧头像和旧 session 展示。
- 成功后刷新当前用户、联系人、会话摘要、群资料和头像缓存。

验收：
- service/store 单测覆盖上传成功、上传失败、commit 失败、缓存刷新。
- H5 live smoke 使用 `external-mock` 完成头像上传，不访问线上 B2。

### H5-P1-05 浏览器存储增强

状态：待执行

任务：
- wa-sqlite OPFS worker 化，IndexedDB VFS 作为 fallback。
- 增加运行时能力探测：OPFS、IndexedDB、FTS5、Cache API。
- 附件、头像、表情 Cache API 配额、过期和清理策略文档化。
- 旧浏览器降级时保证登录、聊天和基础缓存不白屏。

验收：
- `make h5-app.build` 不被 WASM/worker 打包破坏。
- 单测覆盖 fallback 选择和清理策略。

## 4. P1：H5/API/Android 联调扩展

### INTEROP-P1-01 H5/API/Android 主链路扩展

状态：待执行

任务：
- 扩展 `make android-app.test.interop`，串联 H5 live smoke 与 Android live smoke。
- 覆盖普通账号注册/登录、联系人、好友申请、建群、文本消息、富媒体附件、头像缓存、权限降级可测入口、语音播放可测入口。
- API、PG、Redis、external-mock 全部由 Docker Compose 创建。
- 失败时自动提示可查看的 API 容器日志、H5 live 日志和 Android Gradle 测试报告路径。

验收：
```bash
make api.up
make api.wait
make h5-app.test.live
make android-app.test.interop
```

### INTEROP-P1-02 H5/API/iOS 回归保持

状态：待执行

任务：
- 保持 `make ios-app.test.interop` 可用。
- H5 变更后必须确认 iOS live smoke 不被破坏。
- iOS 真机/APNs 不作为当前主线阻塞项。

验收：
```bash
make api.up
make api.wait
make ios-app.test.interop
```

## 5. P1：Android 原生后续 parity

目标：补齐 Android 原生替代 Flutter Android 的剩余可测能力。

### ANDROID-P1-01 聊天扩展

状态：待执行

任务：
- 内置 emoji 面板，支持插入 draft。
- 表情包列表和表情项加载。
- 表情资源缓存，复用文件缓存底座。
- 贴纸发送，优先复用图片附件链路。
- 聊天背景，按 room 保存本地偏好。
- 聊天设置：字体大小、回车发送、媒体自动下载等。

验收：
- ViewModel、Repository、DTO、cache 单测。
- Compose UI test 覆盖输入区、表情入口、贴纸发送可测路径。
- `make android-app.test.unit`
- `make android-app.connected-test`

### ANDROID-P1-02 设置、账号和配置

状态：待执行

任务：
- 个人资料页和昵称更新。
- 头像上传入口；复用 P0 头像缓存展示。
- 账号安全和修改密码。
- 用户协议、隐私政策、关于页完善。
- 反馈提交。
- App 配置拉取与缓存。
- 版本检查和更新提示。
- 当前默认普通账号密码注册/登录；邮箱注册/登录只做后台配置能力，不依赖真实邮箱资源。

验收：
- 设置域单测覆盖成功、失败、缓存回退和登出清理。
- 与 H5/API 的资料、配置、版本字段保持一致。

### ANDROID-P1-03 全量对照和覆盖率提升

状态：待执行

任务：
- 逐项比对 Flutter `app/` 与 Android 原生已实现能力。
- 生成 Android 已完成、部分完成、跳过、缺失清单。
- 覆盖率继续提升，优先 ViewModel、Repository、DTO mapping、Room cache、DataStore、文件缓存。
- Emulator smoke 增加聊天、联系人、群、设置关键页面截图或 UI test。
- 明确 Flutter Android 下线条件和回滚策略。

验收：
- `make android-app.coverage`
- `make android-app.smoke.emulator`
- `android-app/docs/remaining-migration-tasks.md` 更新到发布切换口径。

## 6. P2：Android 通知、Push 和底座协议

### ANDROID-P2-01 通知和 Push mock 可测部分

状态：待执行

任务：
- Android 13+ `POST_NOTIFICATIONS` 权限请求。
- 本地通知 channel 管理和展示。
- 点击通知进入对应 room。
- FCM token 注册流程用 mock 覆盖。
- 登出清理通知、本地 token 绑定和 pending navigation。

验收：
- Emulator 可测路径用单测或 instrumented test 覆盖。
- 真实 FCM token、云端投递、厂商后台限制不伪造，通过真机补验清单记录。

### ANDROID-P2-02 HTTP client 与统一错误模型

状态：待执行

任务：
- 在现有 `NetworkFailure` 基线上补齐错误码分类。
- 增加重试建议、用户可读错误映射。
- 保持 auth、chat、contacts、rooms、media、settings 使用同一错误模型。

验收：
- 合同测试覆盖后端 `{error}`、`{message}`、HTTP status。
- UI 错误展示不泄漏内部栈。

### ANDROID-P2-03 WebSocket protobuf 二进制帧

状态：待执行

任务：
- 确认后端二进制帧协议和兼容策略。
- Android 保留 JSON `/ws?format=json` 可回退。
- 新增 protobuf 解码、事件去重、订阅恢复测试。

验收：
- protobuf 和 JSON 两种模式至少各有一组单测。
- H5/API/Android interop 不回归。

### ANDROID-P2-04 DataStore、live smoke 分层和清理

状态：待执行

任务：
- DataStore 承接聊天设置、通知设置、外观设置。
- `android-app.test.live` 拆分 auth/chat/friend/room/media/settings 子集。
- 登出清理文件 cache、通知态、DataStore 中用户相关偏好。
- 重置密码策略重新确认：当前无真实邮箱资源，自动化测试不能依赖真实邮箱。

验收：
- 单测覆盖每类偏好读写和清理。
- Makefile 或 Gradle 参数可单独跑 live smoke 子集。

## 7. P2：API 性能与核心架构重构

### ARCH-P2-01 性能矩阵扩展

状态：待执行

任务：
- auth 链路增加生产成本 `BCRYPT_COST=12` 指标。
- account limit settings 缓存。
- 用户名/邮箱存在性检查合并，或改为依赖唯一索引冲突处理。
- WebSocket 广播扩展到 100 / 500 / 1000 订阅者。
- 多房间并发广播。
- 慢客户端和 `WS_OUTBOUND_QUEUE_SIZE` 满队列行为。
- small / standard / large 三档资源限制重新跑 release 基线。

验收：
- 新报告写入 `docs/reports/performance/`。
- 报告记录 API/PG/Redis CPU、内存、PG pool、bcrypt cost、metrics 参数、WS 队列大小。
- 性能入口仍使用 Docker Compose 资源限制。

### ARCH-P2-02 broker/event bus 抽象

状态：待执行

任务：
- 先抽象 broker/event bus 层，当前 Redis PubSub 作为一个实现。
- 单机默认保持轻量：PG + Redis + API + external-mock。
- 分布式 profile 增加 NATS Core，用于低延迟实时 fanout。
- 需要持久化、重放、消费者 ack 的异步任务再引入 NATS JetStream。
- Kafka 暂不作为 IM 实时消息主链路；仅在后续审计事件流、超大规模日志分析、跨系统数据管道时评估。

验收：
- 单机和分布式部署都能通过配置切换。
- Redis PubSub 实现保留可回滚。
- 分布式 profile 的 API 多副本 smoke 能证明跨节点 fanout。

### ARCH-P2-03 Compose-first 环境扩展

状态：待执行

任务：
- 新增中间件时同步 dev/test/perf compose profile。
- 所有数据库、中间件、API 启动、测试和压测由 Docker Compose 创建。
- 测试栈 PG/Redis/external-mock 不映射宿主端口。
- Redis 测试栈保持一个实例，API 的 session/pubsub/cache 三个通道指向同一 Redis。
- Docker Compose 资源限制用于固定测试指标。

验收：
- `api/docker/dev/docker-compose.yml`
- `api/docker/release/docker-compose.yml`
- `tests/docker-compose.test.yml`
- perf 入口均同步更新并记录资源限制。

## 8. 跳过/待补验：iOS 真机与 APNs

状态：跳过/待补验

任务：
- iPhone 真机签名、安装和启动。
- APNs token 获取。
- Apple APNs 真实离线系统通知。
- 系统通知点击唤醒。
- 冷启动通知深链。

恢复入口：
```bash
IOS_APNS_PROVIDER_CONFIGURED=1 make ios-app.apns.preflight.local
IOS_APNS_PROVIDER_CONFIGURED=1 IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID> make ios-app.smoke.device.local
```

说明：
- 当前不阻塞 H5/API/iOS Simulator/Android Emulator 主线。
- 不把 Simulator/mock 验收描述为真实 APNs 已通过。

## 9. 跳过/待补验：Android 真机和发布平台

状态：跳过/待补验

任务：
- 相机拍摄图片/视频。
- 麦克风录音质量、权限、后台中断。
- 厂商 ROM 文件选择器差异。
- FCM 真实 token 获取。
- 云端 Push 投递。
- 前台/后台/冷启动通知导航。
- 厂商 ROM 后台限制。
- Play 签名、release 包安装和发布链路。

说明：
- Emulator 阶段只做可模拟的权限、本地通知和数据层状态机。
- 真机行为不伪造通过。

## 10. P3：横向回归和发布准备

### RELEASE-P3-01 全模块回归

状态：待执行

命令：
```bash
make api.test
make h5-app.check
make h5-app.test.unit
make h5-app.test.live
make android-app.test.interop
make ios-app.test.interop
cd admin && bun run type:check
cd desktop && bun run test
cd website && bun run test
```

说明：
- `h5-app.test.live`、`android-app.test.interop`、`ios-app.test.interop` 需要本机 Compose API 已启动。
- 若某模块未改动，可记录跳过原因；发布前仍需完整回归。

### RELEASE-P3-02 原生切换条件

状态：待执行

任务：
- Flutter `app/` 不移除。
- Android 原生切换条件：Android P0/P1 完成、interop 通过、真机必要项按发布要求补验或明确豁免。
- iOS 原生切换条件：当前主链路已完成；正式上架如要求 APNs/真机则恢复补验。
- H5 保持 backend + frontend 联调基准端。

### RELEASE-P3-03 发布与回滚文档

状态：待执行

任务：
- 原生 Android 切换步骤。
- 原生 iOS 切换步骤。
- H5 联调基线。
- API 兼容边界。
- 客户端缓存问题的清理和回滚步骤。
- Push、对象存储、消息总线的回滚开关。

## 11. 非当前主线但保留入口

- Admin 当前不是 P0；保留 route smoke、真实后端 smoke 和 RBAC 回归入口。
- Desktop / Website 当前不是 P0；保留单测、真实后端 smoke 和下载逻辑测试。
- 端到端加密设计已有文档，但尚未进入实现主线；需要独立威胁模型和迁移计划。
- 生产安全加固：H5 token 后续可评估 httpOnly SameSite Cookie 或短生命周期 token 策略。
- 历史 `docs/plans/2026-03-*` 中仍有未勾选项，不自动纳入当前主线；只有用户重新激活对应计划时再复核并迁移到本文档。

## 12. 每个切片通用完成标准

- 只改当前切片相关文件。
- 更新对应模块文档和本总账。
- 行为变更必须补单测、integration、smoke 或明确记录不可自动化原因。
- 真机项只记录 SKIPPED，不伪造通过。
- 执行对应模块验证命令和 `git diff --check`。
- 通过后使用 Conventional Commits 提交并推送。
- API、PG、Redis、external-mock、性能压测保持 Docker Compose-first。

## 13. 主要依据文档

- `docs/reports/task-list.md`
- `android-app/docs/remaining-migration-tasks.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/plans/2026-07-04-002-feat-android-app-native-migration-plan.md`
- `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- `ios-app/docs/full-migration-task-tree.md`
- `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- `docs/reports/performance/api-compose-baseline-2026-07-01.md`
- `docs/reference/testing/README.md`
