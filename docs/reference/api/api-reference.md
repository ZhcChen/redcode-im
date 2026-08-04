# RedCode IM API API 完整参考文档

> 本文档用于记录当前已实现的 REST API 与 WebSocket 接口入口；若与代码不一致，以 `api/src/routes.rs` 为准。

## 📋 目录

- [基础信息](#基础信息)
- [认证 API](#认证-api)
- [登录设备 API](#登录设备-api)
- [扫码登录 API](#扫码登录-api)
- [用户管理 API](#用户管理-api)
- [黑名单 API](#黑名单-api)
- [好友系统 API](#好友系统-api)
- [房间/群组 API](#房间群组-api)
- [群公告 API](#群公告-api)
- [消息 API](#消息-api)
- [消息收藏 API](#消息收藏-api)
- [消息已读 API](#消息已读-api)
- [消息搜索 API](#消息搜索-api)
- [群组管理 API](#群组管理-api)
- [管理后台 API](#管理后台-api)
- [文件存储 API](#文件存储-api)
- [版本管理 API](#版本管理-api)
- [系统设置 API](#系统设置-api)
- [Push 通知 API](#push-通知-api)
- [其他 API](#其他-api)
- [WebSocket 接口](#websocket-接口)

---

## 基础信息

### 服务端口
- 默认端口: `8010`
- 开发环境: `http://localhost:8010`
- 生产环境: `https://api.chatlyme.com`

### 认证方式
除公开路由外，所有 API 请求需要在 Header 中携带 JWT Token：
```
Authorization: Bearer <your-jwt-token>
```

### 响应格式
成功响应的结构**不强制统一**（部分接口返回 `{success,message,...}`，部分接口直接返回业务对象），建议以 **HTTP 状态码** 为第一判断依据。

当接口返回非 2xx 时，响应体遵循统一结构（见 `api/src/error.rs`）：
```json
{
  "code": 40001,
  "message": "错误信息",
  "details": "可选的详细信息"
}
```

---

## 认证 API

### 公开路由

#### 1. 用户注册
- **接口**: `POST /auth/register`
- **权限**: 公开
- **功能**: 使用普通账号和密码创建新用户账户；邮箱注册默认关闭，可由后台开关启用兼容
- **Handler**: `auth::register`

#### 2. 用户登录
- **接口**: `POST /auth/login`
- **权限**: 公开
- **功能**: 普通账号/密码登录；邮箱登录默认关闭，可由后台开关启用兼容
- **Handler**: `auth::login`

#### 3. 短信登录
- **接口**: `POST /auth/login/sms`
- **权限**: 公开
- **功能**: 手机号+验证码登录
- **Handler**: `auth::login_with_sms`

#### 4. 发送登录短信
- **接口**: `POST /auth/sms/send`
- **权限**: 公开
- **功能**: 发送登录验证码短信
- **Handler**: `auth::send_login_sms`

#### 5. 刷新访问令牌
- **接口**: `POST /auth/refresh`
- **权限**: 公开
- **功能**: 使用 refresh_token 获取新的 access_token
- **Handler**: `auth::refresh_token`

**请求示例**：
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**响应示例**：
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### 6. 查询管理员初始化状态
- **接口**: `GET /api/admin/bootstrap/status`
- **权限**: 公开
- **功能**: 查询系统是否已初始化管理员；首次部署引导时用于判断是否需要初始化
- **Handler**: `auth::get_admin_bootstrap_status`

**响应示例**：
```json
{
  "bootstrap_required": true
}
```

#### 7. 初始化管理员
- **接口**: `POST /api/admin/bootstrap/init`
- **权限**: 公开
- **功能**: 系统尚无管理员时创建初始管理员账号并返回管理员登录信息
- **Handler**: `auth::bootstrap_admin`

**请求示例**：
```json
{
  "username": "admin",
  "password": "admin123",
  "display_name": "系统管理员"
}
```

#### 8. 管理员登录
- **接口**: `POST /auth/admin/login`
- **权限**: 公开
- **功能**: 管理员账号登录，返回管理员专用 Token
- **Handler**: `auth::admin_login`

**请求示例**：
```json
{
  "username": "admin",
  "password": "admin123"
}
```

#### 9. 管理员刷新令牌
- **接口**: `POST /auth/admin/refresh`
- **权限**: 公开
- **功能**: 刷新管理员访问令牌
- **Handler**: `auth::admin_refresh_token`

### 需要认证的路由

#### 10. 获取当前用户信息
- **接口**: `GET /auth/me`
- **权限**: 需要认证
- **功能**: 获取当前登录用户的详细信息
- **Handler**: `auth::get_current_user`

#### 11. 短信重置密码
- **接口**: `POST /auth/password/reset`
- **权限**: 需要认证
- **功能**: 通过短信验证码重置密码
- **Handler**: `auth::reset_password_with_sms`

### 管理员认证路由

> 以下接口需要管理员 Token（通过 `/auth/admin/login` 获取）

#### 12. 获取当前管理员信息
- **接口**: `GET /auth/admin/me`
- **权限**: 管理员
- **功能**: 获取当前登录管理员的详细信息
- **Handler**: `auth::get_current_admin_user`

#### 13. 更新当前管理员信息
- **接口**: `PATCH /auth/admin/me`
- **权限**: 管理员
- **功能**: 更新当前管理员的昵称等信息
- **Handler**: `auth::update_current_admin_user`

#### 14. 修改管理员密码
- **接口**: `POST /auth/admin/me/password`
- **权限**: 管理员
- **功能**: 修改当前管理员密码
- **Handler**: `auth::change_current_admin_password`

**请求示例**：
```json
{
  "old_password": "oldpass123",
  "new_password": "newpass456"
}
```

### 登录设备 API（API 2.0）

> 详细说明见 `auth-devices.md`。登录/注册/短信登录请求体可携带
> `device_id`、`device_name`、`platform`。

#### 15. 获取设备列表
- **接口**: `GET /auth/devices`
- **权限**: 需要认证
- **功能**: 列出当前账号全部登录设备（含当前设备标记）
- **Handler**: `auth_device::list_devices`

#### 16. 撤销设备
- **接口**: `POST /auth/devices/:device_id/revoke`
- **权限**: 需要认证
- **功能**: 撤销指定设备：refresh token 立即失效、对应 WS 会话被断开；
  已签发 access token 在 TTL 内仍有效
- **Handler**: `auth_device::revoke_device`

### 扫码登录 API（API 2.0）

> 完整流程见 `qr-login.md`。二维码会话 TTL 5 分钟，`loginCode` 一次性使用。

#### 17. 创建扫码会话
- **接口**: `POST /auth/qr/sessions`
- **权限**: 否（PC 端匿名）
- **功能**: 创建扫码登录会话，返回 `qrId` 与 `expiresAt`
- **Handler**: `qr_login::create_session`

#### 18. 轮询扫码状态
- **接口**: `GET /auth/qr/sessions/:qr_id`
- **权限**: 否（PC 端匿名）
- **功能**: 查询状态；confirmed 时一次性返回 `loginCode`
- **Handler**: `qr_login::get_session`

#### 19. 手机端确认扫码
- **接口**: `POST /auth/qr/sessions/:qr_id/confirm`
- **权限**: 需要认证（手机端已登录）
- **功能**: 确认二维码登录；确认后向 PC 端 WS 推送 `qr_status_changed`
- **Handler**: `qr_login::confirm_session`

#### 20. 取消扫码会话
- **接口**: `POST /auth/qr/sessions/:qr_id/cancel`
- **权限**: 否（PC 端匿名）
- **功能**: 取消等待中的扫码会话
- **Handler**: `qr_login::cancel_session`

---

## 用户管理 API

### 用户查询

#### 1. 搜索用户
- **接口**: `GET /users/search`
- **权限**: 需要认证
- **功能**: 根据用户名、昵称搜索用户
- **Handler**: `user::search_users`
- **查询参数**: `?q=keyword`

#### 2. 获取用户详情
- **接口**: `GET /users/:user_id`
- **权限**: 需要认证
- **功能**: 根据用户ID获取用户详细信息
- **Handler**: `user::get_user_by_id`

### 当前用户管理

#### 3. 更新个人信息
- **接口**: `PATCH /users/me`
- **权限**: 需要认证
- **功能**: 更新当前用户的昵称、个性签名等信息
- **Handler**: `user::update_me`

#### 4. 注销账户
- **接口**: `DELETE /users/me`
- **权限**: 需要认证
- **功能**: 停用当前用户账户
- **Handler**: `user::deactivate_me`

#### 5. 修改密码
- **接口**: `POST /users/me/password`
- **权限**: 需要认证
- **功能**: 修改当前用户密码
- **Handler**: `user::change_password`

### 头像管理

#### 6. 生成头像直传签名
- **接口**: `POST /users/me/avatar/direct-upload`
- **权限**: 需要认证
- **功能**: 生成第三方存储的直传签名（腾讯COS等）
- **Handler**: `user::generate_avatar_direct_upload`

#### 7. 提交头像上传
- **接口**: `POST /users/me/avatar/commit`
- **权限**: 需要认证
- **功能**: 确认头像上传完成
- **Handler**: `user::commit_avatar_upload`

#### 8. 获取头像下载链接
- **接口**: `GET /users/me/avatar/url`
- **权限**: 需要认证
- **功能**: 获取头像的临时下载链接
- **Handler**: `user::get_avatar_download_url`

#### 9. 获取其他用户头像下载链接
- **接口**: `GET /users/:user_id/avatar/url`
- **权限**: 需要认证
- **功能**: 获取指定用户头像的临时下载链接
- **Handler**: `user::get_user_avatar_download_url`

### 黑名单 API（API 2.0）

> 详细说明见 `user-block.md`。双向任一方向拉黑即阻断私聊、发消息与好友申请。

#### 10. 获取拉黑列表
- **接口**: `GET /users/blocked`
- **权限**: 需要认证
- **功能**: 分页获取当前用户拉黑列表（limit 默认 50，1-100）
- **Handler**: `user_block::list_blocked`

#### 11. 拉黑用户
- **接口**: `POST /users/blocked`
- **权限**: 需要认证
- **功能**: 拉黑指定用户（幂等；不能拉黑自己）
- **Handler**: `user_block::block_user`

#### 12. 取消拉黑
- **接口**: `DELETE /users/blocked/:user_id`
- **权限**: 需要认证
- **功能**: 取消对指定用户的拉黑
- **Handler**: `user_block::unblock_user`

---

## 好友系统 API

### 好友请求管理

#### 1. 获取好友请求列表
- **接口**: `GET /friends/requests`
- **权限**: 需要认证
- **功能**: 获取收到和发送的好友请求
- **Handler**: `friend::list_friend_requests`

#### 2. 发送好友请求
- **接口**: `POST /friends/requests`
- **权限**: 需要认证
- **功能**: 向其他用户发送好友请求
- **Handler**: `friend::create_friend_request`

#### 3. 响应好友请求
- **接口**: `POST /friends/requests/:request_id/respond`
- **权限**: 需要认证
- **功能**: 接受或拒绝好友请求
- **Handler**: `friend::respond_friend_request`

### 好友列表

#### 4. 获取好友列表
- **接口**: `GET /friends`
- **权限**: 需要认证
- **功能**: 获取当前用户的所有好友
- **Handler**: `friend::list_friends`

#### 5. 确保私聊存在
- **接口**: `POST /friends/:friend_user_id/chat`
- **权限**: 需要认证
- **功能**: 创建或获取与好友的私聊房间
- **Handler**: `friend::ensure_private_chat`

#### 6. 更新好友备注
- **接口**: `PATCH /friends/:friend_user_id/remark`
- **权限**: 需要认证
- **功能**: 设置或更新好友的备注名
- **Handler**: `friend::update_friend_remark`

**请求示例**：
```json
{
  "remark": "小明同学"
}
```

#### 7. 删除好友
- **接口**: `DELETE /friends/:friend_user_id`
- **权限**: 需要认证
- **功能**: 删除好友关系（双向删除）
- **Handler**: `friend::delete_friend`

---

## 房间/群组 API

### 聊天列表

#### 1. 获取聊天摘要列表
- **接口**: `GET /chats`
- **权限**: 需要认证
- **功能**: 获取所有聊天的摘要信息（包括最后一条消息、未读数等）
- **Handler**: `room::list_chat_summaries`

#### 2. 归档聊天会话
- **接口**: `DELETE /chats/:room_id`
- **权限**: 需要认证（当前用户必须是房间成员）
- **功能**: 仅从当前用户的会话收件箱归档指定聊天；不退出群聊、不删除房间、不影响其他成员，也不删除消息历史。
- **Handler**: `room::archive_chat`
- **说明**: `persist` 模式下新持久化消息会让会话重新出现在聊天列表；`relay_only` 下客户端收到实时消息后应调用恢复接口或在本机恢复。

#### 3. 恢复聊天会话
- **接口**: `POST /chats/:room_id/restore`
- **权限**: 需要认证（当前用户必须是房间成员）
- **功能**: 恢复当前用户已归档的会话
- **Handler**: `room::restore_chat`

### 群目录

#### 1. 获取联系人群目录
- **接口**: `GET /groups/directory`
- **权限**: 需要认证
- **功能**: 获取当前用户仍在其中的群聊，独立于聊天列表、消息缓存和消息持久化模式；收藏群优先返回。
- **Handler**: `room::list_group_directory`

#### 2. 收藏群聊
- **接口**: `POST /rooms/:room_id/directory-favorite`
- **权限**: 需要认证（当前用户必须是群成员）
- **功能**: 收藏群聊，使其在联系人群目录中优先展示。
- **Handler**: `room::favorite_group_directory`

#### 3. 取消收藏群聊
- **接口**: `DELETE /rooms/:room_id/directory-favorite`
- **权限**: 需要认证（当前用户必须是群成员）
- **功能**: 取消联系人群目录中的收藏状态，不退出群聊。
- **Handler**: `room::unfavorite_group_directory`

### 房间管理

#### 2. 创建房间
- **接口**: `POST /rooms`
- **权限**: 需要认证
- **功能**: 创建新的群聊房间
- **Handler**: `room::create_room`

#### 3. 获取我的房间列表
- **接口**: `GET /rooms`
- **权限**: 需要认证
- **功能**: 获取当前用户加入的所有房间
- **Handler**: `room::list_my_rooms`

#### 4. 加入房间
- **接口**: `POST /rooms/:room_id/join`
- **权限**: 需要认证
- **功能**: 加入指定房间
- **Handler**: `room::join_room`

#### 5. 离开房间
- **接口**: `POST /rooms/:room_id/leave`
- **权限**: 需要认证
- **功能**: 退出指定房间
- **Handler**: `room::leave_room`

#### 6. 获取房间成员列表
- **接口**: `GET /rooms/:room_id/members`
- **权限**: 需要认证
- **功能**: 获取房间的所有成员
- **Handler**: `room::list_members`

#### 7. 更新通知设置
- **接口**: `POST /rooms/:room_id/notification-settings`
- **权限**: 需要认证
- **功能**: 设置房间的消息通知（免打扰等）
- **Handler**: `room::update_notification_settings`

#### 8. 获取房间详情
- **接口**: `GET /rooms/:room_id`
- **权限**: 需要认证
- **功能**: 获取房间的详细信息
- **Handler**: `room::get_room`

#### 9. 更新房间信息
- **接口**: `PATCH /rooms/:room_id`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 更新房间名称、描述等信息
- **Handler**: `room::update_room`

**请求示例**：
```json
{
  "name": "新群名称",
  "description": "新的群描述"
}
```

#### 10. 解散群聊
- **接口**: `DELETE /rooms/:room_id`
- **权限**: 需要认证（需要群主权限）
- **功能**: 解散群聊，删除群组
- **Handler**: `room::dissolve_room`

#### 11. 转让群主
- **接口**: `POST /rooms/:room_id/transfer`
- **权限**: 需要认证（需要群主权限）
- **功能**: 将群主身份转让给其他成员
- **Handler**: `room::transfer_room_owner`

**请求示例**：
```json
{
  "new_owner_id": "user-uuid"
}
```

### 房间头像管理

#### 12. 生成房间头像直传签名
- **接口**: `POST /rooms/:room_id/avatar/direct-upload`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 生成房间头像的直传签名
- **Handler**: `room::generate_room_avatar_direct_upload`

#### 13. 提交房间头像上传
- **接口**: `POST /rooms/:room_id/avatar/commit`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 确认房间头像上传完成
- **Handler**: `room::commit_room_avatar_upload`

#### 14. 获取房间头像下载链接
- **接口**: `GET /rooms/:room_id/avatar/url`
- **权限**: 需要认证
- **功能**: 获取房间头像的临时下载链接
- **Handler**: `room::get_room_avatar_download_url`

### 房间置顶

#### 15. 置顶房间
- **接口**: `POST /rooms/:room_id/pin`
- **权限**: 需要认证
- **功能**: 将房间置顶到聊天列表顶部
- **Handler**: `room::pin_room`

#### 16. 取消置顶房间
- **接口**: `DELETE /rooms/:room_id/pin`
- **权限**: 需要认证
- **功能**: 取消房间置顶
- **Handler**: `room::unpin_room`

### 群公告 API（API 2.0）

> 详细说明见 `group-announcement.md`。仅群主/管理员可写，群成员可读。

#### 17. 获取群公告
- **接口**: `GET /rooms/:room_id/announcement`
- **权限**: 需要认证（群成员）
- **功能**: 获取当前群公告；无公告返回 404
- **Handler**: `group_announcement::get_announcement`

#### 18. 发布/更新群公告
- **接口**: `PUT /rooms/:room_id/announcement`
- **权限**: 需要认证（群主/管理员）
- **功能**: 覆盖式发布或更新公告；成功后向群内推送 WS 事件 23
- **Handler**: `group_announcement::update_announcement`

#### 19. 删除群公告
- **接口**: `DELETE /rooms/:room_id/announcement`
- **权限**: 需要认证（群主/管理员）
- **功能**: 删除公告并推送 WS 事件 23（content 为 null）
- **Handler**: `group_announcement::delete_announcement`

---

## 消息 API

### 消息发送与获取

消息接口受全局消息运行模式影响。默认 `persist` 模式会服务端落库；`relay_only` 模式只实时转发，不写 `messages` / `message_parts`，且不把消息快照写入离线 Push 队列；历史、搜索、已读和消息变更类能力会降级。详细边界见 `docs/reference/architecture/message-runtime-modes.md`。

#### 1. 发送消息
- **接口**: `POST /rooms/:room_id/messages`
- **权限**: 需要认证
- **功能**: 在指定房间发送消息；`persist` 模式写入服务端历史，`relay_only` 模式返回运行时消息快照并通过 WebSocket 实时广播
- **Handler**: `message::send_message`
- **请求体**: `content` 可选、`parts` 可选、`quoted_message_id` 可选；当 `parts` 为空时必须提供非空 `content`。消息类型由 `parts` 归一化推导，纯 `content` 为文本消息。`relay_only` 下不支持 `quoted_message_id`，附件 key 必须属于当前房间前缀 `messages/{room_id}/`。
- **错误**: `relay_only` 实时广播失败或附件授权服务不可用时返回 HTTP 503 ErrorResponse（`code=50302`），客户端应保持未发送/可重试状态。

#### 1.1 发送加密消息
- **接口**: `POST /rooms/:room_id/messages/encrypted`
- **权限**: 需要认证
- **功能**: 发送 Base64 编码密文消息；`persist` 模式写入密文历史，`relay_only` 模式仅实时广播运行时快照，不写服务端历史或离线 Push 消息快照
- **Handler**: `message::send_encrypted_message`
- **请求体**: `content_summary` 可选、`encrypted_content` 必填 Base64、`encryption_metadata` 可选、`quoted_message_id` 可选；`relay_only` 下不支持 `quoted_message_id`。
- **错误**: 非法 Base64 返回 HTTP 400；`relay_only` 引用消息返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）；实时广播失败返回 HTTP 503 ErrorResponse（`code=50302`）。

#### 2. 获取消息列表
- **接口**: `GET /rooms/:room_id/messages`
- **权限**: 需要认证
- **功能**: 分页获取房间的历史消息；`relay_only` 模式返回 HTTP 200 空列表
- **Handler**: `message::list_messages`
- **查询参数**: `?before_id=xxx&limit=50` 或 `?since_id=xxx&limit=50`；`before_id` 与 `since_id` 互斥，`limit` 范围 1-200。

#### 3. 清空房间消息
- **接口**: `DELETE /rooms/:room_id/messages`
- **权限**: 需要认证（私聊任一成员；群聊仅群主）
- **功能**: 清空整个房间的所有消息历史并向成员广播；不是“清除我的聊天记录”接口。`relay_only` 下返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）
- **Handler**: `message::clear_room_messages`

### 消息操作

> `relay_only` 下，删除、置顶、取消置顶、转发、编辑和 reaction 类消息变更接口返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）。

#### 3. 删除消息
- **接口**: `DELETE /rooms/:room_id/messages/:message_id`
- **权限**: 需要认证
- **功能**: 删除自己发送的消息（软删除）
- **Handler**: `message::delete_message`

#### 4. 置顶消息
- **接口**: `POST /rooms/:room_id/messages/:message_id/pin`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 将消息置顶到房间顶部
- **Handler**: `message::pin_message`

#### 5. 取消置顶
- **接口**: `DELETE /rooms/:room_id/messages/:message_id/pin`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 取消消息置顶
- **Handler**: `message::unpin_message`

#### 6. 转发消息
- **接口**: `POST /rooms/:room_id/messages/forward`
- **权限**: 需要认证
- **功能**: 将消息转发到其他房间
- **Handler**: `message::forward_message`

#### 7. 编辑消息
- **接口**: `PATCH /rooms/:room_id/messages/:message_id`
- **权限**: 需要认证
- **功能**: 编辑自己发送的文本消息
- **Handler**: `message::edit_message`
- **限制**: 仅允许编辑自己发送的文本消息

**请求示例**：
```json
{
  "content": "编辑后的消息内容"
}
```

**响应**: 返回更新后的消息对象，包含 `edited_at` 字段

### 消息反应 (Reactions)

#### 8. 添加消息反应
- **接口**: `POST /rooms/:room_id/messages/:message_id/reactions`
- **权限**: 需要认证
- **功能**: 为消息添加表情反应（toggle 模式：已存在则恢复，不存在则创建）
- **Handler**: `message::add_message_reaction`
- **支持的反应类型**: `👍` `❤️` `😂` `🎉` `😮` `😢`

**请求示例**：
```json
{
  "reaction_key": "👍"
}
```

**响应示例**：
```json
{
  "success": true,
  "message": "反应已添加",
  "summaries": [
    {
      "reaction_key": "👍",
      "count": 3,
      "has_self": true
    }
  ]
}
```

#### 9. 删除消息反应
- **接口**: `DELETE /rooms/:room_id/messages/:message_id/reactions`
- **权限**: 需要认证
- **功能**: 删除自己对消息的表情反应
- **Handler**: `message::remove_message_reaction`
- **参数传递**: query 参数（`reaction_key`）

**请求示例**：

```text
DELETE /rooms/:room_id/messages/:message_id/reactions?reaction_key=👍
```

#### 10. 获取消息反应
- **接口**: `GET /rooms/:room_id/messages/:message_id/reactions`
- **权限**: 需要认证
- **功能**: 获取消息的所有反应聚合信息
- **Handler**: `message::get_message_reactions`

**响应示例**：
```json
{
  "success": true,
  "message": "获取成功",
  "summaries": [
    {
      "reaction_key": "👍",
      "count": 5,
      "has_self": false
    },
    {
      "reaction_key": "❤️",
      "count": 2,
      "has_self": true
    }
  ]
}
```

### 消息附件

#### 11. 生成附件上传签名
- **接口**: `POST /rooms/:room_id/messages/attachments/signature`
- **权限**: 需要认证
- **功能**: 生成消息附件的直传签名（图片、文件等）
- **Handler**: `message::generate_message_attachment_signature`
- **说明**：
  - 推荐上报 `file_size + hash_value + hash_alg` 以启用秒传/去重；
  - 若响应中 `signature` 为空，表示命中去重逻辑：直接复用返回的 `key`，无需再上传与 commit。

**请求示例**：
```json
{
  "part_type": "image",
  "filename": "demo.png",
  "content_type": "image/png",
  "file_size": 12345,
  "hash_value": "e3b0c44298fc1c149afbf4c8996fb924",
  "hash_alg": 1
}
```

#### 12. 初始化分片上传
- **接口**: `POST /rooms/:room_id/messages/attachments/multipart/initiate`
- **权限**: 需要认证
- **功能**: 初始化大文件分片上传会话
- **Handler**: `message::initiate_message_attachment_multipart_upload`
- **说明**：用于大文件（如视频）的分片上传，返回 session_id 和分片信息

**请求示例**：
```json
{
  "part_type": "video",
  "filename": "demo.mp4",
  "content_type": "video/mp4",
  "file_size": 104857600
}
```

**响应示例**：
```json
{
  "session_id": "session-uuid",
  "key": "messages/{room-id}/videos/xxx.mp4",
  "upload_id": "cos-upload-id",
  "part_size": 5242880,
  "total_parts": 20
}
```

#### 13. 提交附件上传完成
- **接口**: `POST /rooms/:room_id/messages/attachments/commit`
- **权限**: 需要认证
- **功能**: 确认附件已上传到对象存储，并写入去重记录
- **Handler**: `message::commit_message_attachment_upload`
- **说明**：后端会通过对象存储 `HEAD` 校验对象存在性，并校验 `file_size`；对 `md5` 且 `ETag` 可判定为单文件 MD5 时会做哈希校验。

**请求示例**：
```json
{
  "key": "messages/{room-id}/images_20251213/abcdef01.png",
  "file_size": 12345,
  "hash_value": "e3b0c44298fc1c149afbf4c8996fb924",
  "hash_alg": 1
}
```

#### 8. 获取附件下载链接
- **接口**: `GET /rooms/:room_id/messages/attachments/download`
- **权限**: 需要认证
- **功能**: 获取消息附件的临时下载链接
- **Handler**: `message::generate_message_attachment_download_url`
- **查询参数**: `?key=xxx&expires_in_seconds=600`
- **说明**：`persist` 优先校验该 `key` 必须已被当前房间的持久化消息分片引用（附件或缩略图），否则 fallback 检查未过期 relay-only 临时授权；`relay_only` 校验发送时写入的 Redis TTL 临时授权，且附件 key 必须属于当前房间前缀 `messages/{room_id}/` 并已完成上传提交。授权缺失/过期返回 HTTP 404，Redis 授权服务不可用返回 HTTP 503；relay-only 临时授权生成的下载 URL 有效期不会超过 Redis grant 剩余 TTL。

### 消息收藏 API（API 2.0）

> 详细说明见 `messages.md` 的「消息收藏」章节。收藏仅本人可见，重复收藏幂等。

#### 14. 收藏消息
- **接口**: `POST /rooms/:room_id/messages/:message_id/favorite`
- **权限**: 需要认证（房间成员）
- **功能**: 收藏指定消息（幂等）
- **Handler**: `message_favorite::favorite_message`

#### 15. 取消收藏
- **接口**: `DELETE /rooms/:room_id/messages/:message_id/favorite`
- **权限**: 需要认证（房间成员）
- **功能**: 取消收藏；未收藏返回 404
- **Handler**: `message_favorite::unfavorite_message`

#### 16. 获取收藏列表
- **接口**: `GET /messages/favorites`
- **权限**: 需要认证
- **功能**: 分页获取本人收藏（limit 默认 50，1-100，按收藏时间倒序）
- **Handler**: `message_favorite::list_favorites`

---

## 消息已读 API

### 已读标记

#### 1. 标记单条消息已读
- **接口**: `POST /rooms/:room_id/messages/read`
- **权限**: 需要认证
- **功能**: 标记指定消息为已读；`relay_only` 下返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）
- **Handler**: `message_read::mark_message_read`

#### 2. 标记消息已读至
- **接口**: `POST /rooms/:room_id/messages/read_until`
- **权限**: 需要认证
- **功能**: 标记从某条消息之前的所有消息为已读；`relay_only` 下返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）
- **Handler**: `message_read::mark_messages_read_until`

### 未读计数

#### 3. 获取房间未读数
- **接口**: `GET /rooms/:room_id/unread_count`
- **权限**: 需要认证
- **功能**: 获取指定房间的未读消息数量；`relay_only` 下返回 0，已读游标为 `null`
- **Handler**: `message_read::get_unread_count`

#### 4. 获取所有未读数
- **接口**: `GET /unread_counts`
- **权限**: 需要认证
- **功能**: 获取所有房间的未读消息数量；`relay_only` 下所有房间返回 0，已读游标为 `null`
- **Handler**: `message_read::get_all_unread_counts`

### 已读回执

#### 5. 获取消息已读列表
- **接口**: `GET /rooms/:room_id/messages/:message_id/reads`
- **权限**: 需要认证
- **功能**: 获取消息的已读用户列表；`relay_only` 下返回 HTTP 400 ErrorResponse（`code=42201`，`message` 包含 `relay_only`）
- **Handler**: `message_read::get_message_read_list`

---

## 消息搜索 API

#### 1. 搜索消息
- **接口**: `GET /messages/search`
- **权限**: 需要认证
- **功能**: 全文搜索消息内容
- **Handler**: `message_search::search_messages`
- **查询参数**: `?query=keyword&room_id=xxx&limit=20`

#### 2. 获取搜索建议
- **接口**: `GET /messages/search/suggestions`
- **权限**: 需要认证
- **功能**: 根据输入获取搜索关键词建议
- **Handler**: `message_search::get_search_suggestions`
- **查询参数**: `?prefix=keyword&limit=10`

#### 3. 获取热门关键词
- **接口**: `GET /messages/search/trending`
- **权限**: 需要认证
- **功能**: 获取当前热门搜索关键词
- **Handler**: `message_search::get_trending_keywords`

---

## 群组管理 API

### 群组设置

#### 1. 获取群组设置
- **接口**: `GET /rooms/:room_id/settings`
- **权限**: 需要认证
- **功能**: 获取群组的设置信息（名称、头像、描述等）
- **Handler**: `group_management::get_group_settings`

#### 2. 更新群组设置
- **接口**: `PATCH /rooms/:room_id/settings`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 更新群组设置
- **Handler**: `group_management::update_group_settings`

#### 3. 获取群组详情
- **接口**: `GET /rooms/:room_id/detail`
- **权限**: 需要认证
- **功能**: 获取群组的完整详情信息
- **Handler**: `group_management::get_group_detail`

### 成员管理

#### 4. 添加群成员
- **接口**: `POST /rooms/:room_id/members`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 批量添加用户到群组
- **Handler**: `group_management::add_group_members`

**请求示例**：
```json
{
  "user_ids": ["user-uuid-1", "user-uuid-2"]
}
```

#### 5. 添加群成员（别名）
- **接口**: `POST /rooms/:room_id/members/add`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 批量添加用户到群组（与上述接口功能相同）
- **Handler**: `group_management::add_group_members`

#### 6. 移除群成员
- **接口**: `DELETE /rooms/:room_id/members/:user_id`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 将指定成员移出群组
- **Handler**: `group_management::remove_group_member`

### 群规则管理

#### 4. 获取群规则列表
- **接口**: `GET /rooms/:room_id/rules`
- **权限**: 需要认证
- **功能**: 获取群组的所有规则
- **Handler**: `group_management::list_rules`

#### 5. 创建群规则
- **接口**: `POST /rooms/:room_id/rules`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 添加新的群规则
- **Handler**: `group_management::create_rule`

#### 6. 更新群规则
- **接口**: `PATCH /rooms/:room_id/rules/:rule_id`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 修改群规则
- **Handler**: `group_management::update_rule`

#### 7. 删除群规则
- **接口**: `DELETE /rooms/:room_id/rules/:rule_id`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 删除群规则
- **Handler**: `group_management::delete_rule`

### 入群申请管理

#### 8. 获取入群申请列表
- **接口**: `GET /rooms/:room_id/join-requests`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 获取所有入群申请
- **Handler**: `group_management::list_join_requests`

#### 9. 创建入群申请
- **接口**: `POST /rooms/:room_id/join-requests`
- **权限**: 需要认证
- **功能**: 申请加入群组
- **Handler**: `group_management::create_join_request`

#### 10. 审核入群申请
- **接口**: `PATCH /rooms/:room_id/join-requests/:request_id/review`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 批准或拒绝入群申请
- **Handler**: `group_management::review_join_request`

### 群邀请管理

#### 11. 获取当前用户收到的群邀请
- **接口**: `GET /group-invitations?status=pending`
- **权限**: 需要认证
- **功能**: 查询当前用户收到的群邀请；`status` 支持 `pending`、`accepted`、`declined`、`expired` 和 `all`
- **Handler**: `group_management::list_received_invitations`

#### 12. 创建群邀请
- **接口**: `POST /rooms/:room_id/invitations`
- **权限**: 需要认证；群主、管理员可邀请，普通成员需开启 `member_can_invite`
- **功能**: 邀请用户加入群组
- **Handler**: `group_management::create_invitations`

#### 13. 响应群邀请
- **接口**: `PATCH /rooms/:room_id/invitations/:invitation_id/respond`
- **权限**: 需要认证
- **功能**: 接受或拒绝群邀请
- **Handler**: `group_management::respond_to_invitation`

### 管理员管理

#### 13. 获取管理员列表
- **接口**: `GET /rooms/:room_id/admins`
- **权限**: 需要认证
- **功能**: 获取群组的所有管理员
- **Handler**: `group_management::list_admins`

#### 14. 任命管理员
- **接口**: `POST /rooms/:room_id/admins`
- **权限**: 需要认证（需要群主权限）
- **功能**: 将成员设置为管理员
- **Handler**: `group_management::appoint_admin`

#### 15. 移除管理员
- **接口**: `DELETE /rooms/:room_id/admins/:admin_id`
- **权限**: 需要认证（需要群主权限）
- **功能**: 取消成员的管理员身份
- **Handler**: `group_management::remove_admin`

### 禁言管理

#### 16. 禁言用户
- **接口**: `POST /rooms/:room_id/mutes`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 禁言指定用户
- **Handler**: `group_management::mute_user`

#### 17. 获取禁言列表
- **接口**: `GET /rooms/:room_id/mutes`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 获取所有被禁言的用户
- **Handler**: `group_management::list_muted_users`

#### 18. 解除禁言
- **接口**: `DELETE /rooms/:room_id/mutes/:muted_user_id`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 解除用户禁言
- **Handler**: `group_management::unmute_user`

#### 19. 全员禁言设置
- **接口**: `POST /rooms/:room_id/mutes/global`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 开启或关闭全员禁言模式
- **Handler**: `group_management::update_global_mute`

**请求示例**：
```json
{
  "enabled": true,
  "reason": "会议进行中",
  "until": "2024-01-01T12:00:00Z"
}
```

### 操作日志

#### 19. 获取操作日志
- **接口**: `GET /rooms/:room_id/operation-logs`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 获取群组的管理操作记录
- **Handler**: `group_management::list_operation_logs`

---

## 管理后台 API

> 所有管理后台 API 均需要管理员权限

### 仪表盘

#### 1. 获取仪表盘统计
- **接口**: `GET /api/dashboard/stats`
- **权限**: 管理员
- **功能**: 获取系统整体统计数据（用户数、消息数等）
- **Handler**: `admin::get_dashboard_stats`

#### 2. 获取系统监控
- **接口**: `GET /api/dashboard/monitor`
- **权限**: 管理员
- **功能**: 获取系统运行状态监控数据
- **Handler**: `admin::get_system_monitor`

#### 3. 获取数据统计
- **接口**: `GET /api/dashboard/statistics`
- **权限**: 管理员
- **功能**: 获取详细的数据分析统计
- **Handler**: `admin::get_data_statistics`

#### 4. 获取存储统计
- **接口**: `GET /api/dashboard/storage-stats`
- **权限**: 管理员
- **功能**: 获取文件存储使用统计
- **Handler**: `admin::get_dashboard_storage_stats`

#### 5. 获取表情包统计
- **接口**: `GET /api/dashboard/emoji-stats`
- **权限**: 管理员
- **功能**: 获取表情包使用统计
- **Handler**: `admin::get_dashboard_emoji_stats`

### 节点监控

#### 6. 获取活跃节点列表
- **接口**: `GET /api/admin/nodes/monitor`
- **权限**: 管理员
- **功能**: 获取当前活跃的服务节点监控信息
- **Handler**: `admin::list_active_nodes_monitor`

#### 7. 获取 API 性能指标
- **接口**: `GET /api/admin/metrics/performance`
- **权限**: 管理员
- **功能**: 获取 API 响应时间、请求量等性能数据
- **Handler**: `admin::get_api_performance_stats`

### 用户管理

#### 4. 获取用户列表
- **接口**: `GET /api/admin/users`
- **权限**: 管理员
- **功能**: 分页获取所有用户列表
- **Handler**: `admin::get_user_list`
- **查询参数**: `?page=1&page_size=20&status=active`

#### 5. 创建用户
- **接口**: `POST /api/admin/users`
- **权限**: 管理员
- **功能**: 管理员创建新用户
- **Handler**: `admin::create_user`

#### 6. 获取用户详情
- **接口**: `GET /api/admin/users/:user_id`
- **权限**: 管理员
- **功能**: 获取指定用户的详细信息
- **Handler**: `admin::get_user_detail`

#### 7. 更新用户信息
- **接口**: `PATCH /api/admin/users/:user_id`
- **权限**: 管理员
- **功能**: 修改用户信息
- **Handler**: `admin::update_user`

#### 8. 删除用户
- **接口**: `DELETE /api/admin/users/:user_id`
- **权限**: 管理员
- **功能**: 删除用户账户
- **Handler**: `admin::delete_user`

#### 9. 重置用户密码
- **接口**: `POST /api/admin/users/:user_id/password/reset`
- **权限**: 管理员
- **功能**: 管理员重置用户密码
- **Handler**: `admin::reset_user_password`

#### 10. 更新用户状态
- **接口**: `PATCH /api/admin/users/:user_id/status`
- **权限**: 管理员
- **功能**: 启用/禁用用户账户
- **Handler**: `admin::update_user_status`

### 角色权限管理

#### 11. 获取权限列表
- **接口**: `GET /api/admin/permissions`
- **权限**: 管理员
- **功能**: 获取系统所有权限
- **Handler**: `admin::get_permissions`

#### 12. 获取角色列表
- **接口**: `GET /api/admin/roles`
- **权限**: 管理员
- **功能**: 获取所有角色
- **Handler**: `admin::get_roles`

#### 13. 创建角色
- **接口**: `POST /api/admin/roles`
- **权限**: 管理员
- **功能**: 创建新角色
- **Handler**: `admin::create_role`

#### 14. 更新角色
- **接口**: `PATCH /api/admin/roles/:role_id`
- **权限**: 管理员
- **功能**: 修改角色信息和权限
- **Handler**: `admin::update_role`

#### 15. 删除角色
- **接口**: `DELETE /api/admin/roles/:role_id`
- **权限**: 管理员
- **功能**: 删除角色
- **Handler**: `admin::delete_role`

#### 16. 分配角色给用户
- **接口**: `POST /api/admin/roles/assign`
- **权限**: 管理员
- **功能**: 为用户分配角色
- **Handler**: `admin::assign_role_to_user`

#### 17. 获取用户角色
- **接口**: `GET /api/admin/users/:user_id/roles`
- **权限**: 管理员
- **功能**: 获取用户拥有的所有角色
- **Handler**: `admin::get_user_roles`

#### 18. 撤销用户角色
- **接口**: `DELETE /api/admin/users/:user_id/roles/:role_id`
- **权限**: 管理员
- **功能**: 撤销用户的指定角色
- **Handler**: `admin::revoke_role_from_user`

#### 19. 检查用户权限
- **接口**: `POST /api/admin/permissions/check`
- **权限**: 管理员
- **功能**: 检查用户是否拥有指定权限
- **Handler**: `admin::check_user_permission`

#### 20. 获取角色权限
- **接口**: `GET /api/admin/roles/:role_id/permissions`
- **权限**: 管理员
- **功能**: 获取指定角色已绑定的权限 ID 与权限编码
- **Handler**: `admin::get_role_permissions`

**响应示例**：
```json
{
  "role_id": "uuid",
  "permission_ids": ["uuid"],
  "permission_codes": ["user:read"]
}
```

#### 21. 更新角色权限
- **接口**: `PUT /api/admin/roles/:role_id/permissions`
- **权限**: 管理员
- **功能**: 全量更新角色绑定的权限集合
- **Handler**: `admin::update_role_permissions`

**请求示例**：
```json
{
  "permission_ids": ["uuid"]
}
```

### 文件管理

#### 22. 获取文件统计
- **接口**: `GET /api/admin/files/stats`
- **权限**: 管理员
- **功能**: 获取文件存储统计信息
- **Handler**: `admin::get_file_management_stats`

#### 23. 获取文件列表
- **接口**: `GET /api/admin/files`
- **权限**: 管理员
- **功能**: 分页获取所有上传的文件
- **Handler**: `admin::get_file_list`
- **查询参数**: `?page=1&page_size=20`

#### 24. 删除文件
- **接口**: `DELETE /api/admin/files/:file_id`
- **权限**: 管理员
- **功能**: 删除指定文件
- **Handler**: `admin::delete_file`

#### 25. 批量删除文件
- **接口**: `POST /api/admin/files/batch-delete`
- **权限**: 管理员
- **功能**: 批量删除多个文件
- **Handler**: `admin::delete_files_batch`

### 管理员用户管理

#### 26. 获取管理员用户列表
- **接口**: `GET /api/admin/admin-users`
- **权限**: 管理员
- **功能**: 获取所有管理员用户列表
- **Handler**: `admin::get_admin_user_list`

#### 27. 创建管理员用户
- **接口**: `POST /api/admin/admin-users`
- **权限**: 管理员
- **功能**: 创建新的管理员账号
- **Handler**: `admin::create_admin_user`

**请求示例**：
```json
{
  "username": "newadmin",
  "password": "password123",
  "nickname": "新管理员"
}
```

#### 28. 更新管理员状态
- **接口**: `PATCH /api/admin/admin-users/:admin_user_id/status`
- **权限**: 管理员
- **功能**: 启用或禁用管理员账号
- **Handler**: `admin::update_admin_user_status`

#### 29. 获取管理员角色
- **接口**: `GET /api/admin/admin-users/:admin_user_id/roles`
- **权限**: 管理员
- **功能**: 获取指定管理员账号绑定的角色
- **Handler**: `admin::get_admin_user_roles`

#### 30. 更新管理员角色
- **接口**: `PUT /api/admin/admin-users/:admin_user_id/roles`
- **权限**: 管理员
- **功能**: 全量更新管理员账号绑定的角色集合
- **Handler**: `admin::update_admin_user_roles`

**请求示例**：
```json
{
  "role_ids": ["uuid"]
}
```

### 反馈管理

#### 31. 获取反馈列表
- **接口**: `GET /api/admin/feedbacks`
- **权限**: 管理员
- **功能**: 获取用户提交的反馈列表
- **Handler**: `admin::list_feedbacks`

### 举报管理

#### 32. 获取举报列表
- **接口**: `GET /api/admin/reports`
- **权限**: 管理员
- **功能**: 获取用户提交的举报列表
- **Handler**: `report::list_reports_admin`

### 系统日志管理

#### 33. 获取系统日志列表
- **接口**: `GET /api/admin/logs`
- **权限**: 管理员
- **功能**: 分页获取系统操作日志
- **Handler**: `admin::list_system_logs`

#### 34. 获取系统日志统计
- **接口**: `GET /api/admin/logs/stats`
- **权限**: 管理员
- **功能**: 获取系统日志统计信息
- **Handler**: `admin::get_system_log_stats`

#### 35. 清理系统日志
- **接口**: `POST /api/admin/logs/cleanup`
- **权限**: 管理员
- **功能**: 清理过期的系统日志
- **Handler**: `admin::cleanup_system_logs`

### Push 通知管理

#### 36. 获取 Push 发送日志
- **接口**: `GET /api/admin/push/logs`
- **权限**: 管理员
- **功能**: 获取推送发送日志，用于排障
- **Handler**: `push_logs::list_push_logs`

#### 37. 清理 Push 发送日志
- **接口**: `POST /api/admin/push/logs/cleanup`
- **权限**: 管理员
- **功能**: 清理过期的推送日志
- **Handler**: `push_logs::cleanup_push_logs`

#### 38. 获取 Push 队列统计
- **接口**: `GET /api/admin/push/job-queue/stats`
- **权限**: 管理员
- **功能**: 获取推送任务队列的统计信息
- **Handler**: `push_queue::get_push_job_queue_stats`

### 聊天记录管理

#### 39. 获取聊天记录
- **接口**: `GET /api/admin/chat-history`
- **权限**: 管理员
- **功能**: 搜索和查看聊天记录
- **Handler**: `chat_history::get_chat_history`

#### 40. 获取用户所在房间
- **接口**: `GET /api/admin/users/:user_id/rooms`
- **权限**: 管理员
- **功能**: 获取指定用户加入的所有房间
- **Handler**: `chat_history::get_user_rooms`

#### 41. 获取房间聊天记录
- **接口**: `GET /api/admin/rooms/:room_id/chat-history`
- **权限**: 管理员
- **功能**: 获取指定房间的聊天记录
- **Handler**: `chat_history::get_room_chat_history`

### 用户地理分布

#### 42. 获取用户地理分布
- **接口**: `GET /api/admin/users/geolocation/distribution`
- **权限**: 管理员
- **功能**: 获取全局用户的地理位置分布统计
- **Handler**: `activity_logs::get_global_user_distribution`

### 地理位置服务管理

#### 43. 获取 ipinfo Token 列表
- **接口**: `GET /api/admin/ipinfo-tokens`
- **权限**: 管理员
- **功能**: 分页获取 ipinfo.io Token 列表，可按状态过滤
- **Handler**: `admin::get_token_list`
- **查询参数**: `?page=1&page_size=10&status=active`

#### 44. 创建 ipinfo Token
- **接口**: `POST /api/admin/ipinfo-tokens`
- **权限**: 管理员
- **功能**: 新增 ipinfo.io Token 配置
- **Handler**: `admin::create_token`

**请求示例**：
```json
{
  "name": "default",
  "token": "ipinfo_token_value",
  "monthly_limit": 50000
}
```

#### 45. 更新 ipinfo Token
- **接口**: `PATCH /api/admin/ipinfo-tokens/:token_id`
- **权限**: 管理员
- **功能**: 更新 Token 名称、值、月配额或状态
- **Handler**: `admin::update_token`

#### 46. 删除 ipinfo Token
- **接口**: `DELETE /api/admin/ipinfo-tokens/:token_id`
- **权限**: 管理员
- **功能**: 删除指定 Token（级联删除使用记录）
- **Handler**: `admin::delete_token`

#### 47. 重置 ipinfo Token 使用量
- **接口**: `POST /api/admin/ipinfo-tokens/:token_id/reset`
- **权限**: 管理员
- **功能**: 将 Token 使用量归零并顺延一个月有效期
- **Handler**: `admin::reset_token_usage`

#### 48. 测试地理位置 API
- **接口**: `POST /api/admin/test-geolocation-api`
- **权限**: 管理员
- **功能**: 使用指定 IP 调用地理位置服务，验证 Token 与链路是否可用
- **Handler**: `admin::test_geolocation_api`

**请求示例**：
```json
{
  "ip_address": "8.8.8.8"
}
```

#### 49. 获取 IP 地理位置解析开关
- **接口**: `GET /api/admin/ip-geolocation/enabled`
- **权限**: 管理员
- **功能**: 查询 IP 地理位置解析功能是否启用
- **Handler**: `admin::get_ip_geolocation_enabled`

#### 50. 设置 IP 地理位置解析开关
- **接口**: `PATCH /api/admin/ip-geolocation/enabled`
- **权限**: 管理员
- **功能**: 启用或停用 IP 地理位置解析功能
- **Handler**: `admin::set_ip_geolocation_enabled`

**请求示例**：
```json
{
  "enabled": true
}
```

#### 51. 清理全部 App 数据（仅开发环境）
- **接口**: `POST /admin/data/cleanup/all`
- **权限**: 管理员
- **功能**: 清空 App 用户业务数据（保留系统配置与管理数据），仅开发环境可用
- **Handler**: `admin::cleanup_all_app_data`

### 文件内容审核

#### 52. 获取文件审核任务列表
- **接口**: `GET /api/admin/file-upload-audit/tasks`
- **权限**: 管理员
- **功能**: 获取文件上传审核任务列表
- **Handler**: `admin::list_file_upload_audit_tasks`

#### 53. 获取文件审核任务详情
- **接口**: `GET /api/admin/file-upload-audit/tasks/:task_id`
- **权限**: 管理员
- **功能**: 获取指定审核任务的详细信息
- **Handler**: `admin::get_file_upload_audit_task`

#### 54. 重新审核文件
- **接口**: `POST /api/admin/file-upload-audit/tasks/:task_id/requeue`
- **权限**: 管理员
- **功能**: 将审核任务重新加入队列
- **Handler**: `admin::requeue_file_upload_audit_task`

---

## 文件存储 API

### 存储提供商管理

#### 1. 获取存储提供商列表
- **接口**: `GET /api/admin/storage-providers`
- **权限**: 管理员
- **功能**: 获取所有配置的存储提供商
- **Handler**: `admin::list_storage_providers`

#### 2. 创建存储提供商
- **接口**: `POST /api/admin/storage-providers`
- **权限**: 管理员
- **功能**: 添加新的存储提供商配置
- **Handler**: `admin::create_storage_provider`

#### 3. 获取默认存储提供商
- **接口**: `GET /api/admin/storage-providers/default`
- **权限**: 管理员
- **功能**: 获取当前默认的存储提供商
- **Handler**: `admin::get_default_storage_provider`

#### 4. 更新存储提供商
- **接口**: `PATCH /api/admin/storage-providers/:provider_id`
- **权限**: 管理员
- **功能**: 修改存储提供商配置
- **Handler**: `admin::update_storage_provider`

#### 5. 删除存储提供商
- **接口**: `DELETE /api/admin/storage-providers/:provider_id`
- **权限**: 管理员
- **功能**: 删除存储提供商配置
- **Handler**: `admin::delete_storage_provider`

### 对象存储测试接口

> 以下接口用于测试 S3 兼容对象存储能力

#### 6. 测试上传
- **接口**: `POST /api/admin/storage-providers/test/upload`
- **Handler**: `admin::test_storage_upload`

#### 7. 测试上传签名
- **接口**: `POST /api/admin/storage-providers/test/upload/signature`
- **Handler**: `admin::test_storage_upload_signature`

#### 8. 测试初始化分片上传
- **接口**: `POST /api/admin/storage-providers/test/upload/multipart/initiate`
- **Handler**: `admin::test_storage_upload_multipart_initiate`

#### 9. 测试下载链接
- **接口**: `POST /api/admin/storage-providers/test/download-url`
- **Handler**: `admin::test_storage_download_url`

#### 10. 测试删除文件
- **接口**: `POST /api/admin/storage-providers/test/delete`
- **Handler**: `admin::test_storage_delete`

#### 11. 测试文件是否存在
- **接口**: `POST /api/admin/storage-providers/test/exists`
- **Handler**: `admin::test_storage_exists`

#### 12. 测试列出存储桶
- **接口**: `POST /api/admin/storage-providers/test/buckets`
- **Handler**: `admin::test_storage_list_buckets`

#### 13. 测试创建存储桶
- **接口**: `POST /api/admin/storage-providers/test/buckets/create`
- **Handler**: `admin::test_storage_create_bucket`

---

## 版本管理 API

### 客户端版本管理

#### 1. 获取最新版本
- **接口**: `GET /versions/latest`
- **权限**: 公开
- **功能**: 获取指定平台、渠道的最新启用版本
- **Handler**: `version::latest_version`
- **查询参数**: `platform`（必填），`channel`（必填，默认为 `stable`），`current_version`（可选，用于判断是否有更新）

#### 2. 获取最新版本下载链接
- **接口**: `GET /versions/latest/download-url`
- **权限**: 公开
- **功能**: 直接生成最新启用版本的临时下载链接（无需登录）
- **Handler**: `version::download_latest_version`
- **查询参数**: `platform`（必填），`channel`（必填，默认为 `stable`），`expires_in_seconds`（可选，临时链接有效期，默认存储服务默认值）
- **响应字段**: `version`（版本详情），`download_url`（临时直链）

#### 3. 下载指定版本
- **接口**: `GET /versions/download`
- **权限**: 公开
- **功能**: 为指定版本生成临时下载链接
- **Handler**: `version::download_version`
- **查询参数**: `id`（必填，版本 ID），`expires_in_seconds`（可选）

#### 4. 生成版本上传签名
- **接口**: `POST /api/admin/app-versions/upload/signature`
- **权限**: 管理员
- **功能**: 生成版本文件上传签名
- **Handler**: `version::generate_version_upload_signature`

#### 5. 获取版本列表
- **接口**: `GET /api/admin/app-versions`
- **权限**: 管理员
- **功能**: 获取所有版本记录
- **Handler**: `version::list_app_versions`

#### 6. 创建版本
- **接口**: `POST /api/admin/app-versions`
- **权限**: 管理员
- **功能**: 创建新版本记录
- **Handler**: `version::create_app_version`

#### 7. 获取版本详情
- **接口**: `GET /api/admin/app-versions/:id`
- **权限**: 管理员
- **功能**: 获取版本详细信息
- **Handler**: `version::get_app_version`

#### 8. 更新版本
- **接口**: `PATCH /api/admin/app-versions/:id`
- **权限**: 管理员
- **功能**: 修改版本信息
- **Handler**: `version::update_app_version`

#### 9. 删除版本
- **接口**: `DELETE /api/admin/app-versions/:id`
- **权限**: 管理员
- **功能**: 删除版本记录
- **Handler**: `version::delete_app_version`

#### 10. 停用版本
- **接口**: `POST /api/admin/app-versions/:id/deactivate`
- **权限**: 管理员
- **功能**: 停用指定版本
- **Handler**: `version::deactivate_app_version`

#### 11. 初始化版本分片上传
- **接口**: `POST /api/admin/app-versions/upload/multipart/initiate`
- **权限**: 管理员
- **功能**: 初始化版本文件的分片上传会话
- **Handler**: `version::initiate_version_multipart_upload`

### 热更新管理

#### 12. 获取最新热更新
- **接口**: `GET /versions/hot-update`
- **权限**: 公开
- **功能**: 检查指定版本是否有热更新
- **Handler**: `version::latest_hot_update`
- **查询参数**: `platform`，`channel`，`current_version`，`current_patch_version`

**响应示例**：
```json
{
  "has_update": true,
  "current_patch_version": "1.0.0-patch1",
  "patch": {
    "id": "patch-uuid",
    "platform": "android",
    "patch_version": "1.0.0-patch2",
    "download_url": "https://...",
    "mandatory": false
  }
}
```

#### 13. 下载热更新
- **接口**: `GET /versions/hot-update/download`
- **权限**: 公开
- **功能**: 获取热更新包的下载链接
- **Handler**: `version::download_hot_update`

#### 14. 上报热更新事件
- **接口**: `POST /versions/hot-update/report`
- **权限**: 公开
- **功能**: 客户端上报热更新应用结果（成功/失败）
- **Handler**: `version::report_hot_update_event`

**请求示例**：
```json
{
  "platform": "android",
  "base_version": "1.0.0",
  "patch_version": "1.0.0-patch1",
  "event_type": "success",
  "message": "热更新应用成功"
}
```

#### 15. 获取热更新列表（管理员）
- **接口**: `GET /api/admin/hot-updates`
- **权限**: 管理员
- **功能**: 获取所有热更新记录
- **Handler**: `version::list_hot_updates`

#### 16. 创建热更新
- **接口**: `POST /api/admin/hot-updates`
- **权限**: 管理员
- **功能**: 创建新的热更新包
- **Handler**: `version::create_hot_update`

**请求示例**：
```json
{
  "platform": "android",
  "app_version_id": "version-uuid",
  "patch_version": "1.0.0-patch1",
  "channel": "stable",
  "download_key": "hot-updates/android/1.0.0-patch1.zip",
  "mandatory": false,
  "rollout_percentage": 100
}
```

#### 17. 获取热更新详情
- **接口**: `GET /api/admin/hot-updates/:id`
- **权限**: 管理员
- **功能**: 获取热更新详细信息
- **Handler**: `version::get_hot_update`

#### 18. 更新热更新
- **接口**: `PATCH /api/admin/hot-updates/:id`
- **权限**: 管理员
- **功能**: 修改热更新信息
- **Handler**: `version::update_hot_update`

#### 19. 删除热更新
- **接口**: `DELETE /api/admin/hot-updates/:id`
- **权限**: 管理员
- **功能**: 删除热更新记录
- **Handler**: `version::delete_hot_update`

#### 20. 激活热更新
- **接口**: `POST /api/admin/hot-updates/:id/activate`
- **权限**: 管理员
- **功能**: 激活热更新，使其对用户可见
- **Handler**: `version::activate_hot_update`

#### 21. 停用热更新
- **接口**: `POST /api/admin/hot-updates/:id/deactivate`
- **权限**: 管理员
- **功能**: 停用热更新
- **Handler**: `version::deactivate_hot_update`

#### 22. 获取热更新事件列表
- **接口**: `GET /api/admin/hot-updates/events`
- **权限**: 管理员
- **功能**: 获取客户端上报的热更新事件
- **Handler**: `version::list_hot_update_events`

---

## 系统设置 API

### 隐私政策

#### 1. 获取隐私政策（公开）
- **接口**: `GET /settings/privacy-policy`
- **权限**: 公开
- **功能**: 获取系统隐私政策内容
- **Handler**: `settings::get_privacy_policy`

#### 2. 获取隐私政策（管理员）
- **接口**: `GET /api/admin/settings/privacy-policy`
- **权限**: 管理员
- **功能**: 管理员获取隐私政策（含编辑信息）
- **Handler**: `settings::get_privacy_policy_admin`

#### 3. 更新隐私政策
- **接口**: `POST /api/admin/settings/privacy-policy`
- **权限**: 管理员
- **功能**: 更新隐私政策内容
- **Handler**: `settings::update_privacy_policy`

### 用户协议

#### 4. 获取用户协议（公开）
- **接口**: `GET /settings/user-agreement`
- **权限**: 公开
- **功能**: 获取系统用户协议内容
- **Handler**: `settings::get_user_agreement`

#### 5. 获取用户协议（管理员）
- **接口**: `GET /api/admin/settings/user-agreement`
- **权限**: 管理员
- **功能**: 管理员获取用户协议（含编辑信息）
- **Handler**: `settings::get_user_agreement_admin`

#### 6. 更新用户协议
- **接口**: `POST /api/admin/settings/user-agreement`
- **权限**: 管理员
- **功能**: 更新用户协议内容
- **Handler**: `settings::update_user_agreement`

### 通用设置

#### 7. 获取通用设置（公开）
- **接口**: `GET /settings/general`
- **权限**: 公开
- **功能**: 获取系统通用配置（如功能开关）；返回 `message_runtime.server_storage_mode` 和 `message_runtime.content_audit_mode`
- **Handler**: `settings::get_general_settings`

#### 8. 获取应用名称（公开）
- **接口**: `GET /settings/app-name`
- **权限**: 公开
- **功能**: 获取应用显示名称
- **Handler**: `settings::get_app_name`

#### 9. 更新应用名称
- **接口**: `PUT /api/admin/settings/app-name`
- **权限**: 管理员
- **功能**: 更新应用显示名称
- **Handler**: `settings::update_app_name`

#### 10. 获取消息运行模式（管理员）
- **接口**: `GET /api/admin/settings/message-runtime`
- **权限**: 管理员
- **功能**: 获取全局消息运行模式配置
- **Handler**: `settings::get_message_runtime_settings_admin`
- **响应字段**:
  - `server_storage_mode`: `persist` 或 `relay_only`
  - `content_audit_mode`: `plaintext` 或 `e2ee`
  - `updated_at`: 最近更新时间，可为 `null`
  - `updated_by`: 最近更新管理员 ID，可为 `null`

#### 11. 更新消息运行模式
- **接口**: `PUT /api/admin/settings/message-runtime`
- **权限**: 管理员
- **功能**: 更新全局消息运行模式
- **Handler**: `settings::update_message_runtime_settings_admin`
- **请求体**:
```json
{
  "server_storage_mode": "relay_only",
  "content_audit_mode": "plaintext"
}
```
- **说明**: `server_storage_mode` 仅支持 `persist` / `relay_only`；`content_audit_mode` 仅支持 `plaintext` / `e2ee`。非法值返回 HTTP 400 ErrorResponse（`code=42201`）。

### 验证码设置

#### 12. 获取验证码设置（公开）
- **接口**: `GET /settings/captcha`
- **权限**: 公开
- **功能**: 获取验证码配置（是否启用等）
- **Handler**: `settings::get_captcha_setting_public`

#### 13. 获取验证码设置（管理员）
- **接口**: `GET /api/admin/settings/captcha`
- **权限**: 管理员
- **功能**: 获取验证码完整配置
- **Handler**: `admin::get_captcha_setting`

#### 14. 更新验证码设置
- **接口**: `POST /api/admin/settings/captcha`
- **权限**: 管理员
- **功能**: 修改验证码配置
- **Handler**: `admin::update_captcha_setting`

### 用户账户限制

#### 15. 获取用户账户限制
- **接口**: `GET /api/admin/settings/user-account-limit`
- **权限**: 管理员
- **功能**: 获取用户账户相关限制配置和邮箱注册/登录兼容开关
- **Handler**: `settings::get_user_account_limit`

#### 16. 更新用户账户限制
- **接口**: `PUT /api/admin/settings/user-account-limit`
- **权限**: 管理员
- **功能**: 更新用户账户限制配置和邮箱注册/登录兼容开关
- **Handler**: `settings::update_user_account_limit`

### 上传策略配置

#### 17. 获取上传策略（用户）
- **接口**: `GET /system/upload-policy`
- **权限**: 需要认证
- **功能**: 获取当前文件上传策略（大小限制、类型限制等）
- **Handler**: `upload_policy::get_upload_policy_user`

#### 18. 获取上传策略（管理员）
- **接口**: `GET /api/admin/settings/upload-policy`
- **权限**: 管理员
- **功能**: 获取完整上传策略配置
- **Handler**: `upload_policy::get_upload_policy_admin`

#### 19. 更新上传策略
- **接口**: `PUT /api/admin/settings/upload-policy`
- **权限**: 管理员
- **功能**: 更新上传策略配置
- **Handler**: `upload_policy::update_upload_policy_admin`

### Push 平台配置

#### 20. 获取 Push 设置
- **接口**: `GET /api/admin/settings/push`
- **权限**: 管理员
- **功能**: 获取推送服务配置
- **Handler**: `push_settings::get_push_settings_admin`

#### 21. 更新 Push 设置
- **接口**: `PUT /api/admin/settings/push`
- **权限**: 管理员
- **功能**: 更新推送服务配置
- **Handler**: `push_settings::update_push_settings_admin`

#### 22. 更新 Push 提供商配置
- **接口**: `PUT /api/admin/settings/push/providers/:provider`
- **权限**: 管理员
- **功能**: 更新指定推送提供商（fcm/apns）的配置
- **Handler**: `push_settings::upsert_push_provider_admin`

#### 23. 测试 Push 发送
- **接口**: `POST /api/admin/settings/push/test`
- **权限**: 管理员
- **功能**: 发送测试推送消息
- **Handler**: `push_settings::test_push_admin`

---

## Push 通知 API

### 设备管理

#### 1. 注册推送设备
- **接口**: `POST /push/devices`
- **权限**: 需要认证
- **功能**: 注册或更新推送设备 token（支持 token 刷新）
- **Handler**: `push::register_device`

**请求示例**：
```json
{
  "device_id": "device-unique-id",
  "platform": "android",
  "channel": "fcm",
  "device_token": "fcm-device-token..."
}
```

**参数说明**：
- `device_id`: 设备唯一标识（最大 128 字符）
- `platform`: 平台类型（`android` / `ios`）
- `channel`: 推送通道（`fcm` / `apns`）
- `device_token`: 推送服务下发的设备 token（最大 4096 字符）

**响应示例**：
```json
{
  "success": true,
  "message": "设备已注册",
  "device_id": "device-unique-id"
}
```

#### 2. 注销推送设备
- **接口**: `DELETE /push/devices/:device_id`
- **权限**: 需要认证
- **功能**: 注销（软禁用）推送设备
- **Handler**: `push::unregister_device`

**响应示例**：
```json
{
  "success": true,
  "message": "设备已注销"
}
```

---

## 其他 API

### 反馈

#### 1. 提交反馈
- **接口**: `POST /feedbacks`
- **权限**: 需要认证
- **功能**: 用户提交问题反馈或建议
- **Handler**: `feedback::submit_feedback`

### 健康检查

#### 1. 根路径
- **接口**: `GET /`
- **权限**: 公开
- **功能**: API 根路径，返回服务信息
- **Handler**: `root`

#### 2. 健康检查
- **接口**: `GET /healthz`
- **权限**: 公开
- **功能**: 服务健康状态检查
- **Handler**: `healthz`

#### 3. 就绪检查
- **接口**: `GET /readyz`
- **权限**: 公开
- **功能**: 服务就绪状态检查（包括数据库连接等）
- **Handler**: `health::readyz`

### 举报

#### 4. 提交举报
- **接口**: `POST /reports`
- **权限**: 需要认证
- **功能**: 用户举报违规内容或用户
- **Handler**: `report::create_report`

#### 5. 生成举报附件上传签名
- **接口**: `POST /reports/attachments/signature`
- **权限**: 需要认证
- **功能**: 生成举报截图等附件的上传签名
- **Handler**: `report::generate_report_attachment_signature`

#### 6. 提交举报附件上传完成
- **接口**: `POST /reports/attachments/commit`
- **权限**: 需要认证
- **功能**: 确认举报附件上传完成
- **Handler**: `report::commit_report_attachment_upload`

---

## Activity Logs API

### 心跳日志

#### 1. 提交心跳日志
- **接口**: `POST /activity/heartbeat`
- **权限**: 需要认证
- **功能**: 客户端定期上报在线状态
- **Handler**: `activity_logs::create_heartbeat_log`

### 登录历史

#### 2. 创建登录历史
- **接口**: `POST /activity/login`
- **权限**: 需要认证
- **功能**: 记录用户登录信息（设备、IP、位置等）
- **Handler**: `activity_logs::create_login_history`

**请求示例**：
```json
{
  "device_id": "device-uuid",
  "device_type": "mobile",
  "os": "iOS 17.0",
  "app_version": "1.0.0"
}
```

#### 3. 更新登出时间
- **接口**: `POST /activity/login/:log_id/logout`
- **权限**: 需要认证
- **功能**: 更新登录记录的登出时间
- **Handler**: `activity_logs::update_login_logout`

#### 4. 获取用户登录历史
- **接口**: `GET /users/:user_id/activity/login-history`
- **权限**: 需要认证
- **功能**: 获取指定用户的登录历史记录
- **Handler**: `activity_logs::get_user_login_history`

#### 5. 获取用户心跳日志
- **接口**: `GET /users/:user_id/activity/heartbeat-logs`
- **权限**: 需要认证
- **功能**: 获取指定用户的心跳日志
- **Handler**: `activity_logs::get_user_heartbeat_logs`

#### 6. 获取用户地理位置
- **接口**: `GET /users/:user_id/geolocation`
- **权限**: 需要认证
- **功能**: 获取指定用户的最后已知地理位置
- **Handler**: `activity_logs::get_user_geolocation`

---

## Emoji Pack API（贴纸表情包）

### 用户接口

#### 1. 获取可用贴纸包列表
- **接口**: `GET /emoji-packs/available`
- **权限**: 需要认证
- **功能**: 获取所有公开可用的贴纸包
- **Handler**: `emoji_pack::list_available_packs`

#### 2. 搜索贴纸包
- **接口**: `GET /emoji-packs/search`
- **权限**: 需要认证
- **功能**: 根据关键词搜索贴纸包
- **Handler**: `emoji_pack::search_packs`
- **查询参数**: `?q=keyword`

#### 3. 获取我的贴纸包
- **接口**: `GET /emoji-packs/my`
- **权限**: 需要认证
- **功能**: 获取当前用户已添加的贴纸包
- **Handler**: `emoji_pack::list_user_packs`

#### 4. 获取贴纸下载链接
- **接口**: `GET /emoji-packs/download-url`
- **权限**: 需要认证
- **功能**: 获取贴纸图片的临时下载链接
- **Handler**: `emoji_pack::get_emoji_download_url`
- **查询参数**: `?key=xxx`

#### 5. 添加贴纸包
- **接口**: `POST /emoji-packs/:pack_id/add`
- **权限**: 需要认证
- **功能**: 将贴纸包添加到个人收藏
- **Handler**: `emoji_pack::add_user_pack`

#### 6. 添加贴纸套件
- **接口**: `POST /emoji-packs/suites/:suite_id/add`
- **权限**: 需要认证
- **功能**: 将整个贴纸套件添加到个人收藏
- **Handler**: `emoji_pack::add_user_suite`

#### 7. 移除贴纸包
- **接口**: `DELETE /emoji-packs/:pack_id/remove`
- **权限**: 需要认证
- **功能**: 从个人收藏中移除贴纸包
- **Handler**: `emoji_pack::remove_user_pack`

#### 8. 获取套件内贴纸包
- **接口**: `GET /emoji-packs/suites/:suite_id/packs`
- **权限**: 需要认证
- **功能**: 获取指定套件中的所有贴纸包
- **Handler**: `emoji_pack::list_user_suite_packs`

### 管理员接口

#### 9. 获取所有贴纸包（管理员）
- **接口**: `GET /api/admin/emoji-packs`
- **权限**: 管理员
- **功能**: 获取所有贴纸包列表
- **Handler**: `emoji_pack::list_all_packs`

#### 10. 创建贴纸包
- **接口**: `POST /api/admin/emoji-packs`
- **权限**: 管理员
- **功能**: 创建新的贴纸包
- **Handler**: `emoji_pack::create_pack`

#### 11. 获取贴纸包详情
- **接口**: `GET /api/admin/emoji-packs/:pack_id`
- **权限**: 管理员
- **功能**: 获取贴纸包详细信息
- **Handler**: `emoji_pack::get_pack`

#### 12. 更新贴纸包
- **接口**: `PATCH /api/admin/emoji-packs/:pack_id`
- **权限**: 管理员
- **功能**: 更新贴纸包信息
- **Handler**: `emoji_pack::update_pack`

#### 13. 删除贴纸包
- **接口**: `DELETE /api/admin/emoji-packs/:pack_id`
- **权限**: 管理员
- **功能**: 删除贴纸包
- **Handler**: `emoji_pack::delete_pack`

#### 14. 创建贴纸项
- **接口**: `POST /api/admin/emoji-items`
- **权限**: 管理员
- **功能**: 在贴纸包中添加贴纸项
- **Handler**: `emoji_pack::create_item`

#### 15. 获取贴纸项详情
- **接口**: `GET /api/admin/emoji-items/:item_id`
- **权限**: 管理员
- **功能**: 获取贴纸项详细信息
- **Handler**: `emoji_pack::get_item`

#### 16. 更新贴纸项
- **接口**: `PATCH /api/admin/emoji-items/:item_id`
- **权限**: 管理员
- **功能**: 更新贴纸项信息
- **Handler**: `emoji_pack::update_item`

#### 17. 删除贴纸项
- **接口**: `DELETE /api/admin/emoji-items/:item_id`
- **权限**: 管理员
- **功能**: 删除贴纸项
- **Handler**: `emoji_pack::delete_item`

---

## 分片上传 API

> 用于大文件的分片上传，支持用户和管理员两种角色

### 用户分片上传

#### 1. 获取分片上传会话
- **接口**: `GET /uploads/multipart/sessions/:session_id`
- **权限**: 需要认证
- **功能**: 获取分片上传会话信息
- **Handler**: `multipart_upload::get_multipart_session`

#### 2. 生成分片上传签名
- **接口**: `POST /uploads/multipart/sessions/:session_id/parts/signature`
- **权限**: 需要认证
- **功能**: 生成单个分片的上传签名
- **Handler**: `multipart_upload::generate_multipart_part_signature`

**请求示例**：
```json
{
  "part_number": 1
}
```

#### 3. 提交分片上传完成
- **接口**: `POST /uploads/multipart/sessions/:session_id/parts/commit`
- **权限**: 需要认证
- **功能**: 确认单个分片上传完成
- **Handler**: `multipart_upload::commit_multipart_part`

**请求示例**：
```json
{
  "part_number": 1,
  "etag": "abc123..."
}
```

#### 4. 完成分片上传
- **接口**: `POST /uploads/multipart/sessions/:session_id/complete`
- **权限**: 需要认证
- **功能**: 合并所有分片，完成整个文件上传
- **Handler**: `multipart_upload::complete_multipart_upload`

#### 5. 取消分片上传
- **接口**: `POST /uploads/multipart/sessions/:session_id/abort`
- **权限**: 需要认证
- **功能**: 取消分片上传，清理已上传的分片
- **Handler**: `multipart_upload::abort_multipart_upload`

### 管理员分片上传

> 管理员路由前缀为 `/api/admin/uploads/multipart/sessions`，功能与用户路由相同

---

## WebSocket 接口

### 连接

#### WebSocket 连接地址
- **接口**: `GET /ws`
- **权限**: 需要认证
- **协议**: WebSocket
- **Handler**: `ws`

#### 连接参数
- `token`: JWT Token（通过查询参数传递）
- `format`: 消息格式，可选值：
  - `json` (默认): JSON 格式
  - `proto/protobuf/pb/binary`: Protocol Buffers 二进制格式

示例：
```
ws://localhost:8010/ws?token=<your-jwt-token>&format=json
```

### 连接管理器功能

#### 特性
- **多连接支持**: 同一用户可以有多个并发连接（多设备）
- **房间订阅**: 自动管理用户对房间的订阅
- **心跳机制**: Ping/Pong 保持连接活跃
- **连接追踪**: 记录连接时间、最后活跃时间等

#### 连接信息
```rust
pub struct ConnectionInfo {
    pub user_id: String,              // 用户 ID
    pub connected_at: DateTime<Utc>,   // 连接时间
    pub last_ping: DateTime<Utc>,     // 最后 Ping 时间
    pub format: ConnectionFormat,      // 消息格式
    pub sender: mpsc::UnboundedSender<OutboundFrame>,  // 消息发送通道
}
```

### 服务端推送事件

WebSocket 服务端会向客户端推送以下类型的事件：

#### 1. authed - 认证成功
客户端连接并认证成功后推送
```json
{
  "type": "authed",
  "user_id": "user-uuid",
  "conn_id": "connection-uuid"
}
```

#### 2. joined - 加入房间
用户成功加入房间后推送
```json
{
  "type": "joined",
  "room_id": "room-uuid"
}
```

#### 3. left - 离开房间
用户离开房间后推送
```json
{
  "type": "left",
  "room_id": "room-uuid"
}
```

#### 4. message - 新消息
房间中有新消息时推送给所有订阅该房间的用户
```json
{
  "type": "message",
  "message_id": "message-uuid",
  "room_id": "room-uuid",
  "sender_id": "user-uuid",
  "sender_name": "用户昵称",
  "parts": [
    {
      "type": "text",
      "data": "消息内容"
    }
  ],
  "quoted_message": null,  // 引用的消息
  "forward_message": null, // 转发的消息
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### 5. message_read - 消息已读回执
有用户读取消息时推送
```json
{
  "type": "message_read",
  "message_id": "message-uuid",
  "room_id": "room-uuid",
  "user_id": "user-uuid",
  "read_at": "2024-01-01T00:00:00Z"
}
```

#### 6. message_update - 消息更新
消息被更新（编辑、删除等）时推送
```json
{
  "type": "message_update",
  "message_id": "message-uuid",
  "room_id": "room-uuid",
  "update_type": "deleted",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

#### 7. pin_update - 置顶更新
消息被置顶或取消置顶时推送
```json
{
  "type": "pin_update",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "pinned_by": "user-uuid",
  "pinned_at": "2024-01-01T00:00:00Z",
  "is_pinned": true
}
```

#### 8. friend_request_update - 好友请求更新
收到新的好友请求时推送
```json
{
  "type": "friend_request_update",
  "pending_count": 5
}
```

#### 9. room_created - 房间创建
用户被邀请加入新房间时推送
```json
{
  "type": "room_created",
  "room_id": "room-uuid",
  "room_name": "群聊名称",
  "room_type": "group",
  "initiator_id": "user-uuid",
  "owner_id": "user-uuid",
  "description": "群简介",
  "avatar_url": "https://...",
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### 10. error - 错误
服务端发生错误时推送
```json
{
  "type": "error",
  "message": "错误描述"
}
```

#### 11. pong - 心跳响应
响应客户端的 ping 请求
```json
{
  "type": "pong"
}
```

#### 12. reaction_update - 消息反应更新
有用户添加或删除消息反应时推送
```json
{
  "type": "reaction_update",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "reaction_key": "👍",
  "user_id": "user-uuid",
  "action": "add"
}
```
- `action`: `"add"` 添加反应 | `"remove"` 删除反应

#### 13. typing_update - 正在输入
有用户在房间中输入时推送
```json
{
  "type": "typing_update",
  "room_id": "room-uuid",
  "user_id": "user-uuid",
  "is_typing": true,
  "expires_in_ms": 3000
}
```
- `expires_in_ms`: 输入状态过期时间（毫秒），客户端应在过期后自动清除显示

#### 14. room_updated - 房间信息更新
房间名称、头像、描述等信息变更时推送
```json
{
  "type": "room_updated",
  "room_id": "room-uuid",
  "room_name": "新群名称",
  "room_type": "group",
  "avatar_url": "https://...",
  "avatar_object_key": "rooms/xxx/avatar.png",
  "description": "新的群描述"
}
```

#### 15. user_banned - 用户被封禁
当前用户被封禁时推送
```json
{
  "type": "user_banned",
  "user_id": "user-uuid",
  "reason": "违规操作"
}
```

#### 16. group_dissolved - 群组解散
群组被解散时推送给所有成员
```json
{
  "type": "group_dissolved",
  "room_id": "room-uuid"
}
```

#### 17. group_owner_transferred - 群主转让
群主身份转让时推送
```json
{
  "type": "group_owner_transferred",
  "room_id": "room-uuid",
  "old_owner_id": "user-uuid",
  "new_owner_id": "user-uuid"
}
```

#### 18. group_settings_updated - 群设置更新
群组设置（如全员禁言）变更时推送
```json
{
  "type": "group_settings_updated",
  "room_id": "room-uuid",
  "global_mute_enabled": true,
  "global_mute_reason": "会议进行中",
  "global_mute_until": "2024-01-01T12:00:00Z",
  "global_mute_set_by": "user-uuid"
}
```

#### 19. group_member_changed - 群成员变更
成员加入、退出、被禁言、角色变更等时推送
```json
{
  "type": "group_member_changed",
  "room_id": "room-uuid",
  "member_id": "user-uuid",
  "change_type": "muted",
  "new_role": null,
  "operator_id": "admin-uuid",
  "reason": "发送广告",
  "until": "2024-01-01T12:00:00Z"
}
```
- `change_type`: `"joined"` | `"left"` | `"kicked"` | `"muted"` | `"unmuted"` | `"role_changed"`

#### 20. room_history_cleared - 房间历史清除
房间聊天记录被清空时推送
```json
{
  "type": "room_history_cleared",
  "room_id": "room-uuid",
  "cleared_by": "admin-uuid",
  "cleared_at": "2024-01-01T00:00:00Z"
}
```

#### 21. friendship_deleted - 好友关系删除
好友关系被删除时推送
```json
{
  "type": "friendship_deleted",
  "user_id": "friend-uuid"
}
```

#### 22. friend_profile_updated - 好友资料更新
好友的用户资料变更时推送
```json
{
  "type": "friend_profile_updated",
  "user_id": "friend-uuid",
  "username": "newusername",
  "nickname": "新昵称",
  "avatar_url": "https://...",
  "avatar_object_key": "avatars/xxx.png"
}
```

### 客户端发送事件

客户端可以通过 WebSocket 发送以下事件：

#### 1. auth - 认证
```json
{
  "type": "auth",
  "token": "jwt-token"
}
```

#### 2. join - 加入房间
```json
{
  "type": "join",
  "room_id": "room-uuid"
}
```

#### 3. leave - 离开房间
```json
{
  "type": "leave",
  "room_id": "room-uuid"
}
```

#### 4. ping - 心跳
```json
{
  "type": "ping"
}
```

#### 5. typing - 正在输入
```json
{
  "type": "typing",
  "room_id": "room-uuid",
  "is_typing": true
}
```
- 服务端会对 typing 事件进行节流（约 1200ms），避免频繁广播
- 发送消息、离开房间或断开连接时会自动清除 typing 状态

### 消息格式

#### JSON 格式
默认使用 JSON 格式，所有消息都是 UTF-8 编码的 JSON 字符串。

#### Protocol Buffers 格式
使用二进制 Protocol Buffers 格式，性能更高，带宽占用更少。

协议定义位置: `api/proto/ws.proto`

---

## 附录

### API 统计

- **公开路由**: 28 个
- **需要认证的路由**: 114 个
- **管理后台路由**: 95 个
- **路由总数**: 237 个
- **WebSocket 事件类型**: 24 种（服务端推送） + 6 种（客户端发送）

### Handler 模块列表

1. `activity_logs.rs` - 活动日志
2. `admin.rs` - 管理后台
3. `admin_storage_config.rs` - 存储配置管理
4. `auth.rs` - 认证相关
5. `auth_device.rs` - 登录设备
6. `chat_history.rs` - 聊天记录管理
7. `e2ee.rs` - E2EE / MLS
8. `emoji_pack.rs` - 贴纸表情包
9. `feedback.rs` - 反馈系统
10. `friend.rs` - 好友系统
11. `group_announcement.rs` - 群公告
12. `group_management.rs` - 群组管理
13. `health.rs` - 就绪检查
14. `message.rs` - 消息处理（含 reactions）
15. `message_favorite.rs` - 消息收藏
16. `message_read.rs` - 消息已读
17. `message_search.rs` - 消息搜索
18. `multipart_upload.rs` - 分片上传
19. `push.rs` - Push 通知
20. `push_settings.rs` - Push 配置
21. `push_logs.rs` - Push 日志
22. `push_queue.rs` - Push 队列
23. `qr_login.rs` - 扫码登录
24. `report.rs` - 举报系统
25. `room.rs` - 房间管理
26. `settings.rs` - 系统设置
27. `upload_policy.rs` - 上传策略
28. `user.rs` - 用户管理
29. `user_block.rs` - 黑名单
30. `version.rs` - 版本管理
31. `websocket/mod.rs` - WebSocket

### 技术栈

- **Web 框架**: Axum 0.8.6
- **异步运行时**: Tokio 1.44
- **数据库**: PostgreSQL 17 + SQLx 0.8.6
- **缓存**: Redis 7 (redis 0.32.7)
- **序列化**: Protocol Buffers (prost 0.14.1)
- **认证**: JWT (jsonwebtoken 9.3)
- **密码加密**: bcrypt 0.16
- **HTTP 客户端**: reqwest 0.12

---

**文档最后更新**: 2026-08-05
**API 版本**: 2.0.0
