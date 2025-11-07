# RedCode IM API 文档

## 概述

RedCode IM 是一个基于 Rust + Axum 构建的高性能即时通讯后端服务，提供实时消息传递、群组管理、文件共享和消息搜索等功能。

### 技术架构

- **后端**: Rust + Axum 0.7
- **数据库**: PostgreSQL 15
- **缓存**: Redis 7
- **实时通讯**: WebSocket
- **认证**: JWT Token
- **文件存储**: 多存储提供商支持（本地、S3等）

### 基础URL

```
生产环境: https://api.redcode-im.com
开发环境: http://localhost:8010
```

### API版本

当前API版本: `v1`

所有API端点均以 `/api/v1` 开头。

### 认证方式

除登录、注册接口外，所有API请求需要在Header中包含JWT Token：

```
Authorization: Bearer <token>
```

### 响应格式

所有API响应遵循统一格式：

```json
{
  "success": true|false,
  "code": 200,
  "message": "响应消息",
  "data": {} // 响应数据
}
```

### 状态码

- `200` - 成功
- `400` - 请求参数错误
- `401` - 未授权/Token无效
- `403` - 权限不足
- `404` - 资源不存在
- `422` - 业务逻辑验证失败
- `429` - 请求频率超限
- `500` - 服务器内部错误

## 目录

