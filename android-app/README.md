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
- Room / DataStore / Keystore 后续接入
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
│       │   ├── feature/     # Auth / Chat / Contacts / Settings
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
```

说明：

- Android Emulator 访问宿主机 API 使用 `10.0.2.2:8010`。
- JVM 单测不需要启动 API。
- 如需用真实认证 API 构建调试包，可传 `ANDROID_APP_USE_REMOTE_AUTH=true`；Emulator 访问宿主 API 默认使用 `10.0.2.2:8010`。
- `connected-test` 和 `smoke.emulator` 需要本机已有可用 Android Emulator。
- `connected-test` 当前覆盖 Compose 登录 smoke 和 Room in-memory DAO/Repository。
- 覆盖率报告输出到 `android-app/app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html`。

## 文档

- `android-app/docs/architecture.md`
- `android-app/docs/flutter-parity-scope.md`
- `android-app/docs/full-migration-task-tree.md`
- `docs/plans/2026-07-04-002-feat-android-app-native-migration-plan.md`
