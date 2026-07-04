---
title: "feat: Migrate Flutter app functionality to native Android"
type: feat
status: active
date: 2026-07-04
---

# feat: Migrate Flutter app functionality to native Android

## 目标

新增 `android-app` 模块，把 Flutter `app/` 的现有功能逻辑迁移到 Android 原生实现。Flutter `app/` 保留，不做删除或降级。

## 官方架构基线

已按 Android 官方架构文档确认方向：现代 Android App 应采用分层架构、UI 层状态持有者、单向数据流、Repository/DataSource、Coroutines/Flow 和依赖注入；Compose App 中 DataStore/本地数据操作应放在数据层，由 ViewModel 暴露 `StateFlow` 给 UI 订阅。

本模块采用：

- Kotlin-only，不写 Java 业务代码。
- Jetpack Compose + Material 3。
- Single Activity。
- MVVM / UDF：Composable 只渲染 UI 和派发事件，ViewModel 持有 UI 状态。
- Repository/DataSource：后续接入真实 HTTP、WebSocket、Room、DataStore、文件缓存和通知。
- Coroutines + Flow / StateFlow。
- Room：消息、会话、联系人、群、配置等结构化缓存。
- DataStore：非敏感偏好。
- Android Keystore / Jetpack Security：Token 与敏感会话数据。
- 测试：JVM 单测、Compose instrumented test、Jacoco 覆盖率报告。

## 范围

- 认证：普通账号密码注册、登录、登出和启动态恢复；邮箱登录/注册关闭，后续可由后台配置恢复。
- 聊天：会话列表、消息列表、文本消息、pending/失败重试、已读、未读、置顶、免打扰、引用、reaction、搜索。
- 联系人：搜索、好友申请、处理申请、联系人详情、私聊入口。
- 群：建群、设置、成员、管理员、禁言、规则、日志、入群申请、解散/退出。
- 媒体：图片、视频、文件、语音、头像、附件缓存、对象存储 mock 直传。
- 表情/贴纸：内置 emoji、表情包、贴纸管理、资源缓存。
- 设置：个人资料、账号安全、协议文档、反馈、配置、版本检查、更新提示。
- Push/通知：本地通知、FCM/APNs 兼容策略、通知导航；需要真机或云凭据的验收项跳过并记录。

## 当前阶段执行切片

第一切片先完成可构建、可测试、可在本机 Android Studio Emulator 启动的原生基座：

- Gradle Android 工程。
- Compose App Shell。
- 普通账号密码注册/登录 UI。
- Chat / Contacts / Settings 三个主 Tab。
- In-memory Repository 作为本地模拟数据层，便于 UI、ViewModel、覆盖率先闭环。
- 单元测试与 Jacoco 覆盖率入口。
- Android Emulator connected test 入口。

后续切片按 `android-app/docs/full-migration-task-tree.md` 执行，把 In-memory 数据源逐步替换/补齐为真实 HTTP/WS/Room/DataStore 实现，并做 H5/API/Android 联调。

## 非目标

- 不移除 Flutter `app/`。
- 不恢复 Google/Apple 登录。
- 不依赖真实邮箱验证码。
- 不访问线上对象存储；本地测试走 Compose `external-mock`。
- 不把 Flutter Widget/Provider 结构逐行翻译成 Android 代码。
- 不在本机 Emulator 上伪造必须真机才能验证的能力。

## 验证

- `make android-app.test.unit`
- `make android-app.coverage`
- `make android-app.build.debug`
- `make android-app.connected-test`
- `make android-app.smoke.emulator`

真机跳过项统一记录到 `android-app/docs/full-migration-task-tree.md`。
