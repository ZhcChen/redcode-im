# 批次 B-1 验收报告（Backend: auth/users/friends）

**日期**: 2026-03-01  
**范围**: Backend 业务域测试重建第一组（`auth`、`users`、`friends`）

## 1. 本批新增测试

### 1.1 公共测试工具
- `tests/go/internal/testutil/auth_flow.go`
  - 用户注册/密码登录/refresh 封装
  - 鉴权请求构造
  - 测试用户名统一生成为合法手机号格式（适配账号策略）

### 1.2 auth
- `tests/go/backend/auth/password_refresh_test.go`
  - 覆盖：注册 -> 密码登录 -> refresh -> `/auth/me`

### 1.3 users
- `tests/go/backend/users/user_profile_search_test.go`
  - 覆盖：用户搜索 `/users/search`
  - 覆盖：更新个人资料 `/users/me`
  - 覆盖：按 ID 查询用户 `/users/{user_id}`

### 1.4 friends
- `tests/go/backend/friends/friend_lifecycle_test.go`
  - 覆盖：发送好友申请 `/friends/requests`
  - 覆盖：处理好友申请 `/friends/requests/{request_id}/respond`
  - 覆盖：好友列表 `/friends`
  - 覆盖：确保私聊房间 `/friends/{friend_user_id}/chat`

## 2. 验证命令与结果

### 2.1 编译级
- `go -C tests/go test ./backend/auth ./backend/users ./backend/friends -run '^$'`
- 结果：通过

### 2.2 集成级（docker 测试栈）

- 启动：`docker-compose -f tests/docker-compose.yml up -d --build external-mock postgres redis-session redis-cache backend`
- backend 健康：约 294 秒进入 healthy
- 执行：
  - `docker-compose -f tests/docker-compose.yml run --rm go-tests go test ./backend/auth -v`
  - `docker-compose -f tests/docker-compose.yml run --rm go-tests go test ./backend/users -v`
  - `docker-compose -f tests/docker-compose.yml run --rm go-tests go test ./backend/friends -v`
- 结果：三组全部通过（PASS）
- 清理：`docker-compose -f tests/docker-compose.yml down -v --remove-orphans`

## 3. 可追溯更新

- 已更新矩阵：`docs/reference/testing/matrix/backend.csv`
- 本批标记为 `done` 的功能点：
  - auth：`BE-AUTH-001/002/004/005`
  - user：`BE-USER-001/002/005/006`
  - friends：`BE-FRIEND-001/002/003/004`

## 4. 本批完成度

- 需求覆盖：100%（本批定义项）
- 验收覆盖：100%（本批定义项）
- 通过率：100%（本批执行）
- 可追溯：100%（矩阵 + 测试代码 + 验收报告）

## 5. 下一步

进入批次 B-2：`rooms/messages/uploads` 业务域测试重建与验收。
