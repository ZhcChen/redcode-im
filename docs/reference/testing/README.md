# 测试工作流

## 1. 原则

RedCode IM 的测试策略调整为：

- **模块自测为主**
- **`tests/` 只负责 backend contract 测试栈**
- **跨模块 smoke 只保留少量必要链路**

不要再把 `tests/` 当成“全项目统一测试中心”。

---

## 2. 目录边界

### 模块内测试
- `backend/tests/`：Rust 集成测试
- `frontend/test/`：Flutter 单元 / widget 测试
- `frontend/integration_test/`：Flutter integration smoke
- `admin/playwright-tests/`：Admin E2E / smoke
- `desktop/test/`：Desktop 模块测试
- `website/test/`：Website 模块测试

### `tests/` 目录
- `tests/run.sh`：backend contract 统一入口
- `tests/docker-compose.yml`：isolated backend contract stack
- `tests/go/`：backend HTTP / WS 黑盒契约测试
- `tests/mocks/external/`：第三方依赖 mock

---

## 3. 常用命令

### Backend 自测
```bash
cd backend && cargo test
```

### Frontend 自测
```bash
cd frontend && flutter analyze
cd frontend && flutter test
make frontend.test.integration.smoke
```

默认 frontend 设备验收顺序：优先 `Pixel 8 Pro (3A091FDJG001DN)`；如果该设备未连接，自动切换到本机 iOS Simulator。
每次真机执行前，必须先重新检测当前本机局域网 IP，并据此生成 `API_BASE_URL=http://<LAN_IP>:8010` 与 `WS_URL=ws://<LAN_IP>:8010/ws`，不要复用历史 IP；切换到本机 iOS Simulator 时使用 `127.0.0.1`。
推荐使用 Makefile 入口自动完成：

```bash
# 不访问真实 backend，快速验证 integration harness
make frontend.test.integration.smoke

# 本机 backend 联通性验证（默认 macos + http://127.0.0.1:8010）
make frontend.test.integration.network

# 设备联调验证：默认 Pixel 8 Pro；未连接则回退本机 iOS Simulator
make frontend.test.integration.device

# Android USB 真机联调兜底：adb reverse，适合局域网隔离或 Android 本地网络限制导致 LAN IP 不通时
make frontend.test.integration.device.reverse
```

`FLUTTER_DEVICE` 默认为空时由脚本按验收顺序选择设备；需要强制指定设备时可覆盖，例如 `make frontend.test.integration.device FLUTTER_DEVICE=3A091FDJG001DN`。

### Frontend iOS Simulator / Patrol
```bash
make frontend.test.patrol.harness
make frontend.test.patrol.login
```

补充约定：
- Patrol iOS 默认使用 `PATROL_IOS_DEVICE='iPhone 17 Pro'`，可在命令行覆盖。
- 默认显式使用 `PATROL_TEST_SERVER_PORT=19081`、`PATROL_APP_SERVER_PORT=19082`，避免本机已有服务占用 Patrol 默认 `8081 / 8082` 导致 `markPatrolAppServiceReady()` 命中宿主机其他进程。
- `frontend/patrol_test/test_bundle.dart` 是 Patrol 运行时生成文件，不纳入版本控制。

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

### Backend contract 测试栈
```bash
./tests/run.sh
./tests/run.sh rust
./tests/run.sh go
```

说明：
- Go 黑盒契约测试默认按包串行执行（`-p 1`），避免共享同一 backend / DB 时发生状态竞争。
- `tests/docker-compose.yml` 将 backend / PostgreSQL / Redis 放在同一个 Compose 网络中。
- 测试栈只启动一个 Redis，backend 的 `REDIS_SESSION_URL` / `REDIS_PUBSUB_URL` / `REDIS_CACHE_URL` 都指向该实例。
- PostgreSQL / Redis 不映射宿主机端口。
- B2 / S3 兼容对象存储默认走 `tests/mocks/external` 的 `external-mock`：
  - `REDCODE_IM_B2_AUTHORIZE_ACCOUNT_URL=http://external-mock:19080/b2api/v4/b2_authorize_account`
  - `REDCODE_IM_B2_ENDPOINT=http://external-mock:19080`
  - 测试环境禁止使用线上 Backblaze B2 endpoint 消耗对象存储资源。

### Makefile 入口
```bash
make test.all

make backend.test.unit
make backend.test.integration
make backend.test.smoke

make frontend.check
make frontend.test.unit
make frontend.test.core
make frontend.test.chat
make frontend.test.widgets
make frontend.test.features
make frontend.test.integration.smoke
make frontend.test.integration.network
make frontend.test.integration.device
make frontend.test.patrol.harness
make frontend.test.patrol.login

make admin.test.e2e
make admin.test.routes
make admin.test.routes.default
make admin.test.routes.data-cleanup

make desktop.check
make desktop.test.unit
make desktop.test.api
make desktop.test.store
make desktop.test.utils

make website.test.unit
make website.test.download

make backend.test
make frontend.test
make admin.test
make desktop.test
make website.test
make tests.run
make tests.contract
make tests.go
make tests.all
```

---

## 4. 什么时候跑什么

### 改 backend handler / database / websocket / 对外接口
至少跑：
```bash
cd backend && cargo test
./tests/run.sh go
```

### 改 frontend / admin / desktop / website
先跑各自模块测试，不要往 `tests/` 里加模块测试。

### 发版前
按改动面补：
- backend contract
- admin route / core flow smoke
- frontend integration smoke
- backend + frontend 联调时先启动 backend，再跑 `make frontend.test.integration.network`；设备联调用 `make frontend.test.integration.device`（默认 Pixel 8 Pro，未连接则回退本机 iOS Simulator）。

---

## 5. 当前约定

- `tests/run.sh` 默认跑 backend contract 全量：Rust lib + Rust integration + Go contract
- `tests/` 不承载 frontend / admin / desktop / website 的测试用例
- 新增测试时，优先放回模块自己的目录
- 仓库根目录 `make test.all` 是本地全量测试编排入口，内部仍调用各模块自己的测试命令。
