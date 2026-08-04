# 测试工作流

## 1. 原则

RedCode IM 的测试策略调整为：

- **模块自测为主**
- **`tests/` 只负责 api Compose 测试栈 + 仓库级 tooling 守护**
- **跨模块 smoke 只保留少量必要链路**

不要再把 `tests/` 当成“全项目统一测试中心”。

---

## 2. 目录边界

### 模块内测试
- `api/tests/`：Rust 集成测试（axum oneshot 进程内 + 共享 harness `api/tests/support`）
- `android-app/app/src/test/`：Android JVM 单元测试（Kotlin/Compose）
- `ios-app/Tests/`：iOS SwiftPM 单元测试（XCTest）
- `admin/playwright-tests/`：Admin E2E / smoke
- `desktop/test/`：Desktop 模块测试
- `website/test/`：Website 模块测试

### `tests/` 目录
- `tests/docker-compose.test.yml`：api Compose 测试栈（pg / redis / external-mock / rust-tests / api-smoke；PG/Redis/external-mock 不映射宿主端口）
- `tests/go/tooling/`：仓库级 Makefile / 脚本守护测试
- `tests/mocks/external/`：第三方依赖（S3-compatible / IPInfo / FCM / APNs）mock

---

## 3. 常用命令

### API 自测（Compose-first）
```bash
make api.test
```

API 单元、集成、smoke 均通过 `tests/docker-compose.test.yml` 在 Docker Compose 内执行。不要把宿主机 `cargo test` 作为默认验收路径。
外部依赖 mock 服务自测可单独运行：

```bash
make tests.mocks.external
```

### 原生移动端自测
```bash
make android-app.check    # unit + lint + debug APK
make android-app.test.unit
make android-app.lint
make ios-app.check        # SwiftPM unit + Simulator build
make ios-app.test
```

当前 2.0 以原生双端（`android-app/` + `ios-app/`）作为唯一正式移动端主线；Flutter
`app/` 已于 2026-08-04 废弃，其历史验收记录保留在 `docs/reviews/`。

原生双端默认使用本机 iOS Simulator 进行设备验收，Android 侧默认使用本机 Android
Emulator。相机、麦克风、APNs、后台通知等 Simulator/Emulator 无法完整验证的能力，单独
安排 iPhone 真机验证。每次真机执行前，必须先重新检测当前本机局域网 IP，并据此生成
`API_BASE_URL=http://<LAN_IP>:8010` 与 `WS_URL=ws://<LAN_IP>:8010/ws`，不要复用历史
IP；切换到本机 iOS Simulator 时使用 `127.0.0.1`。

真实后端 smoke 使用原生端 live 入口：

```bash
# Android 真实后端聊天/好友 smoke（需 api dev 就绪）
make android-app.test.live

# iOS 真实后端 smoke（认证 + WS + 聊天互发，需 api dev 就绪）
make ios-app.test.live

# iOS Simulator 构建 / XCUITest / 安装启动
make ios-app.build.simulator
make ios-app.ui-test
make ios-app.smoke.simulator

# Android 设备相关
make android-app.connected-test
make android-app.smoke.emulator
```

### IM UI 设计源回归

```bash
make im-ui.install
make im-ui.test
make im-ui.test.visual
```

说明：
- `im-ui-html` 生产预览不依赖业务后端；测试依赖使用 Bun `1.3.11` 与 Chrome for Testing。
- `make im-ui.test` 会按固定端口规则先停止 `8020` 占用，再运行 43 条正式路由在三种设备外壳上的 Console、横向溢出和关键交互回归。
- 三种外壳为 `iPhone 12 Pro`、`iPhone 16 Pro Max`、`Pixel 8 Pro`，由桌面预览工具栏切换，不等同于浏览器原生设备描述符。
- `make im-ui.test.visual` 按 8 条高风险路由生成 24 张截图到 `im-ui-html/test-results/visual-review/`，只供人工评审，不提交、不做像素断言。
- Chrome 模拟无法覆盖系统软键盘、真实安全区、触觉反馈和硬件权限，相关能力仍按原生
  双端设备验收顺序补验。

### 历史 Flutter / Patrol 验收

Flutter `app/` 已于 2026-08-04 废弃，`make app.test.*`、Patrol 与
`app/scripts/` 相关入口均已下线。历史验收记录（U8 设备验收、双端联调、附件链路等）
保留在 `docs/reviews/`，作为原生双端功能迁移的验收基线，不再提供可复跑入口。

