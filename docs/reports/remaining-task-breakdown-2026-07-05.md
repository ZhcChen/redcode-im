# RedCode IM 剩余任务完整整理

整理时间：2026-07-05

本文档是当前剩余任务的执行级拆解，作为 `docs/reports/task-list.md` 的详细版。执行时以本文档的优先级顺序推进；模块内细节仍以对应模块文档为准。

状态口径：

- `进行中`：本地已有未提交实现或正在验证，不能当作已完成。
- `待执行`：尚未开始当前切片实现。
- `跳过/待补验`：按用户要求或环境限制暂不阻塞主线，但必须保留恢复入口。
- `完成`：测试、文档、提交和推送均已收口。

## 1. 当前总体结论

- 当前主线：`android-app` 原生迁移补齐，优先完成 Emulator 可测能力。
- 当前已完成切片：用户头像缓存 + 群头像缓存 + 权限拒绝和恢复路径。
- 当前下一刀：语音播放基线。
- H5 已是 backend + frontend 联调优先入口，剩余集中在全量验收文档、浏览器 E2E、本地搜索页、头像上传和浏览器存储增强。
- iOS 原生 Flutter parity 已完成主链路；必须 iPhone 真机/APNs 的项已按要求跳过并记录，不阻塞当前主线。
- Flutter `app/` 保留，不移除，作为行为对照和回滚基线。
- API 已有 Compose-first 性能基线；核心架构重构应在 Android/H5/API 主链路稳定后单独推进。
- 当前没有影响本地 H5/API/iOS/Android smoke 的新增外部服务依赖。对象存储、Push、IPInfo 走本地 `external-mock`。
- Android 头像缓存相关实现已通过 unit/lint/build/connected/live/interop 验证。
- Android 权限拒绝和恢复路径已通过 unit/connected/lint/build/emulator smoke 验证。

## 2. 当前工作区快照

分支：`feat/core-architecture-performance`

最近已提交：

- `bfef9d51 docs(project): 完整整理剩余任务`
- `11ce2f25 feat(android-app): 支持附件本地文件缓存`

本轮待提交主线改动：

- Android 领域模型、DTO、Room schema 与 mapping 已补齐 `avatarObjectKey`。
- Android 新增 avatar download URL、remote data source、cache repository、Compose 缓存头像组件和相关 JVM 单测。
- Android Chat list、Contacts、Groups、Settings UI 已接入缓存头像组件。
- 已完成验证：`make android-app.test.unit`、`make android-app.lint`、`make android-app.build.debug`、`make android-app.connected-test`、`make android-app.smoke.emulator`、`make android-app.test.live`、`make android-app.test.interop`、`git diff --check`。

恢复执行第一条命令：

```bash
git status --short --branch
```

## 3. 执行顺序

按下面顺序推进，不再并行展开无关大项：

1. `ANDROID-P0`：头像缓存、权限拒绝恢复已完成，继续推进语音播放基线。
2. `H5-P1`：H5 全量验收与浏览器 E2E 收口。
3. `INTEROP-P1`：H5/API/Android 联调扩展和回归稳定。
4. `ANDROID-P1`：聊天扩展、设置账号、配置版本。
5. `ANDROID-P2`：通知/Push mock 可测部分、底座协议补齐。
6. `ARCH-P2`：API 性能矩阵扩展、broker 抽象、NATS 方案、Compose profile。
7. `RELEASE-P3`：全模块回归、切换条件、回滚文档。
8. `DEVICE-SKIP`：Android 真机、iPhone/APNs、Play/App Store 等真实设备/平台补验，后续有设备和凭据后恢复。

## 4. P0：Android 原生迁移当前切片

目标：完成 `ANDROID-06` 中不依赖 Android 真机的媒体、缓存、权限和语音播放能力。

### ANDROID-P0-01 用户头像缓存

状态：完成（待本轮提交推送）

任务：
- 接入 `GET /users/me/avatar/url` 和 `GET /users/{user_id}/avatar/url`。
- DTO/model 补齐 `avatar_object_key` 映射，包括当前用户、联系人、房间成员、会话摘要中私聊好友头像字段。
- 复用 `FileResourceCache` 建立 avatar cache，不新造重复缓存底座。
- UI 优先展示缓存头像；缓存失败或无 object key 时降级为姓名首字母/占位头像。
- 登出或清理本地状态时清理用户头像缓存。

