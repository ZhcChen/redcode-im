# RedCode IM 剩余任务总账

重整时间：2026-07-05

本文档是当前仓库剩余任务的本地执行总账，作为
`docs/reports/task-list.md` 的详细版。执行时以本文档顺序推进；模块内更细
实现细节继续参考对应模块文档。

## 0. 当前口径

- 当前分支：`feat/core-architecture-performance`。
- 当前主线：H5/API/Android 基础联调已收口；接下来收口 Android 原生 parity，
  随后进入全模块回归和 API 核心架构重构。
- 当前立即任务：`ANDROID-P1-01 聊天扩展`。
- `h5-app` 已完成 Flutter parity P1，可作为 backend + frontend 联调优先入口。
- `ios-app` 主链路已完成，后续只剩 iPhone 真机/APNs 补验项。
- `android-app` 已完成 P0 媒体切片；剩余集中在聊天扩展、设置账号配置、通知
  mock、底座协议和最终切换准备。
- Flutter `app/` 保留，不移除；当前只作为行为对照、回滚包和原生迁移基线。
- 当前默认普通账号密码注册/登录；Google / Apple 登录不进入当前主线。
- 邮箱注册/登录作为后台配置能力保留；当前测试不依赖真实邮箱资源，也不要求
  邮箱验证码二次验证。
- 对象存储、Push、IPInfo 在本地测试中继续走 `external-mock`，禁止为了测试
  访问线上 B2、FCM、APNs。
- API、PG、Redis、external-mock、性能压测坚持 Compose-first。
- 测试栈 PG/Redis/external-mock 不映射宿主端口；测试栈只启动一个 Redis，
  `REDIS_SESSION_URL` / `REDIS_PUBSUB_URL` / `REDIS_CACHE_URL` 指向同一 Redis。
- 性能指标必须通过 Docker Compose 资源限制固定测试档位；PG pool 按对应档位的
  最佳值配置。
- Android 真机、iPhone 真机、真实 APNs/FCM/厂商 ROM 行为按用户要求跳过并
  记录，不伪造通过。
- Superpowers 不再作为当前仓库工作流入口；当前 active 工作流以根目录
  `AGENTS.md` 的 Compound Engineering (CE) 为准。

## 1. 状态定义

- `待执行`：尚未开始当前切片实现。
- `进行中`：已有局部实现或分析，但还没有完成测试、文档、提交和推送。
- `待补验`：受真机、平台凭据或外部发布资源限制，暂不阻塞主线，但必须保留
  恢复入口。
- `完成`：实现、测试、文档、提交和推送均已收口。
- `非当前主线`：保留入口，不主动展开，除非用户重新激活。

## 2. 当前完成归档

这些项不再进入剩余任务队列，只作为后续回归和对照依据。

### H5 App

状态：完成

已完成：
- `H5-P1-01` H5 全量验收与文档收口。
- `H5-P1-02` 浏览器 E2E / smoke 扩展。
- `H5-P1-03` 本地消息搜索页面。
- `H5-P1-04` 头像上传浏览器能力。
- `H5-P1-05` 浏览器存储增强：
  - wa-sqlite OPFS worker。
  - wa-sqlite IndexedDB VFS fallback。
  - IndexedDB persisted shim / Memory fallback。
  - OPFS/IndexedDB/FTS5/Cache API/localStorage/Web Worker 能力探测。
  - OPFS worker operation queue 与 transaction 串行化。
  - FTS5 不可用时稳定降级到 LIKE 查询。
  - Blob cache TTL、maxEntries、maxBytes 和 oldest-first cleanup。
  - 新本地消息缓存写入完成后再暴露到 UI，避免刷新恢复竞态。
- `H5-P1-06` H5 parity Unit 8 最终勾选。

当前已验证入口：
- `make h5-app.check`
- `make h5-app.test.unit`
- `make h5-app.build`
- `make h5-app.test.live`
- `make h5-app.test.e2e`

### iOS App

状态：主链路完成，真机/APNs 待补验