### H5 App 自测
```bash
make h5-app.check
make h5-app.test.unit
make api.up
make api.wait
make h5-app.test.live
make h5-app.test.e2e
```

说明：
- `h5-app` 以 `im-ui-html/` 设计源与原生双端为参考，作为 Web 形态与 API 联调验收入口。
- H5 dev server 固定端口为 `8016`，API 固定端口为 `8010`。
- 本地联调依赖由 `api/docker/dev/docker-compose.yml` 创建；PostgreSQL、Redis、external-mock 随 API dev 栈启动。
- 本地对象存储、Push 和 IPInfo 均走 `external-mock`，H5 媒体、头像和附件联调不得访问线上对象存储、FCM 或 APNs。
- 当前 H5 默认普通账号密码注册/登录；邮箱注册/登录只作为后台配置能力保留，不要求真实邮箱验证码二次验证。
- `h5-app.check` 执行 `vue-tsc --noEmit`。
- `h5-app.test.unit` 执行 mock 模式 Vitest，覆盖 service、Pinia store、本地 SQLite/IndexedDB/OPFS worker adapter、FTS5/LIKE 搜索降级、Cache API 清理策略、页面状态和组件。
- `h5-app.test.live` 需要本机 Compose API 已启动，覆盖普通账号注册/登录、`/auth/me`、资料更新、用户头像上传、settings、好友搜索、建群、群头像上传、文本消息、已读、聊天列表、H5/iOS-compatible HTTP 合同和富媒体 mock 对象存储链路。
- `h5-app.test.e2e` 需要本机 Compose API 已启动，会用 Playwright 启动或复用 `http://127.0.0.1:8016`，默认使用本机 Chrome channel；覆盖 UI 注册登录、进入群聊、发送消息、刷新后缓存恢复、本地消息搜索结果跳转、群头像上传、群设置置顶、好友申请闭环、个人头像上传。
- H5 媒体、附件和头像上传依赖 `external-mock`；该 mock 已支持浏览器 direct upload 所需 CORS preflight，E2E 不访问线上对象存储。
- H5 浏览器数据库正式运行口径为 wa-sqlite OPFS worker 优先，降级顺序为 wa-sqlite IndexedDB VFS、IndexedDB persisted shim、Memory；旧浏览器降级不得导致登录、聊天或基础缓存白屏。

### E2EE 专项测试入口

```bash
make e2ee-core.test              # 共享协议核心 host 测试（OpenMLS 状态机）
make e2ee-core.check.targets     # iOS / Android / WASM 四目标构建
make h5-app.test.unit            # 已含 E2EE 安全存储与身份信任单元测试
make h5-app.test.e2ee.live       # 双账号 E2EE 真实后端联调（需服务端显式启用 E2EE）
make h5-app.test.e2e             # 浏览器 smoke（含 WASM 核心初始化/损坏状态校验）
```

说明：
- H5 E2EE 单元测试位于 `h5-app/test/e2ee-secure-state-storage.test.ts`、
  `h5-app/test/e2ee-identity-trust.test.ts`，默认并入 `h5-app.test.unit`。
- `h5-app.test.e2ee.live` 前必须确认 runtime 为显式测试配置；无论成功或失败，
  结束后读取 `/settings/general` 证明已恢复 `persist/plaintext`。不得把 runtime
  自动切换嵌入普通 unit、build、commit hook 或默认 CI 链。
- 原生双端（`android-app/` / `ios-app/`）E2EE 协议接入尚未落地，原生 E2EE 验收
  由原生 E2EE 专项补齐；当前原生测试不含 E2EE 协议用例。

从零联调顺序：

```bash
make api.up
make api.wait
make h5-app.install
make h5-app.up
make h5-app.wait
make h5-app.check
make h5-app.test.unit
make h5-app.test.live
make h5-app.test.e2e
```

### Admin 自测
```bash
cd admin && bun run type:check
cd admin && bun run test:e2e:routes
```

### Desktop / Website 自测
```bash
cd desktop && bun run test
cd website && bun run test
```

Desktop 真实后端 smoke 默认不纳入 `desktop.test.unit`，避免日常单测依赖本机 API。需要联调时先启动 API，再显式开启：

```bash
make desktop.test.live

# 或直接运行
cd desktop
DESKTOP_LIVE_BACKEND_ENABLED=true \
DESKTOP_API_BASE_URL=http://127.0.0.1:8010 \
DESKTOP_WS_URL=ws://127.0.0.1:8010/ws \
bun run test -- test/api/live-backend-smoke.test.ts
```

