# RedCode IM 剩余任务清单

更新时间：2026-07-05

本文档是当前仓库剩余任务的总入口。细节任务仍以对应模块文档为准：

- Android 原生迁移执行清单：`android-app/docs/remaining-migration-tasks.md`
- Android 全量迁移任务树：`android-app/docs/full-migration-task-tree.md`
- iOS 原生 parity 收口报告：`docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`
- H5 Flutter parity 计划：`docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md`
- API 性能基线：`docs/reports/performance/api-compose-baseline-2026-07-01.md`
- 测试入口：`docs/reference/testing/README.md`

## 当前结论

- 当前主线不再是旧 Admin RBAC 任务；旧 Admin mock / `src/api` 业务依赖清理已收口，不作为当前 P0。
- 当前 P0 是 `android-app` 原生迁移剩余能力，先补齐 Emulator 可测的媒体、cache、权限和语音播放基线。
- `h5-app` 已承担 H5/API 联调入口，核心功能已完成；剩余是全量验收、E2E 文档收口、搜索页和头像上传等尾项。
- `ios-app` 主要 Flutter parity 已完成；必须 iPhone 真机和 APNs 凭据才能验证的项按用户要求跳过并记录，不阻塞当前主线。
- Flutter `app/` 保留，不移除；后续只作为回滚和对照基线。
- API 性能基线已建立；架构重构和分布式消息总线应在 Android/H5/API 主链路验收后进入独立重构计划。

## P0：Android 原生迁移当前切片

目标：完成 `ANDROID-06` 中不依赖 Android 真机的剩余可测能力，并保持 H5/API/Android 联调可重复。

- [ ] 用户头像缓存
  - 接入用户头像 download URL。
  - 保存到 app cache。
  - UI 优先使用缓存头像，失败降级占位。
  - 覆盖缓存命中、下载失败和清理逻辑。
- [ ] 群头像缓存
  - 接入群头像 download URL。
  - 群列表、群详情使用缓存头像。
  - 登出或清理本地状态时清理缓存。
- [x] 附件本地文件 cache
  - 已发送/已下载附件保存到 app cache。
  - 再次打开优先使用本地缓存。
  - 本地文件丢失或损坏时重新拉取 download URL。
- [ ] 权限拒绝和恢复路径
  - 文件选择器取消选择不报错。
  - 麦克风/通知权限拒绝时给出可恢复提示。
  - 二次拒绝时引导到系统设置。
- [ ] 语音播放基线
  - 已上传 audio part 的播放入口。
  - 播放、暂停、错误状态。
  - 不依赖麦克风录音即可在 Emulator 验证。

建议第一刀：

1. 建立 Android 文件缓存底座，供头像、附件、表情复用。
2. 增加通用 download bytes 能力。
3. 先落附件 cache，再复用到用户头像和群头像。
4. 补 JVM 单测和必要的 instrumented cache 测试。

P0 验证入口：

```bash
make android-app.test.unit
make android-app.connected-test
make android-app.lint
make android-app.build.debug
make android-app.smoke.emulator
git diff --check
```

触达真实 API / mock 对象存储后追加：

```bash
make android-app.test.live
make android-app.test.interop
```

## P1：Android 后续 parity 能力

目标：完成 Android 原生 App 对 Flutter 当前核心功能的完整替代准备。

- [ ] `ANDROID-07` 聊天扩展
  - 内置 emoji 面板。
  - 表情包列表和表情项加载。
  - 表情资源 cache。
  - 贴纸发送。
  - 聊天背景。
  - 聊天设置。
- [ ] `ANDROID-08` 设置、账号和配置
  - 个人资料和昵称更新。
  - 账号安全和修改密码。
  - 用户协议、隐私政策、关于页完善。
  - 反馈提交。
  - App 配置拉取与缓存。
  - 版本检查和更新提示。
- [ ] `ANDROID-09` 通知和 Push 的 Emulator/mock 可测部分
  - Android 13+ 本地通知权限。
  - 本地通知展示和 channel 管理。
  - 通知点击进入 room。
  - FCM token 注册 mock 覆盖。
  - 登出通知态清理。
- [ ] `ANDROID-10` 全量验收与切换准备
  - Android vs Flutter 功能对照。
  - H5/API/Android 联调脚本扩展。
  - Compose UI 回归和截图/UiTest 覆盖。
  - 覆盖率继续提升，优先 ViewModel、Repository、DTO mapping、Room cache。
  - P0/P1 缺口清单。
  - Flutter Android 下线条件。
  - 回滚策略。

## P1：H5 联调入口收口

目标：保证后续先用 `h5-app` 与 API 联调，作为 Android/iOS 原生迁移的浏览器基准端。

- [ ] H5 全量验收与文档收口
  - 完成 `docs/plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md` 的 Unit 8。
  - 明确 H5 是 backend + frontend 联调优先入口。
  - 保持 `make h5-app.test.live` 可覆盖 auth、chat、contacts、settings、富媒体。
