# RedCode IM 2.0 实现与回归基线

> 日期：2026-08-02
> 对应计划：`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md` U1
> 证据原则：只记录当前源码、测试和命令可以证明的事实；文件存在不等于端到端能力已交付。

## 结论

- `app/` 已有可复用的认证、消息、好友、群组、设置、上传、Push、WebSocket 和本地存储层，2.0 不需要复制第二套 service、storage 或 model。
- 当前入口仍是 `SplashPage -> LoginPage/HomeShellPage`，登录后使用“聊天、联系人、设置”三 Tab；与 2.0 的“聊天、联系人、发现、我的”四 Tab 不一致。
- 冻结设计源共有 43 条正式业务路由，已全部进入 `app/test/contracts/im_ui_route_contract_test.dart`：P0 38 条、P1 5 条、设计源专用 0 条、不适用 0 条。
- P1 路由为朋友圈列表、朋友圈详情、扫一扫、附近的人和游戏。`discover` 一级 shell 属于 P0，但其业务入口在对应 P1 合同完成前不得伪装为可用功能。
- 当前 Flutter REST path 合同检查结果为 `app_paths=85 api_routes=211 missing=0`；这只能证明路径已注册，不能替代权限、状态和真实设备验收。
- U1 开始时全量单测存在一个过时断言：1.5K 手机头像仍按 `0.96` 计算，而当前密度事实源为 `0.94`。本单元已将断言对齐当前规则，不修改生产行为。

## 运行时入口

| 链路 | 当前事实 | 2.0 迁移边界 |
| --- | --- | --- |
| 启动 | `app/lib/main.dart` 初始化热更新、本地通知、Push 和屏幕适配 | U3/U4 拆分 bootstrap，但保留初始化顺序和失败语义 |
| App 根 | `app/lib/app.dart` 装配主题、全局 Navigator、密度和 `SplashPage` | U2/U3 迁移 token、shell 与 route contract |
| 启动门禁 | `app/lib/features/startup/splash_page.dart` 处理会话、协议和版本状态 | U4 重构视觉与状态表达，不改认证 API 语义 |
| 登录 | `app/lib/features/auth/login_page.dart` 登录后清栈进入 `HomeShellPage` | U4 只保留普通账号密码认证，不引入 SMS 客户端入口 |
| 首页 | `app/lib/features/home/home_shell_page.dart` 使用三 Tab `IndexedStack` | U3 替换为四 Tab；设置下沉至“我的” |
| Push 导航 | `app/lib/core/services/push_navigation.dart` 通过全局 Navigator 打开聊天/群页面 | U3 纳入集中 route contract，并保持冷/热启动目标页行为 |

## 设计路由交付分类

机器可读事实源：

- 设计路由：`im-ui-html/tests/routes.ts`
- Flutter 分类：`app/test/contracts/im_ui_route_contract_test.dart`
- 设计语义：`im-ui-html/docs/page-map.md`

| 分类 | 数量 | 范围 |
| --- | ---: | --- |
| P0 | 38 | 登录、会话、聊天、已读、转发、联系人、举报、发现 shell、群治理、贴纸、搜索、我的和设置 |
| P1 | 5 | `moments`、`moment-detail`、`scan`、`nearby`、`games` |
| 设计源专用 | 0 | `entry/spec/pc-design/mobile-design/lab` 不属于 43 条正式业务 manifest |
| 不适用 | 0 | 当前正式 manifest 没有被产品合同排除的路由 |

契约测试同时校验 route ID、预览 path、交付分类和目标 Flutter route 非空。修改 `im-ui-html/tests/routes.ts` 时，未同步分类会直接导致 `make app.test` 失败。

## 现有能力矩阵