- [认证API](#认证api)
- [用户管理API](#用户管理api)
- [消息API](#消息api)
- [群组管理API](#群组管理api)
- [消息搜索API](#消息搜索api)
- [文件上传API](#文件上传api)
- [系统监控API](#系统监控api)
- [错误码](#错误码)

## 认证API

### 用户注册

创建新用户账户。

**接口地址**: `POST /api/v1/auth/register`

**请求参数**:

```json
{
  "username": "string",      // 用户名，3-20个字符
  "password": "string",      // 密码，至少6位
  "email": "string",         // 邮箱地址
  "nickname": "string",      // 昵称，可选
  "mobile": "string"         // 手机号，可选
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "注册成功",
  "data": {
    "user_id": "uuid",
    "username": "testuser",
    "email": "test@example.com"
  }
}
```

### 用户登录

用户登录并获取JWT Token。

**接口地址**: `POST /api/v1/auth/login`

**请求参数**:

```json
{
  "username": "string",      // 用户名或邮箱
  "password": "string"       // 密码
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "uuid",
      "username": "testuser",
      "nickname": "测试用户",
      "avatar_url": "https://cdn.example.com/avatar.jpg"
    }
  }
}
```

### 获取用户信息

获取当前登录用户的基本信息。

**接口地址**: `GET /api/v1/auth/profile`

**请求头**: `Authorization: Bearer <token>`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "id": "uuid",
    "username": "testuser",
    "email": "test@example.com",
    "nickname": "测试用户",
    "avatar_url": "https://cdn.example.com/avatar.jpg",
    "status": "active",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### 更新用户信息

更新当前用户的个人信息。

**接口地址**: `PUT /api/v1/auth/profile`

**请求头**: `Authorization: Bearer <token>`

**请求参数**:

```json
{
  "nickname": "string",      // 新昵称，可选
  "avatar_url": "string",    // 新头像URL，可选
  "mobile": "string"         // 新手机号，可选
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "更新成功",
  "data": {
    "id": "uuid",
    "username": "testuser",
    "nickname": "新昵称",
    "avatar_url": "https://cdn.example.com/new-avatar.jpg",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

### 修改密码

修改当前用户密码。

**接口地址**: `PUT /api/v1/auth/password`

**请求头**: `Authorization: Bearer <token>`

**请求参数**:

```json
{
  "old_password": "string",  // 旧密码
  "new_password": "string"   // 新密码，至少6位
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "密码修改成功"
}
```

### 用户登出

使当前JWT Token失效。

**接口地址**: `POST /api/v1/auth/logout`

**请求头**: `Authorization: Bearer <token>`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "登出成功"
}
```

## 用户管理API

### 获取用户列表

获取用户列表（需要管理员权限）。

**接口地址**: `GET /api/v1/admin/users`

**请求头**: `Authorization: Bearer <token>`

**查询参数**:
- `page` (optional): 页码，默认1
- `limit` (optional): 每页数量，默认20，最大100
- `status` (optional): 用户状态筛选 (active/inactive/banned)
- `search` (optional): 搜索关键词

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "users": [
      {
        "id": "uuid",
        "username": "testuser",
        "email": "test@example.com",
        "nickname": "测试用户",
        "status": "active",
        "created_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

### 获取用户详情

获取指定用户的详细信息。

**接口地址**: `GET /api/v1/admin/users/{user_id}`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "id": "uuid",
    "username": "testuser",
    "email": "test@example.com",
    "nickname": "测试用户",
    "status": "active",
    "last_login_at": "2024-01-01T00:00:00Z",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

## 消息API

### 获取消息列表

获取指定群组/聊天室的消息列表。

**接口地址**: `GET /api/v1/rooms/{room_id}/messages`

**请求头**: `Authorization: Bearer <token>`

**查询参数**:
- `before` (optional): 获取指定消息ID之前的消息
- `limit` (optional): 消息数量，默认50，最大100
- `include_deleted` (optional): 是否包含已删除消息，默认为false

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "room_id": "uuid",
      "sender_id": "uuid",
      "sender_name": "用户名",
      "sender_nickname": "昵称",
      "content": "消息内容",
      "message_type": "text",  // text/image/video/voice/file
      "created_at": "2024-01-01T00:00:00Z",
      "is_deleted": false,
      "quoted_message": {  // 引用消息，可选
        "id": "uuid",
        "content": "被引用的消息"
      },
      "parts": [  // 消息附件，可选
        {
          "position": 0,
          "part_type": "file",
          "attachment": {
            "key": "file_key",
            "name": "文件名.txt",
            "mime": "text/plain",
            "size": 1024,
            "url": "https://cdn.example.com/files/xxx"
          }
        }
      ]
    }
  ]
}
```

### 发送文本消息

在指定群组/聊天室发送文本消息。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages`

**请求参数**:

```json
{
  "content": "string",              // 消息内容，必填
  "quoted_message_id": "string"     // 引用的消息ID，可选
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "消息发送成功",
  "data": {
    "id": "uuid",
    "room_id": "uuid",
    "sender_id": "uuid",
    "content": "消息内容",
    "message_type": "text",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### 发送文件消息

在指定群组/聊天室发送包含附件的消息。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages`

**请求参数**:

```json
{
  "content": "string",              // 消息描述，可选
  "parts": [                        // 附件列表
    {
      "type": "file",               // 附件类型: file/image/video/voice
      "key": "string",              // 文件存储key
      "name": "string",             // 文件名
      "mime": "string",             // MIME类型
      "size": 1024                  // 文件大小（字节）
    }
  ]
}
```

### 标记消息为已读

标记指定消息为已读状态。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages/read`

**请求参数**:

```json
{
  "message_id": "string"  // 消息ID
}
```

### 标记多条消息为已读

标记从第一条到最后一条消息为已读（批量操作）。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages/read_until`

**请求参数**:

```json
{
  "message_id": "string"  // 最后一条消息ID
}
```

### 删除消息

删除指定消息（仅消息发送者或管理员可删除）。

**接口地址**: `DELETE /api/v1/rooms/{room_id}/messages/{message_id}`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "消息删除成功"
}
```

### 置顶消息

将指定消息置顶（仅群组管理员可操作）。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages/{message_id}/pin`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "消息置顶成功",
  "data": {
    "is_pinned": true,
    "pinned_at": "2024-01-01T00:00:00Z",
    "pinned_by": "uuid"
  }
}
```

### 取消置顶消息

取消指定消息的置顶状态。

**接口地址**: `DELETE /api/v1/rooms/{room_id}/messages/{message_id}/pin`

### 转发消息

将指定消息转发到其他群组/聊天室。

**接口地址**: `POST /api/v1/rooms/{room_id}/messages/forward`

**请求参数**:

```json
{
  "message_id": "string",            // 要转发的消息ID
  "target_room_ids": [               // 目标房间ID列表
    "uuid1",
    "uuid2"
  ]
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "消息转发成功",
  "data": [
    {
      "message_id": "uuid",
      "room_id": "uuid1",
      "room_name": "目标群组1",
      "sender_id": "uuid"
    }
  ]
}
```

### 获取未读消息数量

获取指定房间或所有房间的未读消息数量。

**接口地址**: `GET /api/v1/rooms/{room_id}/unread_count`

或获取所有房间的未读统计：

**接口地址**: `GET /api/v1/unread_counts`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "total": 10,
    "rooms": [
      {
        "room_id": "uuid",
        "room_name": "群组名称",
        "count": 5
      }
    ]
  }
}
```

## 群组管理API

### 创建群组

创建一个新的群组聊天室。

**接口地址**: `POST /api/v1/groups`

**请求参数**:

```json
{
  "name": "string",              // 群组名称，1-50个字符
  "description": "string",       // 群组描述，可选
  "avatar_url": "string",        // 群组头像URL，可选
  "max_members": 500,            // 最大成员数，默认500
  "member_ids": [                // 初始成员ID列表
    "uuid1",
    "uuid2"
  ]
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "message": "群组创建成功",
  "data": {
    "id": "uuid",
    "name": "群组名称",
    "room_id": "uuid",
    "owner_id": "uuid",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### 获取群组信息

获取指定群组的详细信息。

**接口地址**: `GET /api/v1/groups/{group_id}`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "id": "uuid",
    "name": "群组名称",
    "description": "群组描述",
    "avatar_url": "https://cdn.example.com/group.jpg",
    "room_type": "group",
    "owner_id": "uuid",
    "member_count": 10,
    "created_at": "2024-01-01T00:00:00Z",
    "settings": {
      "join_approval_required": true,
      "member_can_invite": true,
      "member_can_add_friends": false,
      "require_admin_to_add_friends": true,
      "max_members": 500
    }
  }
}
```

### 获取群组成员列表

获取指定群组的成员列表。

**接口地址**: `GET /api/v1/groups/{group_id}/members`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "username": "testuser",
      "nickname": "测试用户",
      "role": "owner",        // owner/admin/member
      "avatar_url": "https://cdn.example.com/avatar.jpg",
      "joined_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 添加群组成员

向群组添加新成员（仅管理员可操作）。

**接口地址**: `POST /api/v1/groups/{group_id}/members`

**请求参数**:

```json
{
  "user_ids": [               // 要添加的用户ID列表
    "uuid1",
    "uuid2"
  ],
  "message": "string"         // 邀请消息，可选
}
```

### 移除群组成员

从群组中移除成员（仅管理员可操作）。

**接口地址**: `DELETE /api/v1/groups/{group_id}/members/{user_id}`

### 更新群组成员角色

更新群组成员的角色（仅群主可操作）。

**接口地址**: `PATCH /api/v1/groups/{group_id}/members/{user_id}/role`

**请求参数**:

```json
{
  "role": "admin"  // 新角色: admin/member
}
```

### 退出群组

当前用户退出群组。

**接口地址**: `POST /api/v1/groups/{group_id}/leave`

### 解散群组

解散群组（仅群主可操作）。

**接口地址**: `DELETE /api/v1/groups/{group_id}`

### 获取群组设置

获取群组的管理设置。

**接口地址**: `GET /api/v1/groups/{group_id}/settings`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "join_approval_required": true,
    "member_can_invite": true,
    "member_can_add_friends": false,
    "require_admin_to_add_friends": true,
    "max_members": 500
  }
}
```

### 更新群组设置

更新群组的管理设置（仅管理员可操作）。

**接口地址**: `PATCH /api/v1/groups/{group_id}/settings`

**请求参数**:

```json
{
  "join_approval_required": true,        // 是否需要管理员审批
  "member_can_invite": true,             // 成员是否可邀请他人
  "member_can_add_friends": false,       // 成员是否可添加好友
  "require_admin_to_add_friends": true,  // 是否需要管理员审批添加好友
  "max_members": 500                     // 最大成员数
}
```

### 获取群组公告列表

获取群组的公告列表。

**接口地址**: `GET /api/v1/groups/{group_id}/announcements`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "title": "公告标题",
      "content": "公告内容",
      "publisher_id": "uuid",
      "publisher_name": "发布者",
      "is_pinned": true,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 发布群组公告

发布群组公告（仅管理员可操作）。

**接口地址**: `POST /api/v1/groups/{group_id}/announcements`

**请求参数**:

```json
{
  "title": "string",          // 公告标题
  "content": "string",        // 公告内容
  "is_pinned": true           // 是否置顶，可选
}
```

### 删除群组公告

删除群组公告（仅发布者或管理员可操作）。

**接口地址**: `DELETE /api/v1/groups/{group_id}/announcements/{announcement_id}`

### 申请加入群组

申请加入需要审批的群组。

**接口地址**: `POST /api/v1/groups/{group_id}/join-request`

**请求参数**:

```json
{
  "message": "string"  // 申请消息，可选
}
```

### 审批加入申请

审批用户的加群申请（仅管理员可操作）。

**接口地址**: `POST /api/v1/groups/{group_id}/join-requests/{request_id}/review`

**请求参数**:

```json
{
  "status": "approved",  // 审批结果: approved/rejected
  "review_message": "string"  // 审批回复，可选
}
```

### 获取加群申请列表

获取指定群组的加群申请列表（仅管理员可操作）。

**接口地址**: `GET /api/v1/groups/{group_id}/join-requests`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "username": "testuser",
      "message": "申请消息",
      "status": "pending",  // pending/approved/rejected
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 邀请用户加入群组

邀请用户加入群组（仅管理员可操作）。

**接口地址**: `POST /api/v1/groups/{group_id}/invite`

**请求参数**:

```json
{
  "user_ids": [               // 被邀请用户ID列表
    "uuid1",
    "uuid2"
  ],
  "message": "string"         // 邀请消息，可选
}
```

### 处理群组邀请

处理收到的群组邀请。

**接口地址**: `POST /api/v1/groups/invitations/{invitation_id}/respond`

**请求参数**:

```json
{
  "status": "accepted"  // 响应结果: accepted/declined
}
```

## 消息搜索API

### 搜索消息

在消息历史中搜索指定关键词。

**接口地址**: `GET /api/v1/search/messages`

**请求头**: `Authorization: Bearer <token>`

**查询参数**:
- `q` (required): 搜索关键词
- `room_id` (optional): 限制在指定房间
- `sender_id` (optional): 限制指定发送者
- `message_type` (optional): 消息类型筛选 (text/image/video/voice/file)
- `date_from` (optional): 开始时间戳
- `date_to` (optional): 结束时间戳
- `limit` (optional): 结果数量，默认50，最大100
- `offset` (optional): 偏移量

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "results": [
      {
        "id": "uuid",
        "room_id": "uuid",
        "room_name": "群组名称",
        "sender_id": "uuid",
        "sender_name": "发送者",
        "content": "匹配的消息内容",
        "message_type": "text",
        "timestamp": 1704067200000,
        "relevance_score": 0.95
      }
    ],
    "total_results": 1,
    "search_time_ms": 10,
    "query": "搜索词"
  }
}
```

### 获取搜索建议

获取搜索关键词的自动补全建议。

**接口地址**: `GET /api/v1/search/suggestions`

**查询参数**:
- `prefix` (required): 前缀
- `limit` (optional): 建议数量，默认10

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    "建议1",
    "建议2",
    "建议3"
  ]
}
```

### 获取热门关键词

获取当前热门搜索关键词。

**接口地址**: `GET /api/v1/search/trending`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": [
    {
      "keyword": "热门关键词1",
      "search_count": 100
    },
    {
      "keyword": "热门关键词2",
      "search_count": 80
    }
  ]
}
```

### 获取搜索统计

获取搜索功能的统计信息（需要管理员权限）。

**接口地址**: `GET /api/v1/search/stats`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "total_messages": 10000,
    "total_rooms": 100,
    "total_senders": 500,
    "db_size_bytes": 1024000,
    "db_size_mb": "1.00"
  }
}
```

## 文件上传API

### 获取上传配置

获取文件上传所需的配置信息。

**接口地址**: `GET /api/v1/upload/config`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "provider": "s3",  // 存储提供商: local/s3
    "max_file_size": 10485760,  // 最大文件大小（10MB）
    "allowed_types": [  // 允许的文件类型
      "image/jpeg",
      "image/png",
      "image/gif",
      "application/pdf"
    ]
  }
}
```