该 smoke 覆盖 `/healthz`、账号密码注册/登录、内部邮箱占位和 WebSocket open。

### API 集成测试（Rust 原生，Compose 容器内执行）
```bash
# 单元测试（rust-tests 容器内 cargo test --lib）
make api.test.unit

# 集成测试（自动拉起 pg/redis/external-mock，rust-tests 容器内 cargo test --tests）
make api.test.integration

# 默认套：单元 + 集成
make api.test

# 启动 api 容器并在 Compose 网络内跑健康检查
make api.test.smoke

# 编译 smoke / perf 复用的 api debug 二进制
make api.test.build

# 首次运行、Dockerfile 或 external-mock Dockerfile 变更后，显式构建测试镜像
make api.test.images

# 跑完停掉依赖栈
make api.test.deps.down
```

说明：
- 集成测试用 `axum` `oneshot` 进程内打 Router，对 `tests/docker-compose.test.yml` 起的依赖运行；每测试 `CREATE/DROP DATABASE` 独立临时库，`--test-threads=1` 串行。
- `tests/docker-compose.test.yml` 不映射 PostgreSQL / Redis / external-mock 宿主端口；测试容器通过 Compose 服务名访问 `postgres`、`redis`、`external-mock`。
- 测试栈只启动 1 个 Redis；`REDIS_SESSION_URL` / `REDIS_PUBSUB_URL` / `REDIS_CACHE_URL` 均指向该 Redis。
- 涉及对象存储 / 推送 / 地理的用例走 `tests/mocks/external` 的 `external-mock`；测试环境禁止使用线上 S3 兼容对象存储、FCM 或 APNs endpoint。
- `api.test.smoke` 与 `api.perf.*` 会先通过 `api.test.build` 在 `rust-tests` 容器内完成编译，再让受限 `api` 容器直接运行 `/app/target/debug/redcode-im-api`；因此 `API_SERVICE_CPUS` / `API_SERVICE_MEMORY` 表示 API 运行时资源，不混入 Rust 编译开销。
- 迁移一致性校验保留在 `api/tests/database_migration_smoke.rs`。

### API 性能测试（Compose-first）
```bash
# 压测工具轻量自检
make api.perf.smoke

# 单场景基线
make api.perf.healthz
make api.perf.readyz
make api.perf.auth
make api.perf.ws.connect
make api.perf.ws.join
make api.perf.ws.broadcast

# 顺序执行 healthz / readyz / auth-register-login
make api.perf

# 使用 release 二进制执行同样的性能基线（Compose 内 cargo build --release）
make api.perf.release
make api.perf.release.small
make api.perf.release.standard
make api.perf.release.large
make api.perf.release.healthz
make api.perf.release.readyz
make api.perf.release.auth
make api.perf.release.ws.connect
make api.perf.release.ws.join
make api.perf.release.ws.broadcast

# 停止性能测试栈，保留报告与 cargo cache
make api.perf.down
```

说明：
- 压测容器 `api-perf`、API、PostgreSQL、Redis、external-mock 均在 `tests/docker-compose.test.yml` 内运行。
- `api-perf` 在 Compose 网络内访问目标 API：debug 基线为 `http://api:8010`，release 基线为 `http://api-release-local:8010`；PG/Redis/external-mock 不映射宿主机端口。
- 性能入口会显式清理另一种 API 运行容器，并使用 `docker compose run --no-deps api-perf` 运行压测容器，避免 debug / release API 同时运行污染固定资源基线。
- `api.perf.*` 默认运行 debug 二进制；`api.perf.release.*` 会先在 `rust-tests` 容器内执行 `cargo build --release --bin redcode-im-api`，再让受限 `api-release-local` 容器运行 `/app/target/release/redcode-im-api`，避免 Docker Hub metadata 限流影响本地基线。
- 默认场景输出 JSON 到 `tests/perf/reports/`，该目录不纳入版本控制；需要对外沉淀时整理到 `docs/reports/performance/`。
- `make api.perf.*` 默认把 API 限制为 `2 CPU / 1g`，同时把 PostgreSQL / Redis 放大到 `POSTGRES_PERF_CPUS=4.0`、`POSTGRES_PERF_MEMORY=4g`、`REDIS_PERF_CPUS=2.0`、`REDIS_PERF_MEMORY=1g`，并设置 `DATABASE_MAX_CONNECTIONS=80`、`DATABASE_MIN_CONNECTIONS=8`，用于尽量观察 API 侧能力而不是中间件瓶颈。
- 固定硬件档位入口：
  - `make api.perf.release.small`：API `1 CPU / 512m`，PG pool `40 max / 4 min`
  - `make api.perf.release.standard`：API `2 CPU / 1g`，PG pool `80 max / 8 min`，默认对外指标口径
  - `make api.perf.release.large`：API `4 CPU / 2g`，PG pool `160 max / 16 min`
