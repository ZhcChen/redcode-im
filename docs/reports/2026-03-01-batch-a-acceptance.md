# 批次 A 验收报告（基础设施与外部依赖模拟）

**日期**: 2026-03-01  
**范围**: 外部依赖模拟、Backend 外部地址可配置化、测试栈接入与最小集成验证

## 1. 验收目标

1. 在无公网/无真实云资源前提下，Backend 可完成 OAuth 与基础健康链路回归。
2. 外部依赖（对象存储/JWKS/FCM/IPInfo）具备本地可调用模拟实现。
3. 测试栈默认注入模拟地址并可执行。

## 2. 交付清单

- 外部模拟服务：`tests/mocks/external/cmd/external-mock/main.go`
- 外部模拟测试：`tests/mocks/external/cmd/external-mock/main_test.go`
- Backend 可配置项（JWKS/FCM/IPInfo/对象存储 scheme）
- 测试栈接入：`tests/docker-compose.yml`、`tests/run.sh`
- Go 黑盒新增：OAuth 登录、external-mock 健康检查

## 3. 验证证据

### 3.1 快速验证（语法/编译）

- `go -C tests/mocks/external test ./...`
- `go -C tests/go test ./... -run '^$'`
- `cargo test --manifest-path backend/Cargo.toml --lib --no-run`
- `docker compose -f tests/docker-compose.yml config >/dev/null`
- `bash -n tests/run.sh`

结果：全部通过。

### 3.2 集成验证（真实链路）

- 启动：`docker compose -f tests/docker-compose.yml up -d --build external-mock postgres redis-session redis-cache backend`
- 健康检查：`backend /healthz`（冷启动约 247 秒后通过）
- Go 黑盒：
  - `go test ./backend/system -v` 通过
  - `go test ./backend/auth -v` 通过
- 清理：`docker compose -f tests/docker-compose.yml down -v --remove-orphans`

### 3.3 external-mock 自测

- `go -C tests/mocks/external test ./... -v` 通过
- 覆盖能力：
  - 对象存储对象生命周期（PUT/HEAD/GET/DELETE）
  - 对象存储分片上传（initiate/upload/complete）
  - Google/Apple JWKS
  - Google/Apple 测试 ID Token 生成
  - FCM 发送成功/invalid/unregistered 场景
  - IPInfo 查询

## 4. 批次 A 完成度

- 需求覆盖：100%（批次 A 定义项全部落地）
- 验收覆盖：100%（每项均有自动化验证）
- 通过率：100%（当前批次执行全部通过）
- 可追溯：100%（已映射至 `docs/reference/testing/matrix/backend.csv`）

## 5. 后续进入批次

下一步进入 **批次 B**：Backend 业务域测试重建（`auth/users/friends` -> `rooms/messages/uploads` -> `versions/admin/ws`）。
