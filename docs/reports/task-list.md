# RedCode IM 剩余任务清单

更新时间：2026-08-03

本文档是当前仓库剩余任务的唯一 active 总入口。IM 2.0 的产品合同以
`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md` 为准，当前执行
顺序、验收标准和停止条件以
`docs/plans/2026-08-03-001-feat-im-2-0-remaining-work-plan.md` 为准。更早的剩余
任务分解仅作历史追踪，不再决定当前优先级。

## 入口文档

- 剩余任务完整执行分解：`docs/reports/remaining-task-breakdown-2026-07-05.md`
- IM 2.0 正式开发总计划：`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md`
- IM 2.0 剩余工作计划：`docs/plans/2026-08-03-001-feat-im-2-0-remaining-work-plan.md`
- Flutter U8 设备验收记录：`docs/reviews/2026-08-02-im-2-0-u8-device-acceptance-review.md`
- Android 原生迁移执行清单：`android-app/docs/remaining-migration-tasks.md`
- Android 全量迁移任务树：`android-app/docs/full-migration-task-tree.md`
- iOS 原生 parity 收口报告：`docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- iOS 剩余补验清单：`docs/plans/2026-07-04-001-ios-app-remaining-parity-execution-list.md`
- H5 Flutter parity 计划：`docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- API 性能基线：`docs/reports/performance/api-compose-baseline-2026-07-01.md`
- 测试入口：`docs/reference/testing/README.md`

## 当前结论

- 当前主线：Flutter `app/` 2.0 U8 设备验收 -> H5 P0 parity -> E2EE 发布门禁 -> Flutter 桌面 P0 -> 多平台发布。
- 当前立即任务：先完成 `R1.0` 双 iOS Patrol 可靠编排，再继续 U8 系统交互、权限、群聊、已读、前后台和离线恢复验收。
- 当前下一阶段：U8 关闭后执行 H5 差异审计，并把 E2EE 专项计划深化到 Go/No-Go。
- 当前发布阻断项：U8、H5 P0、E2EE、多平台桌面构建、签名/版本/升级/回滚链路。
- 朋友圈、扫一扫、附近的人、音视频通话和游戏默认不阻断 2.0 核心首发；只有本总账明确标记为“2.0 首发必需”的 P1 切片才成为发布门禁。
- `ANDROID-P1-01 聊天扩展` 已完成实现和本地验收，现作为原生恢复时的归档基线。
- `h5-app` 已具备聊天、搜索、联系人 store、群设置和设置页面等基础能力，但尚未按 Flutter 2.0 P0 完成页面、状态、API 和跨端互操作差异审计。
- `ios-app` 主链路已完成；仅保留 iPhone 真机/APNs 补验。
- `android-app` 已完成 P0 媒体切片和聊天扩展；剩余集中在设置账号配置、通知
  mock、底座协议和最终切换准备。
- Flutter `app/` 保留并继续维护，当前作为第一个版本正式移动端主线，按已闭合
  API 合同作为发布、回滚和行为对照基线。
- Android / iOS 原生开发暂时暂停；不删除代码和文档，后续用户重新激活时再恢复。
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

- [x] `IM2-R1.0` 双 iOS Patrol 可靠编排
  - 单一脚本生成 marker、校验两个不同 Simulator、分配独立端口并隔离 A/B 构建产物。
  - 验证两端实际账号、角色和消息前缀，覆盖超时、失败清理、日志与 xcresult 留存。
  - 提供 `make app.test.patrol.dual` 唯一推荐入口并纳入 `make app.test.scripts` 契约测试。
  - 2026-08-03 连续两轮真实运行通过，marker、A/B 构建身份、日志和 `xcresult` 均独立留存。
