---
title: "feat: Add native iOS app module"
type: feat
status: active
date: 2026-07-02
deepened: 2026-07-02
---

# feat: Add native iOS app module

## Overview

新增 `ios-app/` 原生 iOS 客户端模块，用 Swift/SwiftUI 逐步复刻 Flutter `app/` 的 iOS 侧核心能力。迁移期间 `app/`、`h5-app/` 和 `ios-app/` 并行存在；H5 继续作为后端联调和功能验收基准，iOS 原生按阶段补齐核心流程后再讨论替换 Flutter iOS。

## Problem Frame

当前移动端主实现是 Flutter `app/`。用户希望后续转为原生开发，并先从 iOS 开始。由于团队对原生 iOS 不熟，本计划先建立模块边界、技术选型和迁移路径，避免直接手写大体量 iOS 工程导致维护风险。

## Requirements Trace

- R1. 创建 `ios-app/` 模块目录，形成独立原生 iOS 工作区边界。
- R2. 明确 iOS 原生技术栈和架构规范，降低团队学习成本。
- R3. 迁移目标以 Flutter `app/` 和 H5 `h5-app/` 的现有流程为 parity 基准。
- R4. 认证主线使用邮箱注册/登录，不做 Google/Apple 登录。
- R5. 本地消息缓存语义对齐现有 Flutter：按 room 缓存，默认每房间保留最近 200 条。
- R6. 第一阶段不影响现有 Flutter/H5/API 联调与测试入口。

## Scope Boundaries

- 不迁移 Android 原生。
- 不删除或替换现有 Flutter `app/`。
- 不改变后端 API 和 WebSocket 协议。
- 不恢复 Google/Apple 登录。
- 不在第一阶段接入 APNs/FCM Push；Push 后置。
- 不手写 `.xcodeproj`；正式工程由 Xcode 创建，或后续明确采用 XcodeGen/Tuist 后生成。

## Context & Research

### Relevant Code and Patterns

- `app/lib/core/config/environment.dart`：Flutter 端 API/WS 环境配置入口。
- `app/lib/features/auth/login_page.dart`、`app/lib/features/auth/data/auth_repository.dart`：邮箱认证流程参考。
- `app/lib/core/storage/token_storage.dart`：Token 存储语义参考，iOS 原生应落到 Keychain。
- `app/lib/core/services/websocket_service.dart`：Flutter WebSocket 主链路参考。
- `app/lib/core/services/message_service.dart`、`app/lib/core/services/friend_service.dart`、`app/lib/core/services/room_service.dart`、`app/lib/core/services/settings_service.dart`：HTTP service parity 参考。
- `app/lib/core/storage/message_storage.dart`：本地消息缓存语义参考，当前按 room 保留最近 200 条。
- `h5-app/README.md`：当前 H5 parity 范围和真实后端 smoke 入口参考。
- `docs/reference/testing/README.md`：全栈测试入口和 API/H5 联调规范参考。

### Institutional Learnings

- 仓库采用 CE 工作流，计划文档进入 `docs/plans/`，实现与经验沉淀后续进入 `docs/solutions/`。
- 本机 API/测试栈要求 Compose-first；iOS 原生联调时应复用 API Compose 环境，避免临时本机散装依赖。
- App 设备验收规则已有优先级：Pixel 8 Pro 优先，否则本机 iOS Simulator；本计划新增的是原生 iOS 模块，iOS smoke 阶段直接以本机 iOS Simulator 为默认验证目标。

### External References

- Apple SwiftUI 官方文档：SwiftUI app 使用 `App` 协议声明入口，使用 `WindowGroup` 声明根 scene；现代导航使用 `NavigationStack` 和 path/destination 模型。
- Apple SwiftData 官方文档：SwiftData 通过 `ModelContainer` 管理 schema/storage，通过 `ModelContext` fetch/insert/delete/save，支持迁移计划。
- Swift Package Manager 官方文档：`Package.swift` 用 products、dependencies、targets、testTarget 组织库、依赖和测试。

## Key Technical Decisions