- 性能入口默认设置 `API_PERF_BCRYPT_COST=8`（传入 API 容器为 `BCRYPT_COST=8`），用于测注册/登录链路结构性能；生产和普通测试默认仍是 `BCRYPT_COST=12`。如果要测生产密码成本，使用 `API_PERF_BCRYPT_COST=12 make api.perf.auth`。
- 当前内置场景：
  - `healthz`：API 框架 / 网络基线。
  - `readyz`：DB / Redis readiness 低频探测，不作为高并发吞吐指标。
  - `auth-register-login`：账号密码注册 + 登录业务链路，每个操作包含 2 个 HTTP 请求。
  - `ws-connect-ping`：预创建账号后，只测 WebSocket 连接、认证、ping/pong。
  - `ws-connect-join`：预创建账号和房间后，只测 WebSocket 连接、认证、订阅房间。
  - `ws-room-broadcast`：预创建账号、房间和订阅连接后，测 REST 发消息 → Redis PubSub → WebSocket 推送到房间订阅者。
- WS 场景的准备阶段写入 JSON 的 `setup_seconds`、`setup_http_requests`、`setup_bytes_read`；核心吞吐和延迟只统计正式窗口，避免 bcrypt 注册登录和房间初始化污染 IM 指标。
- 默认参数：`PERF_DURATION_SECONDS=30`、`PERF_WARMUP_SECONDS=3`；各场景默认并发分别为 `PERF_HEALTHZ_CONCURRENCY=64`、`PERF_READYZ_CONCURRENCY=1`、`PERF_AUTH_CONCURRENCY=4`、`PERF_WS_CONNECT_CONCURRENCY=8`、`PERF_WS_BROADCAST_CLIENTS=16`、`PERF_WS_BROADCAST_MESSAGES=20`。`readyz` 默认额外设置 `PERF_READYZ_INTERVAL_MS=1000`，避免把健康检查当作业务吞吐接口压测。直接使用 `api.perf.run` 时才读取通用 `PERF_CONCURRENCY=64`。

### API 测试资源基线

`tests/docker-compose.test.yml` 已内置资源限制，保证压测和回归结果可对比。默认值：

- `API_SERVICE_CPUS=2.0`，`API_SERVICE_MEMORY=1g`
- `POSTGRES_TEST_CPUS=2.0`，`POSTGRES_TEST_MEMORY=2g`
- `REDIS_TEST_CPUS=1.0`，`REDIS_TEST_MEMORY=512m`
- `RUST_TEST_CPUS=4.0`，`RUST_TEST_MEMORY=4g`
- `API_PERF_CPUS=1.0`，`API_PERF_MEMORY=512m`
- `EXTERNAL_MOCK_CPUS=0.25`，`EXTERNAL_MOCK_MEMORY=128m`
- `DATABASE_MAX_CONNECTIONS=20`，`DATABASE_MIN_CONNECTIONS=0`，`DATABASE_ACQUIRE_TIMEOUT_SECONDS=30`
- `WS_OUTBOUND_QUEUE_SIZE=1024`
- `METRICS_CHANNEL_CAPACITY=8192`，`METRICS_FLUSH_BATCH_SIZE=1000`，`METRICS_FLUSH_INTERVAL_SECONDS=5`，`METRICS_SAMPLE_RATE=1.0`

`rust-tests` 默认额外设置 `CARGO_BUILD_JOBS=1`，避免 Alpine/musl 静态链接多个 integration test binary 时并行链接导致容器 OOM。这个限制只影响测试编译阶段，不代表 API 运行时吞吐基线。

性能测试入口额外定义了一组偏“API 运行时基线”的默认变量：

- `API_SERVICE_CPUS=2.0`，`API_SERVICE_MEMORY=1g`
- `POSTGRES_PERF_CPUS=4.0`，`POSTGRES_PERF_MEMORY=4g`
- `REDIS_PERF_CPUS=2.0`，`REDIS_PERF_MEMORY=1g`
- `DATABASE_PERF_MAX_CONNECTIONS=80`，`DATABASE_PERF_MIN_CONNECTIONS=8`
- `API_PERF_BCRYPT_COST=8`
- `PERF_HEALTHZ_CONCURRENCY=64`，`PERF_READYZ_CONCURRENCY=1`，`PERF_READYZ_INTERVAL_MS=1000`，`PERF_AUTH_CONCURRENCY=4`
- `PERF_WS_CONNECT_CONCURRENCY=8`，`PERF_WS_BROADCAST_CLIENTS=16`，`PERF_WS_BROADCAST_MESSAGES=20`，`PERF_WS_TIMEOUT_MS=20000`

