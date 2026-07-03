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
- `app/test/`：Flutter 单元 / widget 测试
- `app/integration_test/`：Flutter integration smoke
- `admin/playwright-tests/`：Admin E2E / smoke
- `desktop/test/`：Desktop 模块测试
- `website/test/`：Website 模块测试

### `tests/` 目录
- `tests/docker-compose.test.yml`：api Compose 测试栈（pg / redis / external-mock / rust-tests / api-smoke；PG/Redis/external-mock 不映射宿主端口）
- `tests/go/tooling/`：仓库级 Makefile / 脚本守护测试
- `tests/mocks/external/`：第三方依赖（B2 / IPInfo / FCM）mock

---

## 3. 常用命令

### API 自测（Compose-first）
```bash
make api.test
```

API 单元、集成、smoke 均通过 `tests/docker-compose.test.yml` 在 Docker Compose 内执行。不要把宿主机 `cargo test` 作为默认验收路径。

### App 自测
```bash
cd app && flutter analyze
cd app && flutter test
make app.test.integration.smoke
```

默认 app 设备验收顺序：优先 `Pixel 8 Pro (3A091FDJG001DN)`；如果该设备未连接，自动切换到本机 iOS Simulator。
每次真机执行前，必须先重新检测当前本机局域网 IP，并据此生成 `API_BASE_URL=http://<LAN_IP>:8010` 与 `WS_URL=ws://<LAN_IP>:8010/ws`，不要复用历史 IP；切换到本机 iOS Simulator 时使用 `127.0.0.1`。
设备枚举有超时保护：`flutter devices` 默认 20 秒、`xcrun simctl list devices available` 默认 20 秒，可用 `FLUTTER_DEVICES_TIMEOUT_SECONDS` / `SIMCTL_TIMEOUT_SECONDS` 覆盖。若 iOS Simulator 因本机 Xcode/CoreSimulator runtime 不匹配不可用，本机 API/WS/auth 联调可以先走默认 `macos` target。
推荐使用 Makefile 入口自动完成：

```bash
# 不访问真实 api，快速验证 integration harness
make app.test.integration.smoke

# 本机 api 联通性验证（默认 macos + http://127.0.0.1:8010）
make app.test.integration.network

# 真实账号密码注册/登录验证（默认 macos + http://127.0.0.1:8010）
make app.test.integration.auth

# 设备联调验证：默认 Pixel 8 Pro；未连接则回退本机 iOS Simulator
make app.test.integration.device
make app.test.integration.device.auth

# Android USB 真机联调兜底：adb reverse，适合局域网隔离或 Android 本地网络限制导致 LAN IP 不通时
make app.test.integration.device.reverse
make app.test.integration.device.auth.reverse
```

`FLUTTER_DEVICE` 默认为空时由脚本按验收顺序选择设备；需要强制指定设备时可覆盖，例如 `make app.test.integration.device FLUTTER_DEVICE=3A091FDJG001DN`。

### App Patrol
```bash
make app.test.patrol.harness
make app.test.patrol.login

# 指定 Android Emulator / 真机
make app.test.patrol.harness PATROL_DEVICE=emulator-5554
make app.test.patrol.login PATROL_DEVICE=emulator-5554
```

补充约定：
- Patrol 默认使用 `PATROL_DEVICE='iPhone 17 Pro'`，可在命令行覆盖；Android 本地验收可传 `PATROL_DEVICE=emulator-5554` 或真机设备 ID。
- Android Patrol 默认通过 Makefile 补充 `PATH=$HOME/Library/Android/sdk/platform-tools:$PATH` 并优先使用 JDK 21；若本机缺少 JDK 21，需先安装或显式设置 `JAVA_HOME`。
- iOS Patrol 需要 Xcode SDK 与已安装 Simulator runtime 匹配；若 Xcode 提示 `iOS xx.x is not installed`，先在 Xcode Settings > Components 安装对应 runtime。
- 默认显式使用 `PATROL_TEST_SERVER_PORT=19081`、`PATROL_APP_SERVER_PORT=19082`，避免本机已有服务占用 Patrol 默认 `8081 / 8082` 导致 `markPatrolAppServiceReady()` 命中宿主机其他进程。
- `app/patrol_test/test_bundle.dart` 是 Patrol 运行时生成文件，不纳入版本控制。

### iOS 原生 App 自测
```bash
make ios-app.check
make ios-app.test
make ios-app.build.simulator
make ios-app.smoke.simulator
```

说明：
- `ios-app` 默认使用本机 iOS Simulator 做开发、smoke、UI test 与 H5/API 联调验收。
- Simulator 联调 API/WS 使用 `127.0.0.1`。
- `ios-app.check` 运行 SwiftPM 单元测试并构建 Simulator Debug app。
- `ios-app.smoke.simulator` 构建、安装并启动空壳 App 到本机 iOS Simulator。
- `ios-app` 不套用 Flutter `app` 的 Pixel 8 Pro 优先规则。

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
- 涉及对象存储 / 推送 / 地理的用例走 `tests/mocks/external` 的 `external-mock`；测试环境禁止使用线上 Backblaze B2 endpoint。
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

make app.check
make app.test.unit
make app.test.core
make app.test.chat
make app.test.widgets
make app.test.features
make app.test.integration.smoke
make app.test.integration.network
make app.test.integration.auth
make app.test.integration.device
make app.test.integration.device.auth
make app.test.patrol.harness
make app.test.patrol.login
make app.test.integration.device.auth.reverse

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

make website.test.unit
make website.test.download

make api.test
make app.test
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

### 改 app / admin / desktop / website
先跑各自模块测试，不要往 `tests/` 里加模块测试。

### 发版前
按改动面补：
- api contract
- admin route / core flow smoke
- app integration smoke
- api + app 联调时先启动 api，再跑 `make app.test.integration.network`；设备联调用 `make app.test.integration.device`（默认 Pixel 8 Pro，未连接则回退本机 iOS Simulator）。
- backend + frontend/admin/desktop 联调统一跑 `make test.live`；该入口会启动 API dev 和 Admin dev，并执行 app network/auth、admin live backend、desktop live backend smoke。

---

## 5. 当前约定

- `make api.test` = api Rust 单元（Compose 内 `cargo test --lib`）+ 集成（Compose 内 `cargo test --tests`，axum oneshot 对单一临时测试库）
- `make test.all` = 自包含全量回归，不启动 live dev 联调服务；包含 API Compose test/smoke/迁移守护、app check/unit/smoke、admin check/routes、desktop check/unit、website unit、Compose config、tooling、perf Go 自检。
- `make test.live` = 真实后端联调入口；会启动 `api/docker/dev/docker-compose.yml` 与 admin dev，并跑 app/admin/desktop live smoke。
- `tests/` 不承载 app / admin / desktop / website 的测试用例
- 新增测试时，优先放回模块自己的目录
- 仓库根目录 `make test.all` / `make test.live` 是本地回归与联调编排入口，内部仍调用各模块自己的测试命令。
