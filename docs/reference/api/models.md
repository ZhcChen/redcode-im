# 数据模型接口

## INFO — 字段说明 / 模型定义

本项目主要数据模型与枚举说明，便于前后端对齐。

- 需要认证：否
- 标识：models-overview

---

## 枚举类型

### UserStatus - 用户状态
```json
["active", "inactive", "banned"]
```
- `active`: 正常状态
- `inactive`: 未激活
- `banned`: 已封禁

### RoomType - 房间类型
```json
["private", "group", "public", "favorite"]
```
- `private`: 私聊
- `group`: 群聊
- `public`: 公开聊天室
- `favorite`: 收藏夹

### MessageType - 消息类型
```json
["text", "image", "file", "system", "video", "audio", "mixed"]
```
- `text`: 文本消息
- `image`: 图片消息
- `file`: 文件消息
- `system`: 系统消息
- `video`: 视频消息
- `audio`: 音频消息
- `mixed`: 混合消息（多种类型组合）

### MessagePartType - 消息分片类型
```json
["text", "image", "video", "audio", "file"]
```

### MessageDeliveryStatus - 消息投递状态
```json
["sent", "read"]
```
- `sent`: 已发送
- `read`: 已读

### MemberRole - 成员角色
```json
["owner", "admin", "member"]
```
- `owner`: 房主/群主
- `admin`: 管理员
- `member`: 普通成员

### FriendRequestStatus - 好友请求状态
```json
["pending", "accepted", "declined"]
```
- `pending`: 待处理
- `accepted`: 已接受
- `declined`: 已拒绝

### FriendRequestAction - 好友请求响应动作
```json
["accept", "decline"]
```

---

## 用户相关模型

### UserInfo - 用户公开信息
```typescript
interface UserInfo {
  id: string;                    // 用户ID (UUID)
  username: string;              // 用户名
  email: string;                 // 邮箱地址
  nickname: string | null;       // 昵称
  avatar_url: string | null;     // 头像URL（临时签名链接）
  avatar_object_key: string | null; // 头像存储key
  signature: string | null;      // 个性签名（API 2.0）
  status: UserStatus;            // 用户状态
}
```

### CreateUserRequest - 创建用户请求
```typescript
interface CreateUserRequest {
  username: string;              // 登录账号，当前主流程必填，至少3个字符
  email?: string;                // 可选邮箱资料；未传时后端生成内部占位邮箱
  password: string;              // 密码，至少6个字符
  nickname?: string;             // 昵称（可选）
}
```

### LoginRequest - 登录请求
```typescript
interface LoginRequest {
  username: string;              // 登录账号；邮箱登录兼容开关开启时也可传 email
  email?: string;                // 默认关闭，仅兼容旧邮箱登录客户端
  password: string;              // 密码
  device_id?: string;            // 客户端稳定设备标识（API 2.0，可选）
  device_name?: string;          // 设备名称（API 2.0，可选）
  platform?: string;             // 平台标识（API 2.0，可选）
}
```

### LoginResponse - 登录响应
```typescript
interface LoginResponse {
  token: string;                 // JWT访问令牌
  user: UserInfo;                // 用户信息
  refresh_token?: string;        // 刷新令牌（可选）
  deviceId?: string;             // 本次登录设备ID（API 2.0，可选）
}
```

### UpdateUserRequest - 更新用户信息请求
```typescript
interface UpdateUserRequest {
  nickname?: string;             // 新昵称
  avatar_url?: string;           // 新头像URL
  avatar_object_key?: string;    // 新头像存储key
  signature?: string;            // 个性签名（API 2.0，可选；空串清空）
  friend_remark?: string;        // 好友备注
}
```

### ChangePasswordRequest - 修改密码请求
```typescript
interface ChangePasswordRequest {
  old_password: string;          // 原密码
  new_password: string;          // 新密码
}
```

---

## 房间相关模型

### RoomInfo - 房间信息
```typescript
interface RoomInfo {
  id: string;                    // 房间ID (UUID)
  name: string;                  // 房间名称
  description: string | null;    // 房间描述
  avatar_url: string | null;     // 房间头像URL
  room_type: RoomType;           // 房间类型
  owner_id: string;              // 房主ID
  created_at: string;            // 创建时间 (ISO 8601)
}
```

### CreateRoomRequest - 创建房间请求
```typescript
interface CreateRoomRequest {
  name: string;                  // 房间名称
  description?: string;          // 房间描述
  room_type?: RoomType;          // 房间类型，默认 group
}
```

### RoomMemberInfo - 房间成员信息
```typescript
interface RoomMemberInfo {
  user_id: string;               // 用户ID
  role: MemberRole;              // 成员角色
  joined_at: string;             // 加入时间 (ISO 8601)
}
```

---

