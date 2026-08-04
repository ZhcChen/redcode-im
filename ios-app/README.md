# ios-app

`ios-app` 是 RedCode IM 2.0 的原生 iOS 客户端主线（Swift + SwiftUI），与
`android-app/` 一起替代已弃用的 Flutter `app/`。

当前阶段已建立 SwiftPM 模块基座和可由 Xcode 打开的 iOS App 工程。后续业务功能继续按任务树逐阶段迁移。

## 当前定位

- Flutter `app/` 已弃用（GPU 兼容层问题，2026-08-04 决策），本模块与
  `android-app/` 是 2.0 唯一移动客户端主线。
- H5 继续作为端到端功能验收基准。
- 版本与最低系统：2.0.0；Deployment Target iOS 15（覆盖 iPhone 6s / SE 第一代 /
  7 / 8 / X 及以后）。
- 实现方式遵循 iOS 原生开发习惯，不逐行翻译 Dart/Flutter 写法。
- 暂不恢复 Google/Apple 登录；当前认证主线使用普通账号密码注册和登录。
- 邮箱注册/登录作为后台配置能力保留，当前开发测试不依赖真实邮箱资源。

## 推荐技术栈

- 语言与 UI：Swift 6 + SwiftUI
- 架构：MVVM + feature modules
- 并发与网络：Swift Concurrency (`async/await`) + `URLSession`
- 本地缓存：GRDB/SQLite（最低系统 iOS 15，SwiftData 不可用）+ Keychain
- 依赖管理：Swift Package Manager
- 测试：XCTest + XCUITest

## 工程规范

- Apple 官方规范优先：Swift、SwiftUI、Swift Package Manager、XCTest/XCUITest、Human Interface Guidelines。
- 新业务代码只使用 Swift，不使用 Objective-C。
- UI 遵循 iOS 原生交互、导航、权限、可访问性与系统控件习惯；Flutter/H5 只作为功能和视觉语言参考。
- 当前本机工具链已确认：Xcode 26.6，Apple Swift 6.3.3。

## 目录说明

```text
ios-app/
├── RedCodeIM.xcodeproj          # iOS App Xcode 工程
├── App/                         # iOS App 壳层，后续放 SwiftUI App 入口和组装代码
├── Sources/
│   ├── RedCodeCore/             # 领域模型、错误类型、配置、共享工具
│   ├── RedCodeNetworking/       # API Client、WebSocket、认证请求链路
│   ├── RedCodeStorage/          # GRDB/SQLite 缓存/Token Keychain
│   └── RedCodeFeatures/         # Auth、Chat、Contacts、Settings 等 feature
├── Tests/                       # XCTest 单元测试与集成测试
└── docs/
    ├── architecture.md          # 原生 iOS 架构方案
    └── flutter-parity-scope.md  # Flutter 完整功能迁移范围
```

## 设计原则

- 以 `im-ui-html/` 设计源、`h5-app/` 与 API 合同为 parity 基准。
- 优先复用后端现有 HTTP 和 WebSocket JSON 协议，不在第一阶段引入 protobuf 重构。
- 本地消息缓存语义对齐 Flutter：单房间默认保留最近 200 条消息。
- 原生双端为唯一客户端主线；Flutter `app/` 已移除，历史实现仅作功能语义参考。

## 测试设备策略

- `ios-app` 默认使用本机 iOS Simulator 做开发、smoke、UI test 与 H5/API 联调验收。
- Simulator 联调时 API/WS 使用 `127.0.0.1` 指向本机 Compose API。
- 不套用 Android 侧 Pixel 8 Pro 优先规则；Pixel 8 Pro 只用于 Android 侧验收。
- 只有 APNs、相机、麦克风、后台通知、签名发布等 Simulator 无法完整覆盖的能力，才单独安排 iPhone 真机验证。

## 本地命令

```bash
make ios-app.check
make ios-app.test.live
make ios-app.smoke.simulator
make ios-app.apns.preflight
make ios-app.smoke.device
make ios-app.smoke.device.local
```

说明：

- `make ios-app.check` 运行 SwiftPM 单元测试并构建 Simulator Debug app。
- `make ios-app.test.live` 会在本机 Compose API 上顺序运行 iOS 认证、WebSocket、聊天互发、好友私聊和群管理 live smoke。
- `make ios-app.smoke.simulator` 会构建、安装并启动到本机 iOS Simulator。
- `make ios-app.apns.preflight` 检查 iPhone 真机、非 loopback API/WS 地址、Admin 真实 APNs provider 配置确认和 API 健康状态；真机验收前需设置 `IOS_APP_API_BASE_URL` / `IOS_APP_WS_URL`，并在 Admin Push 设置完成真实 APNs 配置后设置 `IOS_APNS_PROVIDER_CONFIGURED=1`。
- `make ios-app.smoke.device` 会先执行 APNs 真机预检，再构建、安装并启动到 iPhone 真机；需额外传 `IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID>`，必要时传 `IOS_APP_DEVICE_ID=<设备标识>`。
- `make ios-app.smoke.device.local` 每次运行都会重新检测当前本机局域网 IPv4，并自动生成 `IOS_APP_API_BASE_URL=http://<LAN_IP>:8010` / `IOS_APP_WS_URL=ws://<LAN_IP>:8010/ws`；可用 `IOS_APP_LAN_IP=<LAN_IP>` 显式覆盖。
- 真机调试构建可通过 `IOS_APP_API_BASE_URL` / `IOS_APP_WS_URL` 写入 App Info.plist；真机启动也会通过 `devicectl` 注入 `REDCODE_API_BASE_URL` / `REDCODE_WS_URL`；Xcode scheme 可使用同名变量或兼容的 `API_BASE_URL` / `WS_URL`。
- 本机 Compose API 已启动时，可运行 `cd ios-app && RED_CODE_IOS_LIVE_API_SMOKE=1 swift test --filter AuthAPIClientLiveTests` 验证 iOS 认证客户端对真实 API 的注册、登录和 `/auth/me` 链路。
- 本机 Compose API 已启动时，可运行 `cd ios-app && RED_CODE_IOS_LIVE_WS_SMOKE=1 swift test --filter WebSocketClientLiveTests` 验证 iOS WebSocket 客户端对真实 API 的连接和认证链路。
- 本机 Compose API 已启动时，可运行 `cd ios-app && RED_CODE_IOS_LIVE_CHAT_SMOKE=1 swift test --filter ChatAPIClientLiveTests` 验证 iOS 聊天客户端对真实 `/chats`、建群、文本收发、已读链路。
- 本机 Compose API 已启动时，可运行 `cd ios-app && RED_CODE_IOS_LIVE_FRIEND_SMOKE=1 swift test --filter FriendAPIClientLiveTests` 验证 iOS 好友搜索、申请、接受、好友列表、打开私聊和私聊消息链路。
- 本机 Compose API 已启动时，可运行 `cd ios-app && RED_CODE_IOS_LIVE_ROOM_SMOKE=1 swift test --filter RoomAPIClientLiveTests` 验证 iOS 群创建、成员、设置、置顶、免打扰、管理员、禁言、群规则、日志和解散链路。

## 计划文档

详细实施方案见：

- `docs/plans/2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`
- `ios-app/docs/flutter-parity-scope.md`
- `ios-app/docs/full-migration-task-tree.md`