- [ ] `IM2-U8` Flutter 移动 P0 设备验收收口
  - 已通过 iOS integration/auth/API contract、Patrol 登录和双 iOS 私聊实时互发。
  - R1.1 自动化已通过长 composer、焦点优先返回和动态横竖屏缩放；真实软键盘与系统可访问性设置仍按人工清单 PENDING。
  - 待补系统键盘、安全区、长内容、权限拒绝/恢复、群聊、已读、前后台、离线重连、附件和完整页面巡检。
  - Simulator 无法证明的相机/麦克风质量、APNs 和后台通知只记录真机 SKIPPED/PASS，不伪造结果。
- [ ] `IM2-U9` H5 P0 parity
  - U8 关闭后，先按已有/缺失/漂移/平台不适用建立矩阵，再分聊天、联系人/群、我的/设置和跨端互操作闭环。
- [ ] `IM2-U10` E2EE 发布门禁
  - 先深化 `docs/plans/2026-07-31-003-feat-api-ui-capability-parity-plan.md`，冻结协议库、key API、数据模型、最低版本、灰度和回滚策略。
  - Go/No-Go 通过后再实施单聊、多设备、群聊和 Flutter/H5 互操作；未关闭时阻断 2.0 发布。
- [ ] `IM2-U11` P1 可选纵向切片
  - 朋友圈、扫一扫、附近的人、音视频通话、游戏均需独立子计划；当前均未批准为核心首发必需。
- [ ] `IM2-U12` Flutter 桌面 P0
  - H5 P0 后可复用稳定业务控制器实施 Windows、macOS、Linux 桌面 shell；P1 桌面入口随对应切片补齐。
- [ ] `IM2-U13` 多平台发布切换
  - U8/U9/U10/U12 和获批首发 P1 关闭后，完成构建矩阵、签名凭据、checksum、来源追踪、升级与回滚。

## 历史已完成与暂停队列

- [x] `FLUTTER-P0-01` Flutter 首版 API 合同联调收口
  - 已新增 Flutter contract integration 入口。
  - 已完成 Flutter REST path 与 `api/src/routes.rs` 机械化对照：85/85 闭合。
  - 已新增可复跑入口：`make app.test.api-paths`。
  - 已通过 Pixel 8 Pro 真实 API auth、network、contract 联调。
  - 验收报告：`docs/reports/flutter-first-release-readiness-2026-07-23.md`。
- [x] `CROSS-P1-01` H5/API/Android 联调脚本扩展
  - `make android-app.test.interop` 已自动启动并等待 Compose API dev 栈。
  - 已串联 H5 live smoke、Android live smoke 与 Android 本地能力定向测试。
  - 已覆盖认证、联系人、好友、建群、文本、富媒体、头像缓存、权限恢复状态机和
    语音播放状态机。
- [x] `ANDROID-P1-01` 聊天扩展
  - 内置 emoji、表情包列表、表情资源缓存、贴纸发送、聊天背景、聊天设置。
  - 已通过 unit/connected/lint/build/Pixel 8 Pro smoke/live/interop/coverage 验证。
- [ ] `ANDROID-P1-02` 设置、账号和配置
  - 个人资料、昵称更新、头像上传入口、账号安全、修改密码、协议文档、关于、
    反馈、配置、版本检查。

## H5 历史基线

- [x] H5 全量验收与文档收口。
- [x] 浏览器 E2E / smoke 扩展。
- [x] 本地消息搜索页面。
- [x] 头像上传浏览器能力。
- [x] 浏览器存储增强。
- [x] H5 parity Unit 8 最终勾选。

以上是 1.x/既有 parity 基线，不代表已满足 Flutter 2.0 P0。当前剩余项统一由 `IM2-U9` 管理。

## Android 剩余任务

状态：暂时暂停；保留任务清单，不进入当前首版执行队列。

- [x] `ANDROID-P1-01` 聊天扩展
  - 内置 emoji、表情包列表、表情资源缓存、贴纸发送、聊天背景、聊天设置。
  - 已通过 unit/connected/lint/build/Pixel 8 Pro smoke/live/interop/coverage 验证。
