# android-app 原生 Android 架构方案

## 总体方向

`android-app` 采用 Android 官方推荐的现代应用架构：Compose UI、ViewModel 状态持有、单向数据流、Repository/DataSource 分层、Coroutines/Flow、可测试的依赖注入。

迁移目标是功能和行为对齐 Flutter `app/`，但实现方式以 Android 原生开发规范为准，不复制 Flutter Widget/Provider 结构。

## 分层

```text
MainActivity / Compose App Shell
  -> Feature Composables
  -> ViewModel / UI State
  -> Repository
  -> DataSource
  -> HTTP / WebSocket / Room / DataStore / Keystore / File Cache
```

## UI 层

- Single Activity。
- Jetpack Compose + Material 3。
- 页面使用 Composable。
- ViewModel 暴露 `StateFlow<UiState>`。
- Composable 使用 lifecycle-aware collection 订阅状态。
- 事件从 UI 派发到 ViewModel，ViewModel 再调用 Repository。

## 数据层

- Repository 是 UI/Domain 访问数据的唯一入口。
- HTTP 和 WebSocket DataSource 对齐后端现有协议。
- Room 保存消息、会话、联系人、群和配置缓存。
- DataStore 保存非敏感偏好。
- Token 和敏感会话数据走 Android Keystore / Jetpack Security。
- 附件、头像、表情资源进入 app cache 目录。

## 当前第一切片

当前已建立 in-memory Repository：

- `InMemoryAuthRepository`
- `InMemoryChatRepository`
- `InMemoryContactsRepository`
- `InMemorySettingsRepository`

它们用于在真实 HTTP/WS/Room 接入前，让 Compose UI、ViewModel、测试覆盖率、Emulator 启动验收先闭环。后续每个真实 DataSource 接入后保留 fake/in-memory 实现用于测试。

## 测试策略

- JVM unit test 覆盖校验、领域模型、Repository、ViewModel。
- Compose instrumented test 覆盖 Emulator 上的关键 UI flow。
- Jacoco 输出覆盖率报告。
- 后续 live smoke 统一接入本机 Docker Compose API；Android Emulator 使用 `10.0.2.2` 访问宿主机。

## 真机跳过策略

以下能力需要真机或云凭据时不在 Emulator 阶段伪造通过：

- FCM 真实 token 与云端投递。
- 相机/麦克风硬件差异补验。
- 后台限制、厂商 ROM、通知点击冷启动差异。
- Play 签名、release 包安装和商店分发链路。

跳过项记录在 `android-app/docs/full-migration-task-tree.md`。
