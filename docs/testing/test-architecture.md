# 测试架构（五模块）

> 本文档用于统一 RedCode IM 的测试边界、测试分层与各模块测试框架选择。
>
> 模块范围：`backend/`、`frontend/`、`desktop/`、`admin/`、`website/`。

## 1. 总体原则

- **跨端契约优先**：跨模块的接口契约与核心链路回归，优先使用 **Go 1.25**（目录：`tests/go/`）。
- **端内生态优先**：各端内部单元测试使用各自生态的主流框架（Rust/Dart/TypeScript），避免“为了 Go 而 Go”。
- **数据可复现**：所有需要“真实数据/房间/好友关系”的测试，统一依赖 `backend/test_flow.sh` 产出的固定测试数据。
- **覆盖目标**：以“核心逻辑 100%”为目标推进（优先保障核心路径与易回归模块；UI 像素级效果不纳入覆盖率目标）。

## 2. 模块测试矩阵

| 模块 | 目录 | 单元测试 | 集成测试 | E2E 测试 |
|------|------|----------|----------|----------|
| Backend | `backend/` | Rust `cargo test` | Rust 集成测试 + Go HTTP/WS 契约 | WebSocket/关键链路（Go/Node/Playwright 视场景） |
| Frontend (Flutter) | `frontend/` | `flutter test` | 与后端联调（真 API） | Patrol `patrol test` |
| Desktop (Vue+Tauri) | `desktop/` | Vitest（规划）+ `src-tauri` `cargo test` | Go HTTP 契约（复用） | Playwright + Tauri Driver（规划） |
| Admin (Vue) | `admin/` | Vitest（规划） | Go HTTP 契约（复用） | Playwright（已存在脚本，待标准化） |
| Website (Nuxt) | `website/` | Vitest + Nuxt Test Utils（规划） | - | Playwright（规划） |

> “规划”表示当前仓库未完整落地对应框架/脚手架，本阶段先明确架构与落地路径。

## 3. 公共测试环境与测试数据

### 3.1 启动依赖与后端

```bash
cd backend
cp .env.example .env  # 首次运行需要
docker compose up -d postgres redis-session redis-cache
cargo run
```

### 3.2 初始化测试数据（统一入口）

```bash
cd backend
./test_flow.sh
```

默认测试账号（脚本会确保存在）：
- `13800138000` / `Test123456`
- `13800138001` / `Test123456`
- `13800138002` / `Test123456`

脚本会输出可复用的房间 `room_id`（私聊/群聊），供 WebSocket、E2E、手工冒烟使用。

### 3.3 客户端本地连接参数

- iOS Simulator / 桌面：可用 `localhost`
- Android 模拟器：宿主机用 `10.0.2.2`
- 真机：使用宿主机局域网 IP

Flutter 建议通过 `--dart-define` 覆盖：

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8010 --dart-define=WS_URL=ws://localhost:8010/ws
```

## 4. Backend（Rust）如何测试

### 4.1 单元测试（Rust）

- 入口：`cd backend && cargo test`
- 适用：纯函数、参数校验、业务规则、序列化/反序列化等。
- 组织：
  - `backend/src/**` 内使用 `#[cfg(test)] mod tests { ... }`
  - 重点：`handlers/` 的校验逻辑、`services/` 的业务逻辑、`models/convert` 等

### 4.2 数据库/存储层集成测试（Rust）

- 入口：`cd backend && cargo test --test database_store_tests -- --test-threads=1`
- 依赖：PostgreSQL 可用，并配置 `DATABASE_URL_TEST`（或回退 `DATABASE_URL`）。

### 4.3 HTTP/WS 契约与回归（Go 1.25）

目录：`tests/go/*`（每个子目录是独立 go module）。

运行示例：

```bash
cd tests/go/desktop_add_member
API_BASE_URL=http://localhost:8010 go test -v ./...
```

> 该类测试用于验证“前端/管理端/桌面端会调用到的后端 API”，作为跨端回归的第一道闸门。

### 4.4 WebSocket 连通性（Node/工具）

后端自带 WS 测试脚本：

```bash
cd backend
USERNAME="13800138000" PASSWORD="Test123456" ROOM_ID="<ROOM_UUID>" npm run test:ws
```

也可参考：`docs/testing/websocket-test.md`

## 5. Frontend（Flutter）如何测试

### 5.1 单元/Widget 测试

```bash
cd frontend
flutter test
```

### 5.2 E2E（Patrol）

```bash
cd frontend
patrol test
```

运行前建议先按第 3 节启动后端并执行 `backend/test_flow.sh`。

文档入口：`docs/testing/e2e-testing-guide.md`、`docs/testing/test-paths.md`

## 6. Admin（Vue）如何测试

### 6.1 单元测试（规划：Vitest + @vue/test-utils）

- 范围：`admin/src/utils/`、`admin/src/api/`、store、页面组件的关键交互逻辑
- 目标：将“API 封装/拦截器/权限控制”等易回归逻辑用单测固化

### 6.2 E2E（Playwright，现状：脚本为主）

- 目录：`admin/playwright-tests/`
- 当前以 `node *.js` 的方式运行脚本（待后续标准化为 Playwright Test Runner）。

管理后台通常使用独立的管理员账号体系（`/auth/admin/login`）。推荐在本地测试环境中启用一次性初始化接口：

1) 在后端 `.env` 中启用：

```bash
ALLOW_INSECURE_ADMIN_BOOTSTRAP=true
```

2) 创建默认管理员（仅开发/测试用）：

```bash
curl -sS -X POST "http://localhost:8010/api/admin/init-default-admin"
```

默认管理员账号：
- `admin` / `admin123`

> 注意：该初始化接口仅用于本地初始化/调试，生产环境必须保持禁用。

## 7. Desktop（Vue + Tauri）如何测试

### 7.1 端内单元测试（规划：Vitest）

- 范围：Vue 侧的 store、消息模型转换、输入框/渲染逻辑等

### 7.2 Tauri Rust 侧测试（可用：cargo test）

```bash
cd desktop/src-tauri
cargo test
```

### 7.3 API 契约（复用 Go）

桌面端强依赖后端 API，可复用 `tests/go/*` 做回归基线（例如：群成员管理）。

## 8. Website（Nuxt）如何测试

### 8.1 单元测试（规划：Vitest + Nuxt Test Utils）

- 范围：工具函数、路由守卫、SEO 元信息生成、关键渲染逻辑

### 8.2 E2E（规划：Playwright）

- 覆盖：核心页面可访问、导航可用、关键 CTA 行为、基础 SEO 断言

---

## 9. 下一阶段：从“功能清单”反推测试用例

当本架构确认后，下一步按以下顺序推进“接近 100% 覆盖”：

1. 以 `docs/api/*` 与 `backend/src/routes.rs` 为基线生成“API 契约测试清单”（Go）
2. 以 `docs/testing/test-paths.md` 的用户旅程为基线补齐 E2E（Flutter/Playwright）
3. 对后端 `services/`、`database/`、`websocket/` 补齐单元/集成测试，覆盖高风险逻辑