已完成：
- Swift/SwiftUI 原生实现覆盖 Flutter parity 主链路。
- SwiftPM 单测、H5/API/iOS live smoke、H5/iOS 富媒体互通、媒体 mock 回归、本机
  iOS Simulator smoke 和 XCUITest 均已收口。
- `make ios-app.test.interop` 已作为 H5/API/iOS 联调总入口。
- 当前未发现阻断 H5/API/iOS 主链路联调的 P0/P1 功能缺口。

保留待补验见本文档第 9 节。

### Android App 已完成基线

状态：P0 媒体切片完成，P1/P2 待执行

已完成：
- 原生 Android 工程骨架、Compose App Shell、测试和覆盖率入口。
- 普通账号密码认证、本地模拟认证和真实 API 认证合同。
- Chat / Contacts / Rooms 真实 API、Room 缓存、WebSocket JSON 增量、群管理。
- 附件选择、mock 对象存储直传、富媒体消息、附件本地文件缓存。
- 用户头像缓存、群头像缓存、权限拒绝恢复、语音播放基线。
- 已验证入口包括 unit、live、interop、coverage、lint、debug build、connected test、
  emulator smoke。

保留待补：
- 语音录制、相机、麦克风质量、FCM 真实 token、云端 Push、厂商 ROM 行为和 Play
  发布链路属于真机补验，不在 Emulator 阶段伪造通过。
- Android P1/P2 的剩余功能见第 5、6 节。

## 3. 剩余任务优先级总览

P0：已收口
- `CROSS-P1-01` H5/API/Android 联调脚本扩展。

P1：Android 原生 parity 补齐
- `ANDROID-P1-01` 聊天扩展。
- `ANDROID-P1-02` 设置、账号和配置。
- `ANDROID-P1-03` 全量对照和覆盖率提升。

P2：Android 底座、通知和 API 架构
- `ANDROID-P2-01` 通知和 Push mock 可测部分。
- `ANDROID-P2-02` HTTP client 与统一错误模型。
- `ANDROID-P2-03` WebSocket protobuf 二进制帧。
- `ANDROID-P2-04` DataStore、live smoke 分层和清理。
- `ARCH-P2-01` 性能矩阵扩展。
- `ARCH-P2-02` broker/event bus 抽象。
- `ARCH-P2-03` Compose-first 环境扩展。
- `ARCH-P2-04` 最终性能报告。

P3：发布、回滚和非主线保留
- `RELEASE-P3-01` 全模块回归。
- `RELEASE-P3-02` 原生切换条件。
- `RELEASE-P3-03` 发布与回滚文档。
- Admin / Desktop / Website / Flutter `app/` / E2EE / H5 安全加固保留入口。

## 4. P0：当前立即任务

### CROSS-P1-01 H5/API/Android 联调脚本扩展

状态：完成

目标：
- 让 H5 和 Android 原生在同一 Compose API 上完成核心流程互通验收。
- 把当前散落的 H5 live、Android live、Android 可测本地能力入口整理成一个可复现
  的联调总入口。

当前结果：
- `make android-app.test.interop` 已改为自动启动并等待 Compose API dev 栈，然后串联
  `h5-app.test.live`、`android-app.test.live` 与 `android-app.test.interop.support`。
- `android-app.test.live` 覆盖 Android 数据层注册、建群、双向文本互发、
  附件签名/mock 直传/commit/发送/双方可见/下载 URL、已读、好友申请/接受、
  私聊消息和群管理。
- `android-app.test.interop.support` 覆盖头像缓存、权限恢复状态机和语音播放
  ViewModel 状态机，避免联调入口只验证 live API 而漏掉本地可测能力。
- 失败提示已明确 API 容器日志、H5 live 输出、Android unit report、test results
  和 coverage report。

已更新：
- `Makefile`
- `android-app/README.md`
- `android-app/docs/remaining-migration-tasks.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/reference/testing/README.md`
- `docs/reports/task-list.md`
- 本文档

已验证：
- `make android-app.test.interop.support`
- `make android-app.test.interop`