当前结果：
- 已新增 `AvatarCacheRepository`、`HttpAvatarRemoteDataSource`、`CachedAvatarBadge`、`MIGRATION_5_6`。
- 已补 DTO/model/Room mapping 和 `AvatarCacheRepositoryTest`。
- 当前用户、联系人、房间成员、会话摘要均保留 `avatarObjectKey`；UI 无缓存或失败时降级首字母占位。
- 登出/清理本地状态会清理头像 cache。

验收：
- JVM 单测覆盖缓存命中不重复请求、下载失败不污染缓存、object key 变化重新下载、clear 清理。
- DTO mapping 单测覆盖 user/contact/member/chat summary 头像字段。
- `make android-app.test.unit`
- `make android-app.lint`
- `make android-app.build.debug`
- `make android-app.connected-test`
- `git diff --check`

验证结果：以上命令均已通过。

### ANDROID-P0-02 群头像缓存

状态：完成（待本轮提交推送）

任务：
- 接入 `GET /rooms/{room_id}/avatar/url`。
- DTO/model 补齐 `RoomInfo.avatarObjectKey`、会话摘要群头像 object key。
- 群列表、群详情、聊天列表群会话展示缓存头像。
- 与用户头像共用缓存策略和清理入口。

当前结果：
- 已在 `RoomInfo`、`RoomMember`、`ChatSummary`、Room cache 表和群管理 UI 中传递 `avatarObjectKey`。
- 群列表、群详情、聊天列表群会话可通过共用头像缓存策略展示本地缓存头像。
- 群头像下载、命中、失败降级和清理已由 `AvatarCacheRepositoryTest` 覆盖。

验收：
- 单测覆盖群头像下载、命中、失败降级、清理。
- H5/API/Android interop 不回归。
- `make android-app.test.live`
- `make android-app.test.interop`

验证结果：以上命令均已通过。

### ANDROID-P0-03 权限拒绝和恢复路径

状态：完成（待本轮提交推送）

任务：
- 文件选择器取消选择不报错、不污染 draft。
- 通知权限拒绝时显示可恢复提示。
- 麦克风权限拒绝时显示可恢复提示。
- 二次拒绝或系统不再询问时引导打开系统设置。
- 真机差异不在 Emulator 阶段伪造通过，只记录 SKIPPED。

当前结果：
- 文件选择器取消选择会显式回到 ViewModel，不报错、不清空 draft、不进入上传态。
- 麦克风和通知权限拒绝后显示可恢复提示；首次可恢复拒绝提供“重新授权”，二次拒绝或系统不再询问提供“打开设置”。
- 真实硬件/ROM 权限差异仍按真机补验清单跳过，不在 Emulator 阶段伪造通过。

验收：
- ViewModel/permission state 单测覆盖 allow/deny/permanently denied。
- Compose UI test 覆盖拒绝提示入口。
- 真机项写入跳过清单。

验证结果：`make android-app.test.unit`、`make android-app.connected-test`、`make android-app.lint`、`make android-app.build.debug`、`make android-app.smoke.emulator`、`git diff --check` 均已通过。

### ANDROID-P0-04 语音播放基线

状态：待执行

任务：
- 已上传 audio part 增加播放入口。
- 实现播放、暂停、加载中、播放失败状态。
- 不依赖麦克风录音，在 Emulator 用已有 audio attachment 验证播放链路。
- 语音录制和硬件音频质量留到真机补验。

验收：
- 单测覆盖播放状态机。
- Emulator smoke 能打开包含 audio part 的消息并触发播放/暂停路径。

## 5. P1：Android 原生后续 parity

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
- ViewModel/Repository/DTO 单测。
- Compose UI 回归。
- `make android-app.test.unit`
- `make android-app.connected-test`

### ANDROID-P1-02 设置、账号和配置

状态：待执行

任务：
- 个人资料页和昵称更新。
- 头像上传入口；可先复用 P0 头像缓存展示，再接上传。
- 账号安全和修改密码。
- 用户协议、隐私政策、关于页完善。
- 反馈提交。
- App 配置拉取与缓存。
- 版本检查和更新提示。
- 当前主线不启用邮箱验证码二次验证；普通账号密码注册/登录为默认流程。

验收：
- 设置域单测覆盖成功/失败/缓存回退。
- 与 H5/API 的资料和配置字段保持一致。

### ANDROID-P1-03 H5/API/Android 联调脚本扩展

状态：待执行

