# 桌面端“添加成员”功能 Go 测试（契约回归）

## 背景与范围
- 针对桌面端群设置面板的“添加成员”操作，验证后端接口 `POST /rooms/{room_id}/members` 的正确性与稳健性。
- 不涉及前端 UI 自动化，本阶段聚焦 **HTTP/API 黑盒回归**，确保接口契约稳定。

## 测试栈与约定
- 语言：Go（优先 Go 1.25）。
- 目录：`tests/go/` 为**单一 go module**，共享 `internal/testutil` 作为统一 fixtures/http client。
- 推荐入口：`./tests/run.sh`（自动 `docker-compose` 起 PG/Redis/Backend，并跑 Go 测试）。

## 代码位置
- 添加成员用例：`tests/go/backend/rooms/add_member_test.go`

## 主要覆盖场景
1. **成功添加**：群主/管理员添加未入群成员，返回成功，成员列表包含新成员。
2. **无权限**：普通成员调用，返回 403。

> 其余场景（重复成员、成员上限、非法 ID、WS 广播）可在后续按功能补齐。

## 运行方式

### 方式 A：推荐（一键）
```bash
./tests/run.sh
```

### 方式 B：手动跑 Go 测试（需确保 Backend 已启动）
```bash
cd tests/go
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> go test -v ./backend/rooms -run TestAddMembers_ -v
```