- SwiftUI-first：作为主 UI 框架，适合新 iOS 模块快速建立声明式页面和导航；UIKit 只做必要桥接。
- MVVM + feature modules：团队可以按 Auth、Chat、Contacts、Groups、Settings 分区迁移，避免一次性大重写。
- Swift Concurrency + `URLSession`：HTTP、WebSocket、存储异步流程统一使用原生并发模型，减少第三方依赖。
- SwiftData 优先作为消息/会话/联系人缓存底座：更贴合 SwiftUI 与 Apple 生态；SQLite/GRDB 作为二期高性能或复杂查询备选。
- Swift Package Manager 管理依赖与本地模块：用 local package 拆出 Core、Networking、Storage、Features，减少 App 壳层膨胀。
- Keychain 存 Token：Token 不放普通 UserDefaults，本地认证状态以 Keychain 为准。
- JSON WebSocket 先行：优先复用 H5/后端当前 JSON WS 协议；暂不在 iOS 迁移首期引入 protobuf 协议重构。

## Open Questions

### Resolved During Planning

- 是否立刻替换 Flutter iOS：不替换，先并行开发和验收。
- 是否继续 Google/Apple 登录：不继续，邮箱注册/登录为主。
- 本地消息存储选 SwiftData 还是 SQLite：首期 SwiftData，SQLite/GRDB 作为二期备选。
- 是否立即生成 Xcode 工程：不立即生成，先保留标准模块目录和方案；工程创建/生成在实现阶段明确工具后处理。

### Deferred to Implementation

- iOS 最低系统版本：建议 iOS 17+，但最终要在实现前结合目标用户设备决定；若要求 iOS 16，需要把 Observation/SwiftData 使用策略重新评估。
- Xcode 工程管理方式：标准 Xcode project、XcodeGen、Tuist 三选一，等进入实际实现前再定。
- WebSocket 事件覆盖清单：需实现时对齐 `api/src/`、Flutter 和 H5 的实际事件处理。
- SwiftData schema 细节和迁移计划：等第一版模型落地后再形成 migration plan。

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
ios-app/App
  -> RedCodeFeatures
       -> Auth / Chat / Contacts / Groups / Settings
  -> RedCodeCore
       -> domain models / config / shared errors
  -> RedCodeNetworking
       -> HTTP API client / WebSocket client
  -> RedCodeStorage
       -> Keychain / SwiftData / media cache
  -> api + local cache