- [ ] `ANDROID-P1-02` 设置、账号和配置
  - 个人资料、昵称更新、头像上传入口、账号安全、修改密码、协议文档、关于、
    反馈、配置、版本检查。
- [ ] `ANDROID-P1-03` 全量对照和覆盖率提升
  - Flutter vs Android 对照、缺口清单、覆盖率提升、下线条件和回滚策略。
- [ ] `ANDROID-P2-01` 通知和 Push 的 Emulator/mock 可测部分
  - 通知权限、本地通知、通知导航、FCM token mock、登出通知态清理。
- [ ] `ANDROID-P2-02` HTTP client 与统一错误模型
  - 错误码分类、重试建议、用户可读错误映射。
- [ ] `ANDROID-P2-03` WebSocket protobuf 二进制帧
  - 保留 JSON fallback，补 protobuf 解码、去重和订阅恢复测试。
- [ ] `ANDROID-P2-04` DataStore、live smoke 分层和清理
  - 聊天/通知/外观偏好、live 子集、登出清理文件 cache/通知态/DataStore。

## iOS 剩余任务

状态：暂时暂停；保留真机/APNs 补验入口，不进入当前首版执行队列。

当前无阻塞 H5/API/iOS 主链路的 P0/P1 功能缺口。

待补验：
- [ ] iPhone 真机签名、安装和启动。
- [ ] APNs token 获取。
- [ ] Apple APNs 真实离线系统通知。
- [ ] 系统通知点击唤醒。
- [ ] 冷启动通知深链。

恢复入口：

```bash
IOS_APNS_PROVIDER_CONFIGURED=1 make ios-app.apns.preflight.local
IOS_APNS_PROVIDER_CONFIGURED=1 IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID> make ios-app.smoke.device.local
```

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
  - Android/H5/iOS/API 主链路验收后，重跑 release small/standard/large。

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

iOS 真机待补验见上方 iOS 剩余任务。

## 横向回归和发布准备

- [ ] `RELEASE-P3-01` 全模块回归
  - `make api.test`
  - `make app.check`
  - `make app.test.api-paths`
  - `make app.test.unit`
  - `make app.test.integration.network`
  - `make app.test.integration.auth`
  - `make app.test.integration.contract`
  - `make h5-app.check`
  - `make h5-app.test.unit`
  - `make h5-app.test.live`
  - `make h5-app.test.e2e`
  - `make android-app.test.interop`（原生恢复专项，不属于 Flutter 首版门禁）
  - `make ios-app.test.interop`（原生恢复专项，不属于 Flutter 首版门禁）
  - `cd admin && bun run type:check`
  - `cd desktop && bun run test`
  - `cd website && bun run test`
- [ ] `RELEASE-P3-02` 原生切换条件
  - Flutter `app/` 不移除。
  - 首版发布以 Flutter `app/` 为准，Android/iOS 原生切换条件暂不作为当前版本门禁。
  - Android 原生 P0/P1 完成、interop 通过、真机必要项补验或明确豁免。
  - iOS 原生主链路已完成；正式上架如要求 APNs/真机则恢复补验。
- [ ] `RELEASE-P3-03` 发布与回滚文档
  - 原生 Android/iOS 切换步骤、H5 联调基线、API 兼容边界、缓存清理和回滚步骤、
    Push/对象存储/消息总线回滚开关。

## 执行规则

- 每个功能切片完成后更新对应模块文档和剩余任务总账。
- 行为变更必须补单测、integration、smoke 或明确记录不可自动化原因。
- 真机项只记录 SKIPPED，不伪造通过。
- 每个可独立验收切片通过测试后，按 Conventional Commits 提交并推送。
- 只 stage 本轮相关文件，避免混入用户或历史无关改动。
- API、PG、Redis、external-mock、性能压测全部保持 Compose-first。