### 请求文件上传

请求上传文件并获取预签名URL。

**接口地址**: `POST /api/v1/upload/request`

**请求参数**:

```json
{
  "filename": "string",      // 文件名
  "mime": "string",          // MIME类型
  "size": 1048576,           // 文件大小（字节）
  "checksum": "string"       // 文件校验和（可选）
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "upload_url": "https://storage.example.com/upload/xxx",
    "file_key": "files/uuid/filename.jpg",
    "headers": {
      "Content-Type": "image/jpeg",
      "x-amz-checksum": "xxx"
    }
  }
}
```

### 确认文件上传

确认文件上传完成并获取访问URL。

**接口地址**: `POST /api/v1/upload/confirm`

**请求参数**:

```json
{
  "file_key": "string"  // 文件key（从请求上传接口获得）
}
```

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "file_key": "files/uuid/filename.jpg",
    "file_url": "https://cdn.example.com/files/uuid/filename.jpg",
    "expires_at": "2024-01-01T01:00:00Z"
  }
}
```

### 删除文件

删除已上传的文件（仅上传者或管理员可删除）。

**接口地址**: `DELETE /api/v1/upload/files/{file_key}`

## 系统监控API

### 获取系统监控信息

获取系统性能监控数据（需要管理员权限）。

**接口地址**: `GET /api/dashboard/monitor`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "cpu_usage": 45.5,           // CPU使用率 (%)
    "memory_usage": 1024,        // 内存使用量 (MB)
    "disk_usage": 5120,          // 磁盘使用量 (MB)
    "active_connections": 100,   // 活跃连接数
    "requests_per_second": 50,   // 每秒请求数
    "response_time_avg": 120     // 平均响应时间 (ms)
  }
}
```