## 5. Android P1：原生 parity 后续能力

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

建议涉及文件：
- `android-app/app/src/main/java/com/redcode/im/androidapp/feature/`
- `android-app/app/src/main/java/com/redcode/im/androidapp/data/`
- `android-app/app/src/main/java/com/redcode/im/androidapp/persistence/`
- `android-app/app/src/test/java/com/redcode/im/androidapp/`
- `android-app/app/src/androidTest/java/com/redcode/im/androidapp/`

验收：
- ViewModel、Repository、DTO mapping、cache 单测覆盖。
- Compose UI test 覆盖输入区、表情入口、贴纸发送可测路径。
- `make android-app.test.unit`
- `make android-app.connected-test`
- `make android-app.smoke.emulator`

### ANDROID-P1-02 设置、账号和配置

状态：待执行

任务：
- 个人资料页和昵称更新。
- 头像上传入口，复用头像缓存展示。
- 账号安全和修改密码。
- 用户协议、隐私政策、关于页完善。
- 反馈提交。
- App 配置拉取与缓存。
- 版本检查和更新提示。
- 当前默认普通账号密码注册/登录；邮箱注册/登录只做后台配置能力，不依赖真实
  邮箱资源。

验收：
- 设置域单测覆盖成功、失败、缓存回退和登出清理。
- 与 H5/API 的资料、配置、版本字段保持一致。
- `make android-app.test.unit`
- `make android-app.test.live`
- `make android-app.connected-test`

### ANDROID-P1-03 全量对照和覆盖率提升

状态：待执行

任务：
- 逐项比对 Flutter `app/` 与 Android 原生已实现能力。
- 生成 Android 已完成、部分完成、跳过、缺失清单。
- 覆盖率继续提升，优先 ViewModel、Repository、DTO mapping、Room cache、
  DataStore、文件缓存。
- Emulator smoke 增加聊天、联系人、群、设置关键页面截图或 UI test。
- 明确 Flutter Android 下线条件和回滚策略。

验收：
- `make android-app.coverage`
- `make android-app.smoke.emulator`
- `android-app/docs/remaining-migration-tasks.md` 更新到发布切换口径。

## 6. Android P2：通知、Push 和底座协议

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

## 7. API P2：性能与核心架构重构

目标：在 H5/API/Android 主链路稳定后，进入可度量、可回滚的底层架构优化。

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
- 报告记录 API/PG/Redis CPU、内存、PG pool、bcrypt cost、metrics 参数、
  WS 队列大小。
- 性能入口仍使用 Docker Compose 资源限制。

### ARCH-P2-02 broker/event bus 抽象

状态：待执行

任务：
- 先抽象 broker/event bus 层，当前 Redis PubSub 作为一个实现。
- 单机默认保持轻量：PG + Redis + API + external-mock。
- 分布式 profile 增加 NATS Core，用于低延迟实时 fanout。
- 需要持久化、重放、消费者 ack 的异步任务再引入 NATS JetStream。
- Kafka 暂不作为 IM 实时消息主链路；仅在后续审计事件流、超大规模日志分析、
  跨系统数据管道时评估。

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
- Redis 测试栈保持一个实例，API 的 session/pubsub/cache 三个通道指向同一
  Redis。
- Docker Compose 资源限制用于固定测试指标。
- 分布式 profile 应与单机 profile 共用同一套 Makefile/文档入口，避免两套不可
  比较的环境。

验收：
- `api/docker/dev/docker-compose.yml`
- `api/docker/release/docker-compose.yml`
- `tests/docker-compose.test.yml`
- perf 入口均同步更新并记录资源限制。

### ARCH-P2-04 最终性能报告

状态：待执行

任务：
- Android/H5/iOS/API 主链路验收后，重新跑 release small/standard/large。
- 汇总单机最佳 PG pool、Redis 单实例、API 资源限制和 WebSocket fanout 指标。
- 给出单机和分布式部署的推荐 profile。

验收：
- 新性能报告写入 `docs/reports/performance/`。
- 报告包含可复现实验条件和回滚说明。