```

关键原则：App 壳层只做生命周期、依赖注入和根导航；feature 层处理页面与 ViewModel；网络和存储独立成模块，便于 XCTest 覆盖。

## Implementation Units

- [ ] **Unit 1: iOS 模块骨架与规范文档**

**Goal:** 创建 `ios-app/` 模块边界和基础说明，明确后续原生 iOS 迁移方向。

**Requirements:** R1, R2, R6

**Dependencies:** None

**Files:**
- Create: `ios-app/README.md`
- Create: `ios-app/docs/architecture.md`
- Create: `ios-app/App/.gitkeep`
- Create: `ios-app/Sources/RedCodeCore/.gitkeep`
- Create: `ios-app/Sources/RedCodeNetworking/.gitkeep`
- Create: `ios-app/Sources/RedCodeStorage/.gitkeep`
- Create: `ios-app/Sources/RedCodeFeatures/.gitkeep`
- Create: `ios-app/Tests/.gitkeep`
- Create: `docs/plans/2026-07-02-002-feat-ios-app-native-migration-plan.md`

**Approach:**
- 先建立目录和说明文档，不生成工程文件。
- 文档说明技术栈、模块边界、与 Flutter/H5/API 的关系。

**Patterns to follow:**
- `h5-app/README.md` 的模块说明风格。
- `docs/plans/` 现有 CE 计划命名规范。

**Test scenarios:**
- Test expectation: none -- 该单元只创建文档和目录骨架，无可执行行为。

**Verification:**
- `ios-app/` 被 Git 跟踪。
- README 和架构文档能解释模块定位、技术栈和不做事项。

- [ ] **Unit 2: Xcode 工程与 local packages 接入**

**Goal:** 建立可在 Xcode 打开、构建和运行的原生 iOS App 工程，并接入本地 SPM 模块。

**Requirements:** R1, R2, R6

**Dependencies:** Unit 1

**Files:**
- Create/Modify: `ios-app/App/`
- Create/Modify: `ios-app/Package.swift` 或后续选型对应工程配置
- Test: `ios-app/Tests/RedCodeCoreTests/`
- Test: `ios-app/Tests/RedCodeNetworkingTests/`
- Test: `ios-app/Tests/RedCodeStorageTests/`

**Approach:**
- 工程管理方式优先选择团队最容易维护的标准 Xcode project；如需要可重复生成，再评估 XcodeGen/Tuist。
- SPM local package 至少拆分 Core、Networking、Storage，Features 可按复杂度决定是否单独 target。
- App 壳层只依赖模块公开接口，不把业务全部写进 App target。

**Patterns to follow:**
- Swift Package Manager 官方 products/targets/testTarget 组织方式。
- `h5-app/src/services/` 和 Flutter service 的模块边界。

**Test scenarios:**
- Happy path: 新工程在本机 iOS Simulator 构建成功并显示启动页。
- Happy path: Core package 的简单模型/配置单元测试可独立运行。
- Error path: 无 API 地址配置时，App 显示可诊断的环境配置错误，而不是崩溃。

**Verification:**
- 工程可在 Xcode 打开。
- iOS Simulator 可启动空壳 App。
- package 单元测试可运行。

- [ ] **Unit 3: Auth 与 App Shell**

**Goal:** 实现邮箱注册、邮箱登录、Token 存储、启动态恢复和登出。

**Requirements:** R3, R4, R6

**Dependencies:** Unit 2

**Files:**
- Create/Modify: `ios-app/Sources/RedCodeFeatures/`
- Create/Modify: `ios-app/Sources/RedCodeNetworking/`
- Create/Modify: `ios-app/Sources/RedCodeStorage/`
- Test: `ios-app/Tests/RedCodeNetworkingTests/`
- Test: `ios-app/Tests/RedCodeStorageTests/`
- Test: `ios-app/Tests/RedCodeFeaturesTests/`
- UI Test: `ios-app/Tests/RedCodeAppUITests/`

**Approach:**
- 请求路径和 payload 对齐 Flutter/H5 当前邮箱登录注册实现。
- Token 存入 Keychain；启动时读取 Token 并校验/恢复 session。
- App Shell 根据认证态切换 Auth flow 与主界面。

**Patterns to follow:**
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/core/storage/token_storage.dart`
- `h5-app/README.md` 中邮箱注册后自动登录语义。

**Test scenarios:**
- Happy path: 输入合法邮箱和密码注册成功后自动进入主界面。
- Happy path: 输入已注册邮箱和密码登录成功后 Token 写入 Keychain。
- Happy path: App 重启后可从 Keychain 恢复登录态。
- Edge case: 邮箱为空、密码为空或格式错误时，按钮不可提交或显示本地校验错误。
- Error path: 后端返回账号/密码错误时，显示错误并保持在登录页。
- Error path: Keychain 读取失败时，清理本地 session 并回到登录页。
- Integration: 登出后清理 Token，并断开 WebSocket/清空内存态。

**Verification:**
- iOS Simulator 可完成注册、登录、重启恢复和登出闭环。

- [ ] **Unit 4: Chat 列表、本地缓存与 WebSocket 主链路**

**Goal:** 实现会话列表、本地缓存优先加载、后台刷新和 WebSocket 认证订阅。

**Requirements:** R3, R5, R6

**Dependencies:** Unit 3

**Files:**
- Create/Modify: `ios-app/Sources/RedCodeFeatures/`
- Create/Modify: `ios-app/Sources/RedCodeNetworking/`
- Create/Modify: `ios-app/Sources/RedCodeStorage/`
- Test: `ios-app/Tests/RedCodeStorageTests/`
- Test: `ios-app/Tests/RedCodeNetworkingTests/`
- Test: `ios-app/Tests/RedCodeFeaturesTests/`