### 获取数据统计

获取系统数据统计信息（需要管理员权限）。

**接口地址**: `GET /api/dashboard/statistics`

**响应示例**:

```json
{
  "success": true,
  "code": 200,
  "data": {
    "users": {
      "total": 1000,
      "active": 800,
      "new_today": 10
    },
    "messages": {
      "total": 100000,
      "today": 5000
    },
    "groups": {
      "total": 100,
      "active": 80
    },
    "storage": {
      "total_size": 10240000,   // 总存储大小（字节）
      "by_type": [
        {
          "type": "图片",
          "size": 5120000,
          "count": 1000
        }
      ]
    }
  }
}
```

## 错误码

### 通用错误码

| 错误码 | 说明 |
|--------|------|
| 40001 | 未授权 |
| 40002 | Token无效 |
| 40003 | Token已过期 |
| 40004 | 用户名或密码错误 |

| 错误码 | 说明 |
|--------|------|
| 40301 | 权限不足 |
| 40302 | 权限不够 |
| 40401 | 资源不存在 |
| 40901 | 资源已存在 |

| 错误码 | 说明 |
|--------|------|
| 42201 | 验证失败 |
| 42202 | 输入无效 |
| 42901 | 请求频率超限 |
| 42902 | 请求过于频繁 |

| 错误码 | 说明 |
|--------|------|
| 50001 | 业务逻辑错误 |
| 50101 | 数据库错误 |
| 50201 | 缓存错误 |
| 50301 | 内部错误 |
| 50302 | 服务不可用 |