- [ ] 浏览器 E2E / smoke 扩展
  - 注册登录后进入聊天 tab。
  - 创建或进入房间，发送消息。
  - 刷新页面后从本地缓存恢复。
  - 好友申请闭环。
  - 群设置关键路径。
- [ ] H5 本地消息搜索页面
  - 当前已有本地搜索存储测试。
  - 需要补页面、跳转和真实缓存查询交互。
- [ ] H5 头像上传浏览器能力
  - 走浏览器文件选择。
  - 复用 direct upload / commit / avatar cache。
  - 失败时保持旧头像。

## P2：API 性能与核心架构重构

目标：在功能主链路稳定后，进入可度量、可回滚的底层架构优化。

- [ ] 性能矩阵继续扩展
  - auth 链路生产成本 `BCRYPT_COST=12` 指标。
  - account limit settings 缓存。
  - 用户名/邮箱存在性检查合并，或改为依赖唯一索引冲突处理。
  - WebSocket 广播扩展到 100 / 500 / 1000 订阅者。
  - 多房间并发广播。
  - 慢客户端和 `WS_OUTBOUND_QUEUE_SIZE` 满队列行为。
- [ ] 分布式消息架构计划
  - 先抽象 broker/event bus 层，当前 Redis PubSub 作为一个实现。
  - 单机默认保持轻量：PG + Redis + API + external-mock。
  - 分布式 profile 增加 NATS Core，用于低延迟实时 fanout。
  - 需要持久化、重放、消费者 ack 的异步任务再引入 NATS JetStream。
  - Kafka 暂不作为 IM 实时消息主链路；仅在后续需要审计事件流、超大规模日志分析、跨系统数据管道时评估。
- [ ] Compose-first 重构环境
  - 所有中间件、数据库、API 启动和测试都通过 docker compose。
  - 保持测试栈 PG/Redis/external-mock 不映射宿主端口。
  - 新增中间件时同步 dev/test/perf compose profile 和资源限制。
- [ ] 最终性能报告
  - Android/H5/iOS/API 主链路验收后，重新跑 release small/standard/large。
  - 统一记录 CPU、内存、PG pool、bcrypt cost、metrics 参数和 WS 队列大小。

## P2：iOS 真机补验

这些不阻塞当前主线，已按用户要求跳过并记录。

- [ ] iPhone 真机签名、安装和启动。
- [ ] APNs token 获取。
- [ ] Apple APNs 真实离线系统通知。
- [ ] 系统通知点击唤醒。
- [ ] 冷启动通知深链。

恢复补验入口：

```bash
IOS_APNS_PROVIDER_CONFIGURED=1 make ios-app.apns.preflight.local
IOS_APNS_PROVIDER_CONFIGURED=1 IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID> make ios-app.smoke.device.local
```

## P2：Android 真机补验

这些不在 Emulator 阶段伪造通过。

- [ ] 相机拍摄图片/视频。
- [ ] 麦克风录音质量、权限、后台中断。
- [ ] 厂商 ROM 文件选择器差异。
- [ ] FCM 真实 token 获取。
- [ ] 云端 Push 投递。
- [ ] 前台/后台/冷启动通知导航。
- [ ] 厂商 ROM 后台限制。
- [ ] Play 签名、release 包安装和发布链路。

## P3：横向回归和发布准备

- [ ] 全模块回归
  - `make api.test`
  - `make h5-app.check`
  - `make h5-app.test.unit`
  - `make h5-app.test.live`
  - `make android-app.test.interop`
  - `make ios-app.test.interop`
  - `cd admin && bun run type:check`
  - `cd desktop && bun run test`
  - `cd website && bun run test`
- [ ] Flutter `app/` 保留策略
  - 不移除 Flutter 模块。
  - Android/iOS 原生完成切换前，Flutter 继续作为回滚包和行为对照。
  - 原生移动端稳定后，再单独制定 Flutter 下线计划。
- [ ] 发布与回滚文档
  - 原生 Android 切换条件。
  - 原生 iOS 切换条件。
  - H5 联调基线。
  - API 兼容边界。
  - 出现客户端缓存问题时的清理和回滚步骤。

## 当前外部依赖 / Mock 口径

- 本地测试对象存储走 `external-mock`，不访问线上 Backblaze B2。
- 本地 Push 发送走 `external-mock`，不访问线上 FCM/APNs。
- IPInfo 走 `external-mock`。
- Google / Apple 登录已移除当前主线。
- 邮箱验证码不作为当前注册/登录必需条件；当前测试主线使用普通账号密码。
- 当前未发现影响本地 H5/API/iOS/Android smoke 的新增外部服务依赖。

## 执行规则

- 每个功能切片完成后更新对应模块文档。
- 每个可独立验收切片通过测试后，按 Conventional Commits 提交并推送。
- 只 stage 本轮相关文件，避免混入用户或历史无关改动。
- 端口冲突先停止占用进程，不改用其他端口。
- API、PG、Redis、external-mock、性能压测全部保持 Compose-first。