## 消息相关模型

### MessageInfo - 消息信息
```typescript
interface MessageInfo {
  id: string;                    // 消息ID (UUID)
  room_id: string;               // 房间ID
  sender_id: string;             // 发送者ID
  sender_username: string;       // 发送者用户名
  sender_nickname: string | null; // 发送者昵称
  sender_avatar_url: string | null; // 发送者头像URL
  content: string;               // 消息内容（兼容旧格式）
  message_type: MessageType;     // 消息类型
  status?: MessageDeliveryStatus; // 投递状态
  created_at: string;            // 创建时间 (ISO 8601)
  quoted_message?: QuotedMessageInfo; // 引用的消息
  forward_message?: ForwardMessageInfo; // 转发的消息
  is_deleted: boolean;           // 是否已删除
  deleted_at?: string;           // 删除时间
  is_edited: boolean;            // 是否已编辑
  edited_at?: string;            // 编辑时间
  is_pinned: boolean;            // 是否已置顶
  pinned_at?: string;            // 置顶时间
  pinned_by?: string;            // 置顶操作者ID
  parts: MessagePartInfo[];      // 消息分片列表
}
```

### MessagePartInfo - 消息分片信息
```typescript
interface MessagePartInfo {
  position: number;              // 分片位置索引
  part_type: MessagePartType;    // 分片类型
  text?: string;                 // 文本内容（文本类型时）
  attachment?: MessageAttachmentInfo; // 附件信息（媒体类型时）
}
```

### MessageAttachmentInfo - 消息附件信息
```typescript
interface MessageAttachmentInfo {
  key: string;                   // 存储key
  name?: string;                 // 文件名
  mime?: string;                 // MIME类型
  size?: number;                 // 文件大小（字节）
  width?: number;                // 宽度（图片/视频）
  height?: number;               // 高度（图片/视频）
  duration_ms?: number;          // 时长（毫秒，音视频）
  thumbnail_key?: string;        // 缩略图存储key
}
```

### SendMessageRequest - 发送消息请求
```typescript
interface SendMessageRequest {
  content?: string;              // 消息内容（兼容旧格式）
  parts: MessagePartPayload[];   // 消息分片列表
  quoted_message_id?: string;    // 引用的消息ID
}

// 消息分片负载（Tagged Union）
type MessagePartPayload =
  | { type: "text"; text: string }
  | { type: "image"; key: string; name?: string; mime?: string; size?: number; width?: number; height?: number; thumbnail_key?: string }
  | { type: "video"; key: string; name?: string; mime?: string; size?: number; width?: number; height?: number; duration_ms?: number; thumbnail_key?: string }
  | { type: "audio"; key: string; name?: string; mime?: string; size?: number; duration_ms?: number }
  | { type: "file"; key: string; name?: string; mime?: string; size?: number };
```

### QuotedMessageInfo - 引用消息信息
```typescript
interface QuotedMessageInfo {
  id: string;                    // 原消息ID
  room_id: string;               // 原房间ID
  sender_id: string;             // 原发送者ID
  sender_username: string;       // 原发送者用户名
  sender_nickname: string | null; // 原发送者昵称
  sender_avatar_url: string | null; // 原发送者头像
  content: string | null;        // 原消息内容
  message_type: MessageType;     // 原消息类型
  created_at: string | null;     // 原消息创建时间
  is_deleted: boolean;           // 是否已删除
  parts: MessagePartInfo[];      // 原消息分片
}
```

### ForwardMessageInfo - 转发消息信息
```typescript
interface ForwardMessageInfo {
  message_id: string;            // 原消息ID
  room_id: string;               // 原房间ID
  sender_id: string;             // 原发送者ID
  sender_username: string | null; // 原发送者用户名
  sender_nickname: string | null; // 原发送者昵称
}
```

### ListMessagesQuery - 消息列表查询参数
```typescript
interface ListMessagesQuery {
  limit?: number;                // 返回数量限制
  before_id?: string;            // 获取此消息ID之前的消息
  since_id?: string;             // 获取此消息ID之后的消息
}
```

---

## 消息已读相关模型

### MarkMessageReadRequest - 标记已读请求
```typescript
interface MarkMessageReadRequest {
  message_id: string;            // 消息ID
}
```

### MessageReadInfo - 消息已读信息
```typescript
interface MessageReadInfo {
  user_id: string;               // 用户ID
  username: string;              // 用户名
  nickname: string | null;       // 昵称
  avatar_url: string | null;     // 头像URL
  read_at: string;               // 阅读时间 (ISO 8601)
}
```

### UnreadCount - 未读消息统计
```typescript
interface UnreadCount {
  room_id: string;               // 房间ID
  unread_count: number;          // 未读数量
  last_read_message_id: string | null; // 最后已读消息ID
  last_read_at: string | null;   // 最后阅读时间
}
```