### 业务错误码

| 错误码 | 说明 |
|--------|------|
| 60001 | 用户不存在 |
| 60002 | 用户已禁用 |
| 60003 | 密码错误 |
| 60004 | 邮箱已被使用 |
| 60005 | 用户名已被使用 |

| 错误码 | 说明 |
|--------|------|
| 60101 | 群组不存在 |
| 60102 | 群组已满 |
| 60103 | 已是群组成员 |
| 60104 | 不是群组成员 |
| 60105 | 群组名称已存在 |

| 错误码 | 说明 |
|--------|------|
| 60201 | 消息不存在 |
| 60202 | 消息已删除 |
| 60203 | 文件上传失败 |
| 60204 | 文件大小超限 |
| 60205 | 文件类型不支持 |

## 示例

### 发送图片消息的完整流程

1. 获取上传配置

```bash
GET /api/v1/upload/config
Authorization: Bearer <token>
```

2. 请求上传图片

```bash
POST /api/v1/upload/request
Authorization: Bearer <token>
Content-Type: application/json

{
  "filename": "photo.jpg",
  "mime": "image/jpeg",
  "size": 1024000
}
```

3. 上传文件到返回的URL

```bash
PUT <upload_url>
Content-Type: image/jpeg
<binary data>
```

4. 确认上传

```bash
POST /api/v1/upload/confirm
Authorization: Bearer <token>
Content-Type: application/json

{
  "file_key": "files/uuid/photo.jpg"
}
```

5. 发送带图片的消息

```bash
POST /api/v1/rooms/{room_id}/messages
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "看这张图片！",
  "parts": [
    {
      "type": "image",
      "key": "files/uuid/photo.jpg",
      "name": "photo.jpg",
      "mime": "image/jpeg",
      "size": 1024000
    }
  ]
}
```

## SDK

- **JavaScript/TypeScript**: [redcode-im-js-sdk](https://github.com/redcode-im/js-sdk)
- **Python**: [redcode-im-py-sdk](https://github.com/redcode-im/py-sdk)
- **Go**: [redcode-im-go-sdk](https://github.com/redcode-im/go-sdk)

## Changelog

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持基础消息功能
- 支持群组管理
- 支持文件上传
- 支持消息搜索

## 支持

如有问题或建议，请联系：
- 邮箱: support@redcode-im.com
- GitHub: https://github.com/redcode-im/redcode-im/issues
