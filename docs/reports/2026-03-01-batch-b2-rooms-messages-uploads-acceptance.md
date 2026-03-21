# 批次 B-2 验收报告（Backend: rooms/messages/uploads）

**日期**: 2026-03-01  
**范围**: Backend 业务域测试重建第二组（`rooms`、`messages`、`uploads`）

## 1. 本批新增测试

### 1.1 公共测试工具
- `tests/go/internal/testutil/chat_flow.go`
  - 房间创建辅助（group room）
- `tests/go/internal/testutil/admin_flow.go`
  - 管理员初始化与登录
  - 默认存储提供商初始化（用于 uploads 测试）

### 1.2 rooms
- `tests/go/backend/rooms/room_lifecycle_test.go`
  - 覆盖：创建房间 `/rooms`
  - 覆盖：退出房间 `/rooms/{room_id}/leave`
  - 覆盖：加入房间 `/rooms/{room_id}/join`
  - 覆盖：成员列表 `/rooms/{room_id}/members`

### 1.3 messages
- `tests/go/backend/messages/message_lifecycle_test.go`
  - 覆盖：发送消息 `/rooms/{room_id}/messages`
  - 覆盖：编辑消息 `/rooms/{room_id}/messages/{message_id}`
  - 覆盖：删除消息 `/rooms/{room_id}/messages/{message_id}`
  - 覆盖：消息列表 `/rooms/{room_id}/messages`

### 1.4 uploads
- `tests/go/backend/uploads/message_attachment_test.go`
  - 覆盖：附件上传签名 `/rooms/{room_id}/messages/attachments/signature`
  - 覆盖：附件上传完成 `/rooms/{room_id}/messages/attachments/commit`
  - 覆盖：附件消息发送 `/rooms/{room_id}/messages`
  - 覆盖：附件下载链接 `/rooms/{room_id}/messages/attachments/download`
  - 覆盖：通过下载链接回读对象内容

## 2. 验证命令与结果

### 2.1 编译级
- `go -C tests/go test ./... -run '^$'`
- 结果：通过

### 2.2 集成级（docker 测试栈）

- rooms/messages 首轮：
  - `go test ./backend/rooms -v` 通过
  - `go test ./backend/messages -v` 通过
- uploads 首轮失败：
  - 原因：`application/octet-stream` 不在上传策略白名单
- 修复后 uploads 回归：
  - 将测试 MIME 调整为 `image/png`
  - `go test ./backend/uploads -v` 通过

## 3. 可追溯更新

- 已更新矩阵：`docs/reference/testing/matrix/backend.csv`
- 本批标记为 `done` 的功能点：
  - rooms：`BE-ROOM-001/002/003`
  - messages：`BE-MSG-001/002/003`
  - uploads：`BE-UPL-001`

## 4. 本批完成度

- 需求覆盖：100%（本批定义项）
- 验收覆盖：100%（本批定义项）
- 通过率：100%（修复后最终执行）
- 可追溯：100%（矩阵 + 测试代码 + 验收报告）

## 5. 下一步

进入批次 B-3：`versions/admin/ws` 业务域测试重建与验收。