---

## 会话相关模型

### ChatMessagePreview - 最后一条消息摘要
```typescript
interface ChatMessagePreview {
  id: string;                    // 消息ID
  content: string;               // 消息内容
  message_type: MessageType;     // 消息类型
  created_at: string;            // 创建时间
  sender_id: string;             // 发送者ID
  sender_username: string;       // 发送者用户名
  sender_nickname: string | null; // 发送者昵称
}
```

### ChatSummary - 会话概要信息
```typescript
interface ChatSummary {
  room_id: string;               // 房间ID
  name: string;                  // 会话名称
  room_type: RoomType;           // 房间类型
  avatar_url: string | null;     // 头像URL
  room_avatar_object_key?: string; // 房间头像存储key
  description: string | null;    // 描述
  unread_count: number;          // 未读数量
  last_read_message_id: string | null; // 最后已读消息ID
  last_read_at: string | null;   // 最后阅读时间
  notification_settings: number; // 通知设置
  is_muted: boolean;             // 是否免打扰
  is_pinned: boolean;            // 是否置顶
  last_message: ChatMessagePreview | null; // 最后一条消息
  // 私聊特有字段
  friend_user_id?: string;       // 好友用户ID
  friend_nickname?: string;      // 好友昵称
  friend_username?: string;      // 好友用户名
  friend_remark?: string;        // 好友备注
  friend_avatar_object_key?: string; // 好友头像存储key
}
```

---

## 好友相关模型

### CreateFriendRequest - 创建好友请求
```typescript
interface CreateFriendRequest {
  target_user_id: string;        // 目标用户ID
  message?: string;              // 请求留言
}
```

### RespondFriendRequest - 响应好友请求
```typescript
interface RespondFriendRequest {
  action: FriendRequestAction;   // 响应动作 (accept/decline)
}
```

### FriendRequestInfo - 好友请求信息
```typescript
interface FriendRequestInfo {
  id: string;                    // 请求ID
  requester: UserInfo;           // 请求发起者
  addressee: UserInfo;           // 请求接收者
  status: FriendRequestStatus;   // 请求状态
  message: string | null;        // 请求留言
  created_at: string;            // 创建时间
  responded_at: string | null;   // 响应时间
  is_incoming: boolean;          // 是否为收到的请求
}
```

### FriendInfo - 好友信息
```typescript
interface FriendInfo {
  id: string;                    // 好友关系ID
  user: UserInfo;                // 好友用户信息
  created_at: string;            // 成为好友时间
  friend_remark: string | null;  // 好友备注
}
```

### EnsureChatResponse - 确保私聊响应
```typescript
interface EnsureChatResponse {
  room_id: string;               // 房间ID
  room_name: string;             // 房间名称
  room_type: RoomType;           // 房间类型
  friend_id: string;             // 好友ID
  friend_name: string;           // 好友名称
  friend_avatar: string | null;  // 好友头像
}
```

---

## 版本管理模型

### AppVersionInfo - 应用版本信息
```typescript
interface AppVersionInfo {
  id: string;                    // 版本ID
  platform: string;              // 平台 (android/ios/windows/macos/linux)
  version: string;               // 版本号 (如 1.0.0)
  build_number: number;          // 构建号
  channel: string;               // 渠道 (stable/beta/alpha)
  download_key: string;          // 下载存储key
  download_url: string | null;   // 下载URL
  app_store_url: string | null;  // 应用商店URL
  file_size: number | null;      // 文件大小
  checksum: string | null;       // 校验和
  signature: string | null;      // 签名
  release_notes: string | null;  // 更新说明
  mandatory: boolean;            // 是否强制更新
  is_active: boolean;            // 是否启用
  created_at: string;            // 创建时间
  updated_at: string;            // 更新时间
  released_at: string | null;    // 发布时间
}
```

### LatestVersionResponse - 最新版本响应
```typescript
interface LatestVersionResponse {
  has_update: boolean;           // 是否有更新
  current_version: string | null; // 当前版本
  version: AppVersionInfo | null; // 最新版本信息
}
```

### HotUpdateInfo - 热更新信息
```typescript
interface HotUpdateInfo {
  id: string;                    // 热更新ID
  platform: string;              // 平台
  app_version_id: string;        // 关联的应用版本ID
  patch_version: string;         // 补丁版本号
  channel: string;               // 渠道
  download_key: string;          // 下载存储key
  download_url: string | null;   // 下载URL
  file_size: number | null;      // 文件大小
  checksum: string | null;       // 校验和
  signature: string | null;      // 签名
  rollout_percentage: number;    // 灰度发布比例 (0-100)
  mandatory: boolean;            // 是否强制更新
  description: string | null;    // 更新说明
  is_active: boolean;            // 是否启用
  released_at: string | null;    // 发布时间
  created_at: string;            // 创建时间
  updated_at: string;            // 更新时间
}
```

