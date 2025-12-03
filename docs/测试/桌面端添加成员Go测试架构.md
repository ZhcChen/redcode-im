# 桌面端“添加成员”功能 Go 测试架构

## 背景与范围
- 针对桌面端群设置面板的“添加成员”操作，验证后端接口 `/rooms/{room_id}/members`（兼容 `/members/add`）在主要业务场景下的正确性与稳健性。
- 不涉及前端 UI 自动化，本轮聚焦 HTTP/API 层验证，确保接口契约稳定后再考虑 UI 冒烟。

## 技术栈与规范
- 语言：Go（优先 Go 1.25）。
- 依赖：标准库 `net/http`, `encoding/json`, `testing`；可选 `stretchr/testify` 用于断言（如新增需写入 go.mod）。
- 运行命令：`GO111MODULE=on go test -v ./...`（建议使用 `go1.25` 可执行文件）。

## 目录规划
```
tests/go/desktop_add_member/
  go.mod                # go 1.25，集中管理依赖
  http_client.go        # 轻量 HTTP 客户端封装（鉴权、重试）
  fixtures.go           # 测试数据生成/登录获取 token/创建群
  add_member_test.go    # 场景用例（成功/权限/上限/重复/非法ID）
  testdata/
    users.json          # 预置用户/密码/角色
```

## 前置依赖
- 后端服务已运行，默认基准地址 `http://localhost:8010`（可通过环境变量 `API_BASE_URL` 覆盖）。
- 具备一个可登录的管理员账号或有群管理权限的测试账号；如无，测试夹具使用注册接口创建。
- 数据库允许创建/删除测试群和成员。

## 场景覆盖
1. **成功添加**：管理者添加多个未入群成员，返回成功，成员数增加，广播事件（可在后续加 WS 验证）。
2. **重复成员**：包含已在群内的 user_id，应跳过且整体返回成功，响应中标记 skipped。
3. **成员上限**：当 `max_members` 达到阈值时返回业务错误，提示名额不足。
4. **无权限**：普通成员调用，返回 403。
5. **非法用户ID**：包含格式错误的 UUID，返回 422。

## 测试数据与夹具
- `fixtures.go` 负责：
  - 登录并缓存 Bearer Token。
  - 创建临时用户（调用注册或后台 API）。
  - 创建临时群（指定群主/管理员），返回 `room_id`。
  - 测试结束清理：删除群或移除测试用户，避免污染。
- ID 生成与等待：尽量同步操作；若需等待异步广播，可增加短暂轮询确认成员列表。

## 运行与参数
- 环境变量：
  - `API_BASE_URL`：后端基地址。
  - `ADMIN_USERNAME` / `ADMIN_PASSWORD`：管理账号（可选）。
- 运行示例：
  ```
  cd tests/go/desktop_add_member
  go test -v -run TestAddMembers_Smoke
  ```

## 执行规则（backend 端口与进程）
- 涉及 backend 的测试必须由测试脚本自行启动 backend 服务。
- 启动前检查目标端口（默认 8010，可由 `PORT` 环境变量覆盖）；若被占用，优先 kill 占用该端口的进程后再启动 backend。
- 启动时建议使用独立端口以避免影响现有实例，例如 `PORT=18010 cargo run --quiet`。
- 测试完成后必须关闭本次启动的 backend 进程，保持环境整洁。

## 扩展计划
- 增加 WS 层验证：订阅 `GroupMemberChanged` 事件，确认 joined/kicked 广播。
- 引入并行用例与 race 检查，覆盖并发添加同一用户的幂等性。
- 将测试纳入 CI，使用容器化后端或本地 docker-compose 作为依赖服务。