任务：
- 扩展 `android-app.test.interop` 覆盖头像缓存、权限降级、语音播放可测入口。
- 串联认证、联系人、群、文本、富媒体、设置关键路径。
- 保持 API、PG、Redis、external-mock 全部由 Docker Compose 创建。

验收：
- `make api.up`
- `make api.wait`
- `make android-app.test.interop`
- 失败时能定位到 H5 live、Android live 或 API 容器日志。

## 6. P1：H5 联调入口收口

### H5-P1-01 全量验收与文档收口

状态：待执行

任务：
- 完成 `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md` 的 Unit 8。
- `h5-app/README.md` 明确 H5 是 backend + frontend 联调优先入口。
- `docs/reference/testing/README.md` 补齐 H5 从零启动到验收流程。
- Makefile 入口保持 `h5-app.check`、`h5-app.test.unit`、`h5-app.test.live` 可用。

验收：
- `make h5-app.check`
- `make h5-app.test.unit`
- `make api.up && make api.wait && make h5-app.test.live`

### H5-P1-02 浏览器 E2E / smoke 扩展

状态：待执行

任务：
- 注册登录后进入聊天 tab。
- 创建或进入房间，发送消息。
- 刷新页面后从本地缓存恢复。
- 好友申请闭环。
- 群设置关键路径。
- 使用固定 H5 端口 `8016`，API 端口 `8010`。

验收：
- 新增 `h5-app/test/e2e/` 或等价 Playwright/Vitest browser 入口。
- 截图或稳定断言能证明关键页面可操作。

### H5-P1-03 本地消息搜索页面

状态：待执行

任务：
- 基于已有本地搜索存储测试补 UI 页面。
- 支持关键词搜索、room 过滤、结果跳转到聊天详情。
- FTS5 不可用时明确 fallback 到 LIKE 或服务端搜索。

验收：
- 单测覆盖本地索引和页面状态。
- 浏览器 smoke 覆盖搜索跳转。

### H5-P1-04 头像上传浏览器能力

状态：待执行

任务：
- 浏览器文件选择头像。
- direct upload / commit / avatar cache 串联。
- 上传失败时保留旧头像。
- 成功后刷新当前用户和会话/联系人头像展示。

验收：
- service 单测覆盖上传成功/失败。
- H5 live smoke 可上传到 `external-mock`，不访问线上 B2。

### H5-P2-01 浏览器存储增强

状态：待执行

任务：
- wa-sqlite OPFS worker 化，IndexedDB VFS 作为 fallback。
- 运行时探测 FTS5 能力。
- 附件/头像/表情 Cache API 配额、过期和清理策略文档化。

验收：
- 构建不破坏 Vite 8。
- 旧浏览器 fallback 不白屏。

## 7. P2：Android 通知、Push 和底座协议

### ANDROID-P2-01 通知和 Push mock 可测部分

状态：待执行

任务：
- Android 13+ `POST_NOTIFICATIONS` 权限请求。
- 本地通知 channel 管理和展示。
- 点击通知进入对应 room。
- FCM token 注册流程用 mock 覆盖。
- 登出清理通知、本地 token 绑定和 pending navigation。

验收：
- Emulator 可测路径用单测/instrumented test 覆盖。
- 真实 FCM token、云端投递、厂商后台限制不伪造，通过真机补验项记录。

### ANDROID-P2-02 HTTP client 与统一错误模型

状态：待执行

任务：
- 在现有 `NetworkFailure` 基线上补齐错误码分类。
- 增加重试建议、用户可读错误映射。
- 保持 auth/chat/contacts/rooms/media/settings 使用同一错误模型。

验收：
- 合同测试覆盖后端 `{error}` / `{message}` / HTTP status。
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

### ANDROID-P2-04 DataStore 与 live smoke 分层

状态：待执行

任务：
- DataStore 承接聊天设置、通知设置、外观设置。
- `android-app.test.live` 拆分为 auth/chat/friend/room/media/settings 子集，便于定位失败。
- 登出清理文件 cache、通知态、DataStore 中用户相关偏好。

验收：
- 单测覆盖每类偏好读写和清理。
- Makefile 或 Gradle 参数可单独跑子集。

### ANDROID-P2-05 重置密码策略

状态：待执行

任务：
- 当前无邮箱资源，测试主线不启用邮箱验证码。
- 后续按普通账号安全策略决定是否保留重置密码入口。
- 若保留，走后台配置或通用验证码策略，不能依赖真实邮箱。

验收：
- 文档明确当前是否展示入口。
- 自动化测试不依赖真实邮箱。

## 8. P2：API 性能与核心架构重构