默认测试命令不强制 `--build`；镜像构建独立放在 `make api.test.images`，避免每轮本地测试都请求 Docker Hub metadata，降低限流对验收的影响。

需要模拟更小单机时，直接在命令前覆盖变量，例如：

```bash
API_SERVICE_CPUS=1.0 API_SERVICE_MEMORY=512m make api.test.smoke
API_SERVICE_CPUS=1.0 API_SERVICE_MEMORY=512m PERF_HEALTHZ_CONCURRENCY=32 make api.perf.healthz
```

### 账号注册约定
- 当前测试默认使用普通账号密码注册/登录，不依赖真实邮箱资源。
- 邮箱注册/登录作为后台配置能力保留，默认 `auth_email_enabled=0`，不需要邮箱验证码二次验证。
- `require_captcha_for_login` 只控制短信验证码登录能力；不应阻断普通账号注册。

### Makefile 入口
```bash
# 自包含回归：不启动 live dev 服务，不依赖本机 API/admin 运行态
make test.all

# 真实后端联调：启动 api/admin dev，然后跑 app/admin/desktop live smoke
make test.live

make api.test.unit
make api.test.integration
make api.test.smoke
make api.test.build
make api.perf.smoke
make api.perf.healthz
make api.perf.readyz
make api.perf.auth
make api.perf.ws.connect
make api.perf.ws.join
make api.perf.ws.broadcast
make api.perf.release
make api.perf.release.small
make api.perf.release.standard
make api.perf.release.large

make android-app.check
make android-app.test.unit
make android-app.lint
make android-app.build.debug
make android-app.test.live
make ios-app.check
make ios-app.test
make ios-app.test.live
make ios-app.build.simulator
make ios-app.ui-test
make ios-app.smoke.simulator

make admin.test.e2e
make admin.test.routes
make admin.test.routes.default
make admin.test.routes.data-cleanup
make admin.test.live

make desktop.check
make desktop.test.unit
make desktop.test.api
make desktop.test.store
make desktop.test.utils
make desktop.test.live

make h5-app.check
make h5-app.test.unit
make h5-app.test.live
make h5-app.test.e2e

make website.test.unit
make website.test.download

make api.test
make admin.test
make desktop.test
make website.test
make tests.compose.config
make tests.tooling
make tests.perf.check
make tests.all
```

---

## 4. 什么时候跑什么

### 改 api handler / database / websocket / 对外接口
至少跑：
```bash
make api.test          # Compose 内 Rust 单元 + 集成（自动拉起 pg/redis/external-mock）
```

### 改 android-app / ios-app / admin / desktop / website
先跑各自模块测试，不要往 `tests/` 里加模块测试。

### 发版前
按改动面补：
- api contract
- admin route / core flow smoke
- 原生端 integration / live smoke：`make android-app.test.live`、`make ios-app.test.live`
- API + 原生双端/admin/desktop 联调统一跑 `make test.live`；该入口会启动 API dev 和
  Admin dev，并执行 android-app/ios-app live、admin live backend、desktop live backend
  smoke。H5 保留独立 `make h5-app.test.live`。

---

## 5. 当前约定

- `make api.test` = api Rust 单元（Compose 内 `cargo test --lib`）+ 集成（Compose 内 `cargo test --tests`，axum oneshot 对单一临时测试库）
- `make test.all` = 自包含全量回归，不启动 live dev 联调服务；包含 API Compose
  test/smoke/迁移守护、android-app JVM unit、ios-app SwiftPM unit、admin check/routes、
  desktop check/unit、h5-app check/unit、website unit、Compose config、tooling、perf
  Go 自检。
- `make test.live` = 真实后端联调入口；会启动 `api/docker/dev/docker-compose.yml` 与
  admin dev，并跑 android-app/ios-app live、admin live backend、desktop live backend
  smoke。
- `tests/` 不承载 android-app / ios-app / admin / desktop / website 的测试用例
- 新增测试时，优先放回模块自己的目录
- 仓库根目录 `make test.all` / `make test.live` 是本地回归与联调编排入口，内部仍调用各模块自己的测试命令。
