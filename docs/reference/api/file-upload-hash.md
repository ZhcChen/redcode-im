# 文件直传与哈希去重说明

> 本文档说明所有通过对象存储（当前为 **Backblaze B2**）直传的文件，在后端的记录方式与哈希去重规则，适用于消息附件、用户头像、群头像、安装包、热更新补丁等场景。

## 1. 总体设计

### 1.1 目标

- 避免同一文件被重复上传到对象存储；
- 降低存储空间浪费、加快上传速度；
- 为统计、清理与审计提供统一数据来源。

### 1.2 统一文件记录表：`file_upload_records`

所有通过直传方式上传到对象存储的文件，都会记录到 `file_upload_records` 表中。关键字段：

- `storage_provider_id`：所属存储提供商（当前仅 Backblaze B2）
- `object_key`：对象键，例如：
  - `messages/{room_id}/...`
  - `avatars/{user_id}/...`
  - `room_avatars/{room_id}/...`
  - `releases/{platform}/{channel}/...`
- `hash_alg`：哈希算法，当前约定 `1=MD5`、`2=SHA256`
- `hash_value`：客户端计算并上报的文件哈希
- `file_size`：文件大小（字节）
- `content_type`：MIME 类型
- `status`：
  - `0`：上传中 / 待确认
  - `1`：上传完成，可复用
  - `2`：上传失败
  - `3`：已删除，不再允许复用

后端通过 `hash_alg + hash_value + file_size + status=1` 判断文件是否已存在，以便在生成直传签名时直接复用已有 `object_key`。

## 2. 前端统一约定

### 2.1 必须由前端计算哈希

直传模式下，文件二进制内容不会经过 api，因此哈希值必须由前端在本地计算。当前推荐统一使用 MD5（`hash_alg = 1`）。

### 2.2 直传签名请求新增字段（通用）

以下字段均为可选，用于兼容旧客户端：

- `file_size`
- `hash_value`
- `hash_alg`

当前已支持的接口包括：

- 消息附件直传签名：`POST /rooms/{room_id}/messages/attachments/signature`
- 用户头像直传签名：`POST /users/me/avatar/direct-upload`
- 群头像直传签名：`POST /rooms/{room_id}/avatar/direct-upload`
- 安装包直传签名：`POST /api/admin/app-versions/upload/signature`
- Admin 对象存储测试签名：`POST /api/admin/storage-providers/test/upload/signature`

### 2.3 响应行为：是否需要实际上传对象存储

统一响应结构：

```json
{
  "success": true,
  "message": "xxx",
  "key": "对象键",
  "signature": {
    "url": "https://s3.us-east-005.backblazeb2.com/demo-private-bucket/messages/...",
    "method": "PUT",
    "headers": {
      "Authorization": "AWS4-HMAC-SHA256 Credential=...",
      "Content-Type": "image/png"
    },
    "key": "与上方 key 保持一致"
  }
}
```

- 若命中哈希去重：`signature = null`，前端直接复用 `key`；
- 若未命中：前端使用 `signature` 上传，再调用对应 commit / 业务接口。

## 3. 各业务场景说明

### 3.1 消息附件

- `POST /rooms/{room_id}/messages/attachments/signature`
- `POST /rooms/{room_id}/messages/attachments/commit`

commit 时后端会对对象执行 `HEAD` 检查，确认对象存在，并尽量校验 size / hash。

### 3.2 用户头像

- `POST /users/me/avatar/direct-upload`
- `POST /users/me/avatar/commit`

仅在 `avatars/{user_id}/` 前缀下尝试复用。

### 3.3 群头像

- `POST /rooms/{room_id}/avatar/direct-upload`
- `POST /rooms/{room_id}/avatar/commit`

仅在 `room_avatars/{room_id}/` 前缀下尝试复用。

### 3.4 安装包与热更新补丁

- `POST /api/admin/app-versions/upload/signature`
- `POST /api/admin/app-versions`
- `POST /api/admin/hot-updates`

成功创建业务记录后，会调用 `mark_completed_by_key` 将对应文件标记为完成。

## 4. 兼容性与注意事项

1. 所有哈希字段都是可选的，旧客户端仍可正常使用直传能力。
2. 新客户端应尽量计算并上传哈希，以获得去重收益。
3. 当 `signature = null` 时，前端必须跳过实际上传流程。
4. 文件清理任务会基于 `file_upload_records.status = 3` 与引用关系回收孤儿对象。