| 领域 | 当前源码证据 | 当前自动化证据 | 2.0 结论 |
| --- | --- | --- | --- |
| 认证与启动 | `features/auth/`、`features/startup/`、`core/auth/`、`core/update/` | 登录、认证模型、版本 service、真实 auth integration | 可迁移；U4 保持协议、会话恢复和版本门禁 |
| 会话与聊天 | `features/chat/`、`MessageService`、`WebSocketService` | chat widget/provider/model/runtime、真实消息合同 | 可迁移；U5 先刻画再拆大页面，不复制消息状态 |
| 联系人 | `features/contacts/`、`FriendService`、`FriendStore`、`FriendStorage` | 添加好友、好友模型、真实好友合同 | 可迁移；申请与举报等状态仍需按设计补齐 |
| 群组 | `group_*` 页面、`RoomService`、`RoomSubscriptionManager` | 建群、群目录、Room service、真实群治理合同 | 可迁移；角色可见性与服务端拒绝状态需 U6 统一 |
| 搜索 | `message_search_page.dart`、`MessageSearchStorage` | 搜索页与消息 runtime 测试 | 可迁移；U5 统一结果层级和原消息定位 |
| 贴纸 | `StickerManagementPage`、Emoji pack/item service 与 cache | emoji pack model、输入面板 runtime | 部分具备；U5/U7 统一聊天面板和管理状态 |
| 我的与设置 | 当前只有 `SettingsPage` 作为一级 Tab；已有账号、聊天、隐私、反馈、关于页面 | settings、feedback、version 与页面测试 | “我的”页面缺失；U7 新建入口并迁移设置链路 |
| 发现 | 没有正式 `features/discover/` | 无正式端 E2E | U3 只建 P0 shell；五条业务路由按 U11 合同先行 |
| 完整音视频通话 | 只有语音消息 service/widget 和视频预览页 | 语音消息 widget 测试 | 不能证明通话能力；按 U11e 单独交付 |
| 桌面 | Flutter 平台目录存在，当前无正式 desktop shell | 无三平台 shell 验收 | U3 只建立边界，U12 正式实现 |

## 可复用基础层

### Service

- 消息与实时：`MessageService`、`WebSocketService`、`RoomSubscriptionManager`。
- 关系与群组：`FriendService`、`FriendStore`、`RoomService`。
- 用户与媒体：`UserService`、`UserAvatarService`、`RoomAvatarService`、`VoiceService`、`UploadPolicyService`。
- 产品配置：`SettingsService`、`AppConfigService`、`VersionService`、`FeedbackService`。
- 贴纸：`EmojiPackService`、`EmojiItemService`。
- 平台：`PushService`、`LocalNotificationService`。

### Storage/Cache

- 会话与消息：`ChatCache`、`MessageStorage`、`MessageSearchStorage`。
- 身份与配置：`TokenStorage`、`AppConfigStorage`、`FriendStorage`。
- 媒体与贴纸：`AttachmentCache`、`AttachmentUrlCache`、`AvatarCache`、`EmojiCache`。

这些类型是迁移资产。后续单元允许增加 controller/adapter，但不得创建第二套 REST、WebSocket 或持久化实现。

## 测试基线

当前测试资产：

- Flutter unit/widget：51 个 `*_test.dart`（含本单元新增路由契约）。
- Flutter integration：4 个 `*_test.dart`。
- Patrol：2 个 `*_test.dart`。
- `test`/`testWidgets` 静态统计为 222 处；该数字只用于规模基线，不作为通过数量。

关键入口：

| 层级 | 入口 | 覆盖边界 |
| --- | --- | --- |
| 静态分析 | `make app.check` | Dart analyze |
| unit/widget | `make app.test` | core、chat、features、widgets 与路由分类 |
| API path | `make app.test.api-paths` | Flutter REST path 对 `api/src/routes.rs` 注册 |
| integration smoke | `make app.test.integration.smoke` | auth state bus 与附件缓存异步链路 |
| 真实认证 | `make app.test.integration.auth` | 普通账号注册/登录 |
| 真实合同 | `make app.test.integration.contract` | 认证、好友、群、消息、设置、Push 与清理 |
| 设备 | `make app.test.integration.device.*`、Patrol | 默认 Pixel 8 Pro，缺席时 iOS Simulator |

## U2-U7 必须保持的基线

1. 不删除或绕过普通账号登录、协议门禁、会话恢复、版本检查、Push 初始化与登出清理。
2. 不复制 `MessageService`、`FriendService`、`RoomService`、WebSocket 或 storage；新 UI 通过既有行为层接入。
3. `relay_only`、`persist`、`plaintext`、`e2ee` 的现有状态与限制必须继续由服务端配置裁决。
4. 43 条设计 route 的分类必须保持完整；新增或删除设计 route 时同步更新契约和平台交付文档。
5. 设计源 mock、页面文件名和 API path 注册都不能单独作为“能力完成”的证据；至少需要对应状态测试，核心链路还需要真实 API/设备验收。

## U1 验收记录

完成本单元时必须重新执行：

```bash
make app.check
make app.test
make app.test.api-paths
make app.test.integration.smoke
```

最终结果以本单元提交前的命令输出为准，不在本文维护滚动进度状态。
