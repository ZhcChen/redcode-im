# RedCode IM 剩余任务清单

更新时间：2026-07-05

本文档是当前仓库剩余任务的总入口。完整执行顺序以 `docs/reports/remaining-task-breakdown-2026-07-05.md` 为准；模块细节继续参考模块文档。

## 入口文档

- 剩余任务完整执行分解：`docs/reports/remaining-task-breakdown-2026-07-05.md`
- Android 原生迁移执行清单：`android-app/docs/remaining-migration-tasks.md`
- Android 全量迁移任务树：`android-app/docs/full-migration-task-tree.md`
- iOS 原生 parity 收口报告：`docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- iOS 剩余补验清单：`docs/plans/2026-07-04-001-ios-app-remaining-parity-execution-list.md`
- H5 Flutter parity 计划：`docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- API 性能基线：`docs/reports/performance/api-compose-baseline-2026-07-01.md`
- 测试入口：`docs/reference/testing/README.md`

## 当前结论

- 当前主线：先用 `h5-app` 与 Compose API 做 backend + frontend 联调，随后扩展 Android 原生互通、全模块回归和 API 架构重构。
- 当前立即任务：收口 H5 头像上传浏览器能力。
- 当前 H5 头像上传已有未提交草稿，状态是 `进行中`，不能视为完成。
- `h5-app` 已承担联调入口，文档、live smoke、浏览器 E2E smoke、本地消息搜索页已收口。
- `android-app` P0 媒体切片已完成：附件缓存、头像缓存、权限拒绝恢复、语音播放基线均已收口。
- `ios-app` 主要 Flutter parity 已完成；必须 iPhone 真机和 APNs 凭据才能验证的项按用户要求跳过并记录。
- Flutter `app/` 保留，不移除；后续只作为回滚和对照基线。
- Google / Apple 登录不进入当前主线；默认普通账号密码注册/登录。
- 对象存储、Push、IPInfo 在本地测试走 `external-mock`，不访问线上 B2、FCM、APNs。
- API 性能基线已建立；分布式消息总线和性能矩阵扩展在 H5/API/Android 主链路稳定后进入独立重构切片。

## 当前立即队列

- [ ] `H5-P1-04` H5 头像上传浏览器能力
  - 状态：进行中。
  - 用户头像上传、群头像上传。
  - 复用 direct upload / signed URL PUT / commit / avatar cache。
  - 上传失败保留旧头像、旧 session 和旧会话摘要。
  - 成功后刷新当前用户、联系人/会话展示、群资料和头像缓存。
  - 使用 `external-mock` 完成 live smoke。
- [ ] `H5-P1-05` H5 浏览器存储增强
  - wa-sqlite OPFS worker 化。
  - IndexedDB VFS fallback。
  - OPFS、IndexedDB、FTS5、Cache API 能力探测。
  - 缓存配额、过期和清理策略。
- [ ] `H5-P1-06` H5 parity Unit 8 最终勾选
  - 头像上传和存储增强完成后，回填 H5 parity 计划与测试文档。
- [ ] `CROSS-P1-01` H5/API/Android 联调脚本扩展
  - 串联 H5 live smoke 与 Android live smoke。
  - 覆盖认证、联系人、好友、建群、文本、富媒体、头像缓存、权限降级和语音播放可测路径。

## H5 剩余任务

- [x] H5 全量验收与文档收口。
- [x] 浏览器 E2E / smoke 扩展。
- [x] 本地消息搜索页面。
- [ ] 头像上传浏览器能力。
- [ ] 浏览器存储增强。
- [ ] H5 parity Unit 8 最终勾选。

## Android 剩余任务

- [ ] `ANDROID-07` 聊天扩展
  - 内置 emoji、表情包列表、表情资源缓存、贴纸发送、聊天背景、聊天设置。
- [ ] `ANDROID-08` 设置、账号和配置
  - 个人资料、昵称更新、头像上传入口、账号安全、修改密码、协议文档、关于、反馈、配置、版本检查。
- [ ] `ANDROID-09` 通知和 Push 的 Emulator/mock 可测部分
  - 通知权限、本地通知、通知导航、FCM token mock、登出通知态清理。
- [ ] `ANDROID-10` 全量验收与切换准备
  - Flutter vs Android 对照、H5/API/Android 联调、Compose UI 回归、覆盖率提升、缺口清单、下线条件、回滚策略。
- [ ] 底座补齐
  - 统一错误模型、WebSocket protobuf 二进制帧、DataStore 扩展、live smoke 分层、登出清理文件 cache/通知态。

## iOS 剩余任务

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

- [ ] 性能矩阵扩展
  - `BCRYPT_COST=12` auth 指标、account limit settings 缓存、注册/登录存在性检查优化、WS 100/500/1000 订阅者、多房间广播、慢客户端和满队列行为。
- [ ] broker/event bus 抽象
  - 保留 Redis PubSub 实现。
  - 分布式 profile 引入 NATS Core。
  - 需要持久化、重放、消费者 ack 时再引入 NATS JetStream。
  - Kafka 暂不作为 IM 实时消息主链路。
- [ ] Compose-first 环境扩展
  - 新增中间件同步 dev/test/perf profile。
  - 测试栈 PG/Redis/external-mock 不映射宿主端口。
  - Redis 测试栈保持一个实例，session/pubsub/cache 三个通道指向同一 Redis。
  - Compose 资源限制用于固定测试指标。
- [ ] 最终性能报告
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

- [ ] 全模块回归
  - `make api.test`
  - `make h5-app.check`
  - `make h5-app.test.unit`
  - `make h5-app.test.live`
  - `make h5-app.test.e2e`
  - `make android-app.test.interop`
  - `make ios-app.test.interop`
  - `cd admin && bun run type:check`
  - `cd desktop && bun run test`
  - `cd website && bun run test`
- [ ] 原生切换条件
  - Flutter `app/` 不移除。
  - Android 原生 P0/P1 完成、interop 通过、真机必要项补验或明确豁免。
  - iOS 原生主链路已完成；正式上架如要求 APNs/真机则恢复补验。
- [ ] 发布与回滚文档
  - 原生 Android/iOS 切换步骤、H5 联调基线、API 兼容边界、缓存清理和回滚步骤、Push/对象存储/消息总线回滚开关。

## 执行规则

- 每个功能切片完成后更新对应模块文档和剩余任务总账。
- 行为变更必须补单测、integration、smoke 或明确记录不可自动化原因。
- 真机项只记录 SKIPPED，不伪造通过。
- 每个可独立验收切片通过测试后，按 Conventional Commits 提交并推送。
- 只 stage 本轮相关文件，避免混入用户或历史无关改动。
- API、PG、Redis、external-mock、性能压测全部保持 Compose-first。