### HotUpdateResponse - 热更新检查响应
```typescript
interface HotUpdateResponse {
  has_update: boolean;           // 是否有更新
  current_patch_version: string | null; // 当前补丁版本
  patch: HotUpdateInfo | null;   // 热更新信息
}
```

### HotUpdateEventReport - 热更新事件上报
```typescript
interface HotUpdateEventReport {
  platform: string;              // 平台
  channel?: string;              // 渠道
  base_version: string;          // 基础版本
  patch_version: string;         // 补丁版本
  event_type: string;            // 事件类型 (success/failed/rollback)
  client_id?: string;            // 客户端ID
  message?: string;              // 消息
  client_type?: string;          // 客户端类型
  os_version?: string;           // 操作系统版本
  os_arch?: string;              // 操作系统架构
  app_arch?: string;             // 应用架构
  build_number?: number;         // 构建号
  trigger_source?: string;       // 触发来源
  network_type?: string;         // 网络类型
  device_info?: string;          // 设备信息
}
```

---

## 文档配置模型

### DocumentContent - 文档内容
```typescript
interface DocumentContent {
  key: string;                   // 文档标识
  title: string;                 // 文档标题
  content: string;               // 文档内容 (Markdown)
  updated_at: string;            // 更新时间
  updated_by: string | null;     // 更新者ID
}
```

### UpdateDocumentRequest - 更新文档请求
```typescript
interface UpdateDocumentRequest {
  title?: string;                // 新标题
  content: string;               // 新内容
}
```

---

## JWT Claims

### Claims - JWT 令牌声明
```typescript
interface Claims {
  sub: string;                   // 用户ID
  username: string;              // 用户名
  is_admin: boolean;             // 是否为管理员Token
  exp: number;                   // 过期时间戳
  iat: number;                   // 签发时间戳
}
```

---

## 通用响应模型

### SuccessResponse - 成功响应
```typescript
interface SuccessResponse {
  success: boolean;              // 是否成功
  message: string;               // 响应消息
}
```

### ErrorResponse - 错误响应
```typescript
interface ErrorResponse {
  code: number;                  // 错误码
  message: string;               // 错误信息
  details?: string;              // 详细信息
}
```

### PaginatedResponse - 分页响应
```typescript
interface PaginatedResponse<T> {
  total: number;                 // 总数量
  items: T[];                    // 数据列表
}
```

---

## API 2.0 新增模型

### BlockedUserInfo - 黑名单列表项
```typescript
interface BlockedUserInfo {
  userId: string;                // 被拉黑用户ID
  username: string;              // 用户名
  nickname: string | null;       // 昵称
  avatarUrl: string | null;      // 头像URL
  signature: string | null;      // 个性签名
  blockedAt: string;             // 拉黑时间（RFC3339）
}
```

### GroupAnnouncement - 群公告
```typescript
interface GroupAnnouncement {
  roomId: string;                // 群房间ID
  content: string;               // 公告内容
  createdBy: string;             // 创建者用户ID
  updatedBy: string;             // 最后更新者用户ID
  createdAt: string;             // 创建时间（RFC3339）
  updatedAt: string;             // 更新时间（RFC3339）
}
```

### FavoriteMessageInfo - 消息收藏项
```typescript
interface FavoriteMessageInfo {
  messageId: string;             // 消息ID
  roomId: string;                // 房间ID
  senderId: string;              // 发送者用户ID
  content: string;               // 消息内容
  messageType: string;           // 消息类型
  messageCreatedAt: string;      // 消息创建时间（RFC3339）
  favoritedAt: string;           // 收藏时间（RFC3339）
}
```

### UserDeviceInfo - 登录设备
```typescript
interface UserDeviceInfo {
  deviceId: string;              // 设备ID
  deviceName: string;            // 设备名称
  platform: string;              // 平台标识
  lastSeenAt: string;            // 最后活跃时间（RFC3339）
  createdAt: string;             // 登记时间（RFC3339）
  revokedAt: string | null;      // 撤销时间；null 表示未撤销
  isCurrent: boolean;            // 是否为当前请求设备
}
```

### QrSessionResponse - 扫码会话
```typescript
interface QrSessionResponse {
  qrId: string;                  // 二维码会话ID（UUID）
  expiresAt: string;             // 过期时间（RFC3339，默认 5 分钟）
}

interface QrSessionStatusResponse {
  status: "pending" | "confirmed" | "cancelled" | "expired";
  loginCode?: string;            // 仅 confirmed 时返回，一次性
}
```

---

**文档最后更新**: 2026-08-04
