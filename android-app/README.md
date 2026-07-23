# android-app

`android-app` 是 RedCode IM 的原生 Android 客户端模块，目标是把 Flutter `app/` 的完整功能逻辑迁移为 Android 官方推荐架构实现。

## 当前定位

- Flutter `app/` 保留，Android 原生模块并行开发。
- 当前测试设备使用用户已启动的 Android Studio Emulator。
- 需要 Android 真机的能力跳过并记录，后续再补验。
- 当前认证主线是普通账号密码注册/登录；邮箱注册/登录、Google/Apple 登录不进入当前测试主线。

## 技术栈

- Kotlin
- Jetpack Compose + Material 3
- Single Activity
- MVVM / Unidirectional Data Flow
- Coroutines + Flow / StateFlow
- Repository / DataSource 分层
- Room / Android Keystore / Preferences DataStore 已接入，真实 Chat/Contacts/Rooms HTTP 数据会写入 Room 缓存
- OkHttp WebSocket JSON client 已接入，支持鉴权、房间订阅、ping、重连和消息/附件 parts/已读/好友申请增量事件处理基线
- JUnit + Compose UI Test + Jacoco coverage

## 目录

```text
android-app/
├── app/
│   └── src/
│       ├── main/java/com/redcode/im/androidapp/
│       │   ├── core/        # 领域模型、配置、校验
│       │   ├── data/        # Repository / DataSource
│       │   ├── di/          # 依赖组装
│       │   ├── feature/     # Auth / Chat / Contacts / Groups / Settings
│       │   ├── realtime/    # WebSocket JSON client
│       │   └── ui/          # Compose theme
│       ├── test/            # JVM 单元测试
│       └── androidTest/     # Emulator instrumented tests
└── docs/
```

## 本地命令

当前模块优先使用本机可用 Gradle；没有全局 Gradle 时，Makefile 会优先复用本机 Gradle wrapper 缓存，最后回退到 Flutter Android 已存在的 Gradle wrapper，避免仓库重复维护 wrapper：

```bash
make android-app.test.unit
make android-app.lint
make android-app.coverage
make android-app.build.debug
make android-app.connected-test
make android-app.smoke.emulator
make android-app.test.live
make android-app.test.interop
make android-app.test.interop.support
```

说明：

- 默认优先使用已授权的 `Pixel 8 Pro (3A091FDJG001DN)` 真机；无该真机时回退本机 Android Emulator。
- Android Emulator 访问宿主机 API 使用 `10.0.2.2:8010`。
- Android 真机访问宿主机 API 前必须重新检测本机局域网 IPv4，并传 `ANDROID_APP_API_BASE_URL=http://<LAN_IP>:8010`、`ANDROID_APP_WS_URL=ws://<LAN_IP>:8010/ws`；Makefile 默认检测到非 Emulator 设备时会自动生成当前 LAN API/WS，可用 `make android-app.resolve.network` 查看。
- JVM 单测不需要启动 API。
- 如需用真实认证 API 构建调试包，可传 `ANDROID_APP_USE_REMOTE_AUTH=true`；Emulator 访问宿主 API 默认使用 `10.0.2.2:8010`。
- 传 `ANDROID_APP_USE_REMOTE_AUTH=true` 时，Android 原生模块同时启用真实认证、公开设置文档、Chat HTTP、Contacts HTTP、Rooms HTTP、Emoji HTTP 和 WebSocket JSON 基线；Chat/Contacts/Rooms 远端刷新会落 Room 缓存，联系人 UI 已覆盖搜索添加、好友申请处理、联系人详情和私聊入口，群聊 UI 已覆盖建群、群资料、成员、设置、管理员/禁言、群规、日志、退出/解散入口，聊天详情已支持系统文件选择、mock 对象存储直传、附件消息元数据展示、emoji/sticker 面板、贴纸发送、聊天背景和聊天设置；默认仍用本地模拟数据便于无后端 smoke。
- `connected-test` 和 `smoke.emulator` 需要本机已有可用 Android 设备；目标名保留历史命名，真机可通过 `ANDROID_APP_DEVICE=<device-id>` 覆盖。
- `connected-test` 当前覆盖 Compose 登录/协议门禁 smoke、聊天扩展 UI smoke、权限恢复 banner、语音播放 UI smoke、Room in-memory DAO/Repository、Android Keystore 加密会话存储、DataStore 协议/聊天偏好。
- `android-app.test.live` 需要本机 Compose API 已启动，覆盖 Android 数据层注册、建群、双向文本互发、附件签名/mock 直传/commit/发送/可见性/下载 URL、已读、好友申请/接受、私聊消息、群管理和表情列表 fallback smoke。
- `android-app.test.interop` 会自动启动并等待 Compose API dev 栈，串联 `h5-app.test.live`、`android-app.test.live` 与 `android-app.test.interop.support`，用于 H5/API/Android 聊天、富媒体附件、好友、群管理、表情列表/缓存、头像缓存、权限降级和语音播放状态机互通验收。
- `android-app.test.interop.support` 不依赖 API，定向覆盖头像缓存、表情资源缓存、权限恢复状态机和语音播放 ViewModel 状态机；失败时查看 `app/build/reports/tests/testDebugUnitTest/index.html` 和 `app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html`。
- WebSocket JVM 单测覆盖 URL 规范化、auth/ping、join/leave、typing guard、服务端错误、断开清理、失败重连和增量事件分发；protobuf 二进制帧在后续切片补齐。
- 覆盖率报告输出到 `android-app/app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html`。

## 文档

- `android-app/docs/architecture.md`
- `android-app/docs/flutter-parity-scope.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/plans/2026-07-04-002-feat-android-app-native-migration-plan.md`