**Approach:**
- SwiftData 保存会话摘要和消息摘要。
- 启动主界面时先读本地缓存，再请求 `/chats` 同步。
- WebSocket 登录后连接、认证并订阅当前需要的 room。
- WebSocket 事件更新内存态和 SwiftData 缓存。

**Patterns to follow:**
- `app/lib/features/chat/chat_list_page.dart`
- `app/lib/features/chat/providers/chat_provider.dart`
- `app/lib/core/services/websocket_service.dart`
- `h5-app/README.md` 中聊天列表与 WebSocket 主链路说明。

**Test scenarios:**
- Happy path: 本地已有会话缓存时，进入主界面先显示缓存，再被后端最新数据刷新。
- Happy path: WebSocket 收到新消息事件后，会话列表最新消息、时间和未读数更新。
- Edge case: 本地无缓存时显示空态或骨架屏，并在 API 返回后更新。
- Error path: `/chats` 请求失败时，保留本地缓存并显示非阻塞错误状态。
- Error path: WebSocket 断开后进入重连状态，重连成功后重新认证和订阅。
- Integration: HTTP 刷新和 WebSocket 事件同时到达时，不重复插入同一消息。

**Verification:**
- 真实后端环境下，会话列表能加载、刷新并响应实时消息。

- [ ] **Unit 5: Chat 详情与文本消息发送**

**Goal:** 实现聊天详情页、历史消息、本地 pending、文本发送、失败重试和服务端回包替换。

**Requirements:** R3, R5, R6

**Dependencies:** Unit 4

**Files:**
- Create/Modify: `ios-app/Sources/RedCodeFeatures/`
- Create/Modify: `ios-app/Sources/RedCodeNetworking/`
- Create/Modify: `ios-app/Sources/RedCodeStorage/`
- Test: `ios-app/Tests/RedCodeStorageTests/`
- Test: `ios-app/Tests/RedCodeFeaturesTests/`
- UI Test: `ios-app/Tests/RedCodeAppUITests/`

**Approach:**
- 打开详情页时本地消息优先，后台加载历史消息并合并。
- 发送文本消息时先生成本地 pending，再请求后端；成功后用服务端消息替换 pending。
- 按 room 修剪本地消息，默认保留最近 200 条。

**Patterns to follow:**
- `app/lib/features/chat/chat_detail_page_v2.dart`
- `app/lib/core/storage/message_storage.dart`
- `h5-app/README.md` 中聊天详情与文本发送说明。

**Test scenarios:**
- Happy path: 打开会话详情后先显示本地消息，后台补齐历史消息。
- Happy path: 发送文本成功后 pending 状态变为已发送，并保留服务端 message id。
- Happy path: 收到 WebSocket 服务端回包时，本地 pending 被替换而不是重复显示。
- Edge case: 单个 room 超过 200 条缓存时，保留最近 200 条。
- Error path: 发送失败时消息进入失败状态，可点击重试。
- Error path: 历史消息加载失败时，已缓存消息不丢失。
- Integration: A 设备发送消息后，B 设备或 H5 能实时收到，iOS 端刷新状态一致。

**Verification:**
- iOS Simulator 与 H5 可在同一后端环境互发文本消息。

- [ ] **Unit 6: Contacts、Groups、Settings parity**

**Goal:** 补齐好友、联系人、群聊基础流程和设置页，形成可验收 MVP。

**Requirements:** R3, R6

**Dependencies:** Unit 5

**Files:**
- Create/Modify: `ios-app/Sources/RedCodeFeatures/`
- Create/Modify: `ios-app/Sources/RedCodeNetworking/`
- Create/Modify: `ios-app/Sources/RedCodeStorage/`
- Test: `ios-app/Tests/RedCodeFeaturesTests/`
- UI Test: `ios-app/Tests/RedCodeAppUITests/`

