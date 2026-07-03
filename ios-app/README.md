# ios-app

`ios-app` 是 RedCode IM 的原生 iOS 客户端模块，目标是把 Flutter `app/` 的完整功能逻辑逐步迁移为原生 iOS 实现。

当前阶段只建立模块边界、架构方案和目录骨架；暂不手写 `.xcodeproj`。正式工程建议通过 Xcode 创建后接入本目录，或在后续明确选型后使用 XcodeGen/Tuist 生成。

## 当前定位

- 先做 iOS 原生，不影响现有 Flutter `app/`、H5 `h5-app/` 和后端 API。
- H5 继续作为端到端功能验收基准。
- iOS 原生目标是完整覆盖 Flutter 当前功能逻辑；实现方式遵循 iOS 原生开发习惯，不逐行翻译 Dart/Flutter 写法。
- 暂不恢复 Google/Apple 登录；认证主线使用邮箱注册和登录。

## 推荐技术栈

- 语言与 UI：Swift + SwiftUI
- 架构：MVVM + feature modules
- 并发与网络：Swift Concurrency (`async/await`) + `URLSession`
- 本地缓存：SwiftData 优先；如后续需要更强 SQL/全文搜索能力，再评估 SQLite/GRDB
- 依赖管理：Swift Package Manager
- 测试：XCTest + XCUITest

## 目录说明

```text
ios-app/
├── App/                         # iOS App 壳层，后续放 SwiftUI App 入口和组装代码
├── Sources/
│   ├── RedCodeCore/             # 领域模型、错误类型、配置、共享工具
│   ├── RedCodeNetworking/       # API Client、WebSocket、认证请求链路
│   ├── RedCodeStorage/          # SwiftData/缓存/Token Keychain
│   └── RedCodeFeatures/         # Auth、Chat、Contacts、Settings 等 feature
├── Tests/                       # XCTest 单元测试与集成测试
└── docs/
    ├── architecture.md          # 原生 iOS 架构方案
    └── flutter-parity-scope.md  # Flutter 完整功能迁移范围
```

## 设计原则

- 以 `h5-app/` 和 Flutter `app/` 的现有用户流程为 parity 基准。
- 优先复用后端现有 HTTP 和 WebSocket JSON 协议，不在第一阶段引入 protobuf 重构。
- 本地消息缓存语义对齐 Flutter：单房间默认保留最近 200 条消息。
- 原生 iOS 与 Flutter 并行存在，直到功能验收完全通过后再讨论替换和删除策略。

## 计划文档

详细实施方案见：

- `docs/plans/2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`
- `ios-app/docs/flutter-parity-scope.md`
