# RedCode IM Backend API 完整参考文档

> 本文档用于记录当前已实现的 REST API 与 WebSocket 接口入口；若与代码不一致，以 `backend/src/routes.rs` 为准。

## 📋 目录

- [基础信息](#基础信息)
- [认证 API](#认证-api)
- [用户管理 API](#用户管理-api)
- [好友系统 API](#好友系统-api)
- [房间/群组 API](#房间群组-api)
- [消息 API](#消息-api)
- [消息已读 API](#消息已读-api)
- [消息搜索 API](#消息搜索-api)
- [群组管理 API](#群组管理-api)
- [管理后台 API](#管理后台-api)
- [文件存储 API](#文件存储-api)
- [版本管理 API](#版本管理-api)
- [系统设置 API](#系统设置-api)
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

当接口返回非 2xx 时，响应体遵循统一结构（见 `backend/src/error.rs`）：
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
- **功能**: 创建新用户账户
- **Handler**: `auth::register`

#### 2. 用户登录
- **接口**: `POST /auth/login`
- **权限**: 公开
- **功能**: 用户名/密码登录
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

### 需要认证的路由

#### 5. 获取当前用户信息
- **接口**: `GET /auth/me`
- **权限**: 需要认证
- **功能**: 获取当前登录用户的详细信息
- **Handler**: `auth::get_current_user`

#### 6. 短信重置密码
- **接口**: `POST /auth/password/reset`
- **权限**: 需要认证
- **功能**: 通过短信验证码重置密码
- **Handler**: `auth::reset_password_with_sms`

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

---

## 房间/群组 API

### 聊天列表

#### 1. 获取聊天摘要列表
- **接口**: `GET /chats`
- **权限**: 需要认证
- **功能**: 获取所有聊天的摘要信息（包括最后一条消息、未读数等）
- **Handler**: `room::list_chat_summaries`

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

---

## 消息 API

### 消息发送与获取

#### 1. 发送消息
- **接口**: `POST /rooms/:room_id/messages`
- **权限**: 需要认证
- **功能**: 在指定房间发送消息
- **Handler**: `message::send_message`

#### 2. 获取消息列表
- **接口**: `GET /rooms/:room_id/messages`
- **权限**: 需要认证
- **功能**: 分页获取房间的历史消息
- **Handler**: `message::list_messages`
- **查询参数**: `?cursor=xxx&limit=50`

### 消息操作

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

### 消息附件

#### 7. 生成附件上传签名
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

#### 8. 提交附件上传完成
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
- **查询参数**: `?key=xxx`
- **说明**：后端会校验该 `key` 必须已被当前房间的消息引用（附件或缩略图），否则返回 404。

---

## 消息已读 API

### 已读标记

#### 1. 标记单条消息已读
- **接口**: `POST /rooms/:room_id/messages/read`
- **权限**: 需要认证
- **功能**: 标记指定消息为已读
- **Handler**: `message_read::mark_message_read`

#### 2. 标记消息已读至
- **接口**: `POST /rooms/:room_id/messages/read_until`
- **权限**: 需要认证
- **功能**: 标记从某条消息之前的所有消息为已读
- **Handler**: `message_read::mark_messages_read_until`

### 未读计数

#### 3. 获取房间未读数
- **接口**: `GET /rooms/:room_id/unread_count`
- **权限**: 需要认证
- **功能**: 获取指定房间的未读消息数量
- **Handler**: `message_read::get_unread_count`

#### 4. 获取所有未读数
- **接口**: `GET /unread_counts`
- **权限**: 需要认证
- **功能**: 获取所有房间的未读消息数量
- **Handler**: `message_read::get_all_unread_counts`

### 已读回执

#### 5. 获取消息已读列表
- **接口**: `GET /rooms/:room_id/messages/:message_id/reads`
- **权限**: 需要认证
- **功能**: 获取消息的已读用户列表
- **Handler**: `message_read::get_message_read_list`

---

## 消息搜索 API

#### 1. 搜索消息
- **接口**: `GET /messages/search`
- **权限**: 需要认证
- **功能**: 全文搜索消息内容
- **Handler**: `message_search::search_messages`
- **查询参数**: `?q=keyword&room_id=xxx&limit=20`

#### 2. 获取搜索建议
- **接口**: `GET /messages/search/suggestions`
- **权限**: 需要认证
- **功能**: 根据输入获取搜索关键词建议
- **Handler**: `message_search::get_search_suggestions`
- **查询参数**: `?q=keyword`

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

#### 11. 创建群邀请
- **接口**: `POST /rooms/:room_id/invitations`
- **权限**: 需要认证（需要管理员权限）
- **功能**: 邀请用户加入群组
- **Handler**: `group_management::create_invitations`

#### 12. 响应群邀请
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

### 文件管理

#### 20. 获取文件统计
- **接口**: `GET /api/admin/files/stats`
- **权限**: 管理员
- **功能**: 获取文件存储统计信息
- **Handler**: `admin::get_file_management_stats`

#### 21. 获取文件列表
- **接口**: `GET /api/admin/files`
- **权限**: 管理员
- **功能**: 分页获取所有上传的文件
- **Handler**: `admin::get_file_list`
- **查询参数**: `?page=1&page_size=20`

#### 22. 删除文件
- **接口**: `DELETE /api/admin/files/:file_id`
- **权限**: 管理员
- **功能**: 删除指定文件
- **Handler**: `admin::delete_file`

#### 23. 批量删除文件
- **接口**: `POST /api/admin/files/batch-delete`
- **权限**: 管理员
- **功能**: 批量删除多个文件
- **Handler**: `admin::delete_files_batch`

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

### COS 测试接口

> 以下接口用于测试腾讯云 COS 存储功能

#### 6. 测试上传
- **接口**: `POST /api/admin/storage-providers/test/upload`
- **Handler**: `admin::test_cos_upload`

#### 7. 测试上传签名
- **接口**: `POST /api/admin/storage-providers/test/upload/signature`
- **Handler**: `admin::test_cos_upload_signature`

#### 8. 测试下载链接
- **接口**: `POST /api/admin/storage-providers/test/download-url`
- **Handler**: `admin::test_cos_download_url`

#### 9. 测试获取 CORS 配置
- **接口**: `POST /api/admin/storage-providers/test/cors/list`
- **Handler**: `admin::test_cos_get_cors`

#### 10. 测试设置 CORS
- **接口**: `POST /api/admin/storage-providers/test/cors`
- **Handler**: `admin::test_cos_set_cors`

#### 11. 测试删除文件
- **接口**: `POST /api/admin/storage-providers/test/delete`
- **Handler**: `admin::test_cos_delete`

#### 12. 测试文件是否存在
- **接口**: `POST /api/admin/storage-providers/test/exists`
- **Handler**: `admin::test_cos_exists`

#### 13. 测试列出存储桶
- **接口**: `POST /api/admin/storage-providers/test/buckets`
- **Handler**: `admin::test_cos_list_buckets`

#### 14. 测试创建存储桶
- **接口**: `POST /api/admin/storage-providers/test/buckets/create`
- **Handler**: `admin::test_cos_create_bucket`

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

### 验证码设置

#### 4. 获取验证码设置
- **接口**: `GET /api/admin/settings/captcha`
- **权限**: 管理员
- **功能**: 获取验证码配置
- **Handler**: `admin::get_captcha_setting`

#### 5. 更新验证码设置
- **接口**: `POST /api/admin/settings/captcha`
- **权限**: 管理员
- **功能**: 修改验证码配置
- **Handler**: `admin::update_captcha_setting`

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

### 消息格式

#### JSON 格式
默认使用 JSON 格式，所有消息都是 UTF-8 编码的 JSON 字符串。

#### Protocol Buffers 格式
使用二进制 Protocol Buffers 格式，性能更高，带宽占用更少。

协议定义位置: `backend/src/proto/ws.proto`

---

## 附录

### API 统计

- **公开路由**: 9 个
- **需要认证的路由**: 100+ 个
- **管理后台路由**: 40+ 个
- **WebSocket 事件类型**: 11 种

### Handler 模块列表

1. `auth.rs` - 认证相关
2. `user.rs` - 用户管理
3. `friend.rs` - 好友系统
4. `room.rs` - 房间管理
5. `message.rs` - 消息处理
6. `message_read.rs` - 消息已读
7. `message_search.rs` - 消息搜索
8. `group_management.rs` - 群组管理
9. `admin.rs` - 管理后台
10. `version.rs` - 版本管理
11. `settings.rs` - 系统设置
12. `feedback.rs` - 反馈系统
13. `websocket/mod.rs` - WebSocket

### 技术栈

- **Web 框架**: Axum 0.7
- **异步运行时**: Tokio
- **数据库**: PostgreSQL 15 + SQLx
- **缓存**: Redis 7
- **序列化**: Protocol Buffers (prost)
- **认证**: JWT (jsonwebtoken)
- **密码加密**: bcrypt

---

**文档生成时间**: 2024-11-07
**API 版本**: v1
**后端版本**: 0.1.0