### ARCH-P2-01 性能矩阵扩展

状态：待执行

任务：
- auth 链路增加生产成本 `BCRYPT_COST=12` 指标。
- account limit settings 缓存。
- 用户名/邮箱存在性检查合并，或改为依赖唯一索引冲突处理。
- WebSocket 广播扩展到 100 / 500 / 1000 订阅者。
- 多房间并发广播。
- 慢客户端和 `WS_OUTBOUND_QUEUE_SIZE` 满队列行为。

验收：
- 新报告记录 API/PG/Redis CPU、内存、PG pool、bcrypt cost、metrics 参数、WS 队列大小。
- 性能入口仍使用 Docker Compose 资源限制。

### ARCH-P2-02 broker/event bus 抽象

状态：待执行

任务：
- 先抽象 broker/event bus 层，当前 Redis PubSub 作为一个实现。
- 单机默认保持轻量：PG + Redis + API + external-mock。
- 分布式 profile 增加 NATS Core，用于低延迟实时 fanout。
- 需要持久化、重放、消费者 ack 的异步任务再引入 NATS JetStream。
- Kafka 暂不作为 IM 实时消息主链路；仅在需要审计事件流、超大规模日志分析、跨系统数据管道时再评估。

验收：
- 单机和分布式部署都能通过配置切换。
- Redis PubSub 实现保留可回滚。
- 分布式 profile 的 API 多副本 smoke 能证明跨节点 fanout。

### ARCH-P2-03 Compose-first 环境扩展

状态：待执行

任务：
- 新增中间件时同步 dev/test/perf compose profile。
- 所有数据库、中间件、API 启动、测试和压测由 Docker Compose 创建。
- PG/Redis 测试栈不映射宿主端口。
- Docker Compose 资源限制用于固定测试指标。

验收：
- `api/docker/dev/docker-compose.yml`
- `api/docker/release/docker-compose.yml`
- `tests/docker-compose.test.yml`
- perf 入口均同步更新并记录资源限制。

## 9. P2：iOS 真机/APNs 补验

状态：跳过，待设备和 Apple 平台凭据恢复。

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
- 本项不阻塞当前 H5/API/iOS Simulator/Android Emulator 主线。
- 不把 Simulator/mock 验收描述为真实 APNs 已通过。

## 10. P2：Android 真机补验

状态：跳过，待 Android 真机和发布凭据恢复。

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
- Emulator 阶段只做可模拟的权限和本地通知状态机。
- 真机行为不伪造通过。

## 11. P3：横向回归和发布准备

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
- 若某模块未改动，可记录跳过原因，但发布前仍需完整回归。

### RELEASE-P3-02 Flutter 保留和原生切换条件

状态：待执行

任务：
- Flutter `app/` 不移除。
- Android 原生切换条件：Android P0/P1 完成、interop 通过、真机必要项按发布要求补验或明确豁免。
- iOS 原生切换条件：当前主链路已完成；若正式上架需要 APNs/真机补验恢复执行。
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

## 12. 非当前主线但应保留的长期事项

- 端到端加密设计已在文档中存在，尚未进入当前实现主线；需独立计划和威胁模型复核后再执行。
- Admin 当前不是 P0，保留 route smoke、真实后端 smoke 和 RBAC 回归入口。
- Desktop / Website 当前不是 P0，保留单测、真实后端 smoke 和下载逻辑测试。
- 生产安全加固：H5 token 后续可评估 httpOnly SameSite Cookie 或短生命周期 token 策略。
- 历史 `docs/plans/2026-03-*` 中仍有未勾选项，但不自动纳入当前主线；只有用户重新激活对应计划时再复核并迁移到本文档。

## 13. 每个切片的通用完成标准

- 只改当前切片相关文件。
- 更新对应模块文档和本总清单。
- 行为变更必须补单测或 smoke；不能测试的真机项记录 SKIPPED。
- 执行对应模块验证命令和 `git diff --check`。
- 通过后使用 Conventional Commits 提交并推送。
- API、PG、Redis、external-mock、性能压测保持 Docker Compose-first。

## 14. 主要依据文档

- `docs/reports/task-list.md`
- `android-app/docs/remaining-migration-tasks.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/plans/2026-07-04-002-feat-android-app-native-migration-plan.md`
- `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- `ios-app/docs/full-migration-task-tree.md`
- `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- `docs/reports/performance/api-compose-baseline-2026-07-01.md`
- `docs/reference/testing/README.md`