## 8. P3：横向回归和发布准备

### RELEASE-P3-01 全模块回归

状态：待执行

命令：

```bash
make api.test
make h5-app.check
make h5-app.test.unit
make h5-app.test.live
make h5-app.test.e2e
make android-app.test.interop
make ios-app.test.interop
cd admin && bun run type:check
cd desktop && bun run test
cd website && bun run test
git diff --check
```

说明：
- `h5-app.test.live`、`h5-app.test.e2e`、`android-app.test.interop`、
  `ios-app.test.interop` 需要本机 Compose API 已启动。
- 若某模块未改动，可记录跳过原因；发布前仍需完整回归。

### RELEASE-P3-02 原生切换条件

状态：待执行

任务：
- Flutter `app/` 不移除。
- Android 原生切换条件：Android P0/P1 完成、interop 通过、真机必要项按发布
  要求补验或明确豁免。
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

## 9. 真机待补验

### iOS 真机/APNs

状态：待补验

说明：
- 当前已按用户要求跳过，不阻塞主线。
- Simulator/单测只能覆盖本地通知调度、payload 导航和登出通知态清理，不能
  替代真实 APNs 离线投递。

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

### Android 真机/FCM/厂商行为

状态：待补验

说明：
- Emulator 阶段只做可模拟的权限、本地通知和数据层状态机。
- 以下真机行为不在 Emulator 阶段伪造通过。

任务：
- 相机拍摄图片/视频。
- 麦克风录音质量、权限、后台中断。
- 厂商 ROM 文件选择器差异。
- FCM 真实 token 获取。
- 云端 Push 投递。
- 前台/后台/冷启动通知导航。
- 厂商 ROM 后台限制。
- Play 签名、release 包安装和发布链路。

## 10. 非当前主线但保留入口

- Admin：当前不是 P0；保留 route smoke、真实后端 smoke 和 RBAC 回归入口。
- Desktop / Website：当前不是 P0；保留单测、真实后端 smoke 和下载逻辑测试。
- Flutter `app/`：保留，不移除；后续作为回滚包、行为对照和原生切换前基线。
- 端到端加密：已有 `docs/reference/architecture/end-to-end-encryption-design.md`，
  尚未进入实现主线；需要独立威胁模型和迁移计划。
- H5 安全加固：token 后续可评估 httpOnly SameSite Cookie 或短生命周期 token
  策略。
- 历史 `docs/plans/2026-03-*` 和 `docs/plans/2026-04-*` 中仍有未勾选项，不自动
  纳入当前主线；只有用户重新激活对应计划时再复核并迁移到本文档。

## 11. 每个切片通用完成标准

- 只改当前切片相关文件。
- 更新对应模块文档和本总账。
- 行为变更必须补单测、integration、smoke 或明确记录不可自动化原因。
- 真机项只记录 SKIPPED，不伪造通过。
- 执行对应模块验证命令和 `git diff --check`。
- 通过后使用 Conventional Commits 提交并推送。
- 只 stage 本轮相关文件，避免混入用户或历史无关改动。
- API、PG、Redis、external-mock、性能压测保持 Docker Compose-first。

## 12. 下一步执行指针

下一步直接执行：

```text
ANDROID-P1-01 聊天扩展
```

随后进入：

```text
ANDROID-P1-02 设置、账号和配置
ANDROID-P1-03 全量对照和覆盖率提升
```

## 13. 主要依据文档

- `docs/reports/task-list.md`
- `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- `docs/plans/2026-07-04-002-feat-android-app-native-migration-plan.md`
- `android-app/docs/remaining-migration-tasks.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/plans/2026-07-04-001-ios-app-remaining-parity-execution-list.md`
- `ios-app/docs/full-migration-task-tree.md`
- `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- `docs/reports/performance/api-compose-baseline-2026-07-01.md`
- `docs/reference/testing/README.md`
- `api/docker/dev/docker-compose.yml`
- `api/docker/release/docker-compose.yml`
- `tests/docker-compose.test.yml`