**Approach:**
- 联系人：列表、搜索用户、发送好友申请、处理好友申请、打开私聊。
- 群聊：选择联系人建群、基础群设置、退出/解散。
- 设置：个人资料、账号安全、协议文档、关于、反馈、登出。
- 页面和交互优先对齐 Flutter/H5，不在首版扩展新产品行为。

**Patterns to follow:**
- `app/lib/features/contacts/`
- `app/lib/features/chat/create_group_page.dart`
- `app/lib/features/chat/group_settings_page.dart`
- `app/lib/features/settings/`
- `h5-app/README.md` 中联系人、群聊、设置范围。

**Test scenarios:**
- Happy path: 搜索用户并发送好友申请成功。
- Happy path: 处理好友申请后联系人列表出现新好友。
- Happy path: 选择多个联系人创建群聊后进入群聊详情。
- Happy path: 修改昵称后本地 session 和页面展示同步更新。
- Error path: 搜索用户失败、好友申请失败、建群失败时显示错误且不污染本地缓存。
- Integration: H5 创建好友/群聊状态后，iOS 刷新可见；iOS 侧变更 H5 可见。

**Verification:**
- iOS 与 H5 在联系人、群聊、设置主流程上行为一致。

## System-Wide Impact

- **Interaction graph:** `ios-app` 新增独立客户端，不改变 `api/`、`app/`、`h5-app/` 的接口；联调会复用 API Compose 环境。
- **Error propagation:** Networking 层负责把 HTTP/WS/超时错误转换为领域错误，Feature ViewModel 决定 UI 展示和重试策略。
- **State lifecycle risks:** Token、WebSocket session、SwiftData cache 和内存 store 需要在登录、登出、重连、App 冷启动之间保持一致。
- **API surface parity:** 邮箱 Auth、Chats、Messages、Friends、Rooms、Settings 接口需要与 Flutter/H5 保持一致。
- **Integration coverage:** 单元测试不足以证明 parity；必须用 iOS Simulator + H5 + API Compose 做真实后端联调。
- **Unchanged invariants:** 后端接口、H5 验收入口、Flutter 现有 app 流程在迁移初期保持不变。

## Risks & Dependencies

- SwiftData 最低系统版本和成熟度风险：先建议 iOS 17+，若需要 iOS 16 兼容，在实现前重新评估持久化方案。
- Xcode 工程维护风险：不手写 `.xcodeproj`；由 Xcode 创建或后续采用生成工具。
- Parity 漏洞风险：每个 feature 都对齐 Flutter/H5 文件和真实后端 smoke。
- WebSocket 状态复杂度风险：重连、订阅、重复事件、pending 替换必须单独测试。
- 本地缓存一致性风险：消息去重、room 修剪、登出清理、失败重试需要存储层测试覆盖。
- 团队 iOS 学习成本：文档先解释技术选择，模块拆小，首期不引入过多第三方库。

## Documentation / Operational Notes

- `ios-app/README.md`：模块定位、技术栈、目录和第一阶段原则。
- `ios-app/docs/architecture.md`：原生 iOS 架构方案。
- 后续实现完成后需要在 `docs/reference/testing/README.md` 增加 `ios-app` 构建、单测、Simulator smoke 与 H5 联调入口。
- 若后续沉淀 SwiftData/Keychain/WebSocket 实现经验，应写入 `docs/solutions/`。

## Sources & References

- Related code: `app/lib/core/config/environment.dart`
- Related code: `app/lib/features/auth/data/auth_repository.dart`
- Related code: `app/lib/core/storage/token_storage.dart`
- Related code: `app/lib/core/services/websocket_service.dart`
- Related code: `app/lib/core/storage/message_storage.dart`
- Related code: `h5-app/README.md`
- Related docs: `docs/reference/testing/README.md`
- External docs: Apple SwiftUI documentation via Context7 (`/websites/developer_apple_swiftui`)
- External docs: Apple SwiftData documentation via Context7 (`/websites/developer_apple_swiftdata`)
- External docs: Swift Package Manager documentation via Context7 (`/swiftlang/swift-package-manager`)
