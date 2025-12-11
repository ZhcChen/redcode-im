# 文件直传与哈希去重说明

> 本文档说明所有通过对象存储（当前为腾讯云 COS）直传的文件，在后端的记录方式与哈希去重规则，适用于：消息附件、用户头像、群头像、应用安装包、热更新补丁等场景。

## 1. 总体设计

### 1.1 目标

- 避免同一文件被重复上传到 COS：
  - 同一用户多次发送同一图片/视频；
  - 不同用户在不同终端上传同一个文件；
- 降低存储空间浪费、加快上传速度；
- 为后续存储统计、清理任务提供统一的数据来源。

### 1.2 统一文件记录表：`file_upload_records`

所有通过直传方式上传到 COS 的文件，都会记录到 `file_upload_records` 表中。字段主要包括：

- `storage_provider_id`：文件所属的存储提供商（当前为腾讯云 COS，来自 `storage_providers` 表）
- `object_key`：COS 中的对象键，例如：
  - 消息附件：`messages/{room_id}/...`
  - 用户头像：`avatars/{user_id}/...`
  - 群头像：`room_avatars/{room_id}/...`
  - 安装包：`releases/{platform}/{channel}/...`
- `hash_alg`：哈希算法，当前约定：
  - `1`：MD5
  - `2`：SHA256
- `hash_value`：文件哈希值（由客户端计算并上报，十六进制字符串）
- `file_size`：文件大小（字节）
- `content_type`：MIME 类型，例如 `image/png`、`video/mp4`
- `status`：上传状态
  - `0`：上传中/待确认（已生成直传签名，但尚未确认 COS 上传成功）
  - `1`：上传完成（可被复用）
  - `2`：上传失败
  - `3`：已删除（COS 对象已被清理，不再允许复用）

后端会通过 `hash_alg + hash_value + file_size + status=1` 来判断文件是否已存在，从而在生成直传签名时直接复用已有的 `object_key`。

## 2. 前端统一约定

### 2.1 必须由前端计算哈希

直传模式下，文件二进制内容不会经过 backend，因此哈希值必须由前端在本地计算。建议约定：

- 桌面端 / 管理后台：使用 MD5（`hash_alg = 1`），以十六进制字符串形式传给后端；
- 移动端（Flutter）可保持一致，或按需要扩展 SHA256（`hash_alg = 2`）。

### 2.2 直传签名请求新增字段（通用）

所有直传签名接口，在请求体上新增以下字段（均为可选，用于兼容旧客户端）：

- `file_size`：`number`，文件大小（字节）；
- `hash_value`：`string`，文件哈希值（十六进制字符串）；
- `hash_alg`：`number`，哈希算法，当前约定：
  - `1`：MD5（默认值）
  - `2`：SHA256。

当前已支持的接口包括：

- 消息附件直传签名：`POST /rooms/{room_id}/messages/attachments/signature`
- 用户头像直传签名：`POST /users/me/avatar/direct-upload`
- 群头像直传签名：`POST /rooms/{room_id}/avatar/direct-upload`
- 安装包直传签名：`POST /api/admin/app-versions/upload/signature`
- Admin COS 测试签名：`POST /api/admin/storage-providers/test/upload/signature`

### 2.3 响应行为：是否需要实际上传 COS

所有直传签名接口的响应结构统一为：

```json
{
  "success": true,
  "message": "xxx",
  "key": "对象在 COS 中的路径",
  "signature": {
    "url": "https://<bucket>.cos.<region>.myqcloud.com/...",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=...",
      "Content-Type": "image/png"
    },
    "key": "与上方 key 保持一致"
  }
}
```

- 如果 **发现可复用的文件**（即存在相同 `hash_alg + hash_value + file_size` 且 `status = 1` 的记录）：
  - `success = true`
  - `key` = 已存在文件的 `object_key`
  - `signature = null`（不再返回直传参数）
  - 前端只需要使用该 `key` 绑定业务数据，无需再上传 COS。

- 如果 **未找到可复用文件**：
  - `success = true`
  - `key` = 新生成的 `object_key`
  - `signature` = 非空，包含直传所需的 URL、方法和请求头
  - 前端需要使用该 `signature` 将文件上传到 COS，然后再调用对应的 commit/业务接口。

前端判断逻辑：

- `signature != null`：需要执行实际上传；
- `signature == null`：命中哈希去重，直接复用，跳过上传。

## 3. 各业务场景说明

### 3.1 消息附件（文件/图片/视频）

#### 3.1.1 直传签名

- 接口：`POST /rooms/{room_id}/messages/attachments/signature`
- 请求体扩展：详见 `backend/docs/api/messages.md` 中的“消息附件直传”一节。
- 行为：
  1. 校验房间与权限；
  2. 验证 `content_type` 和 `file_size` 是否符合限制；
  3. 如提供 `hash_value + file_size`：
     - 调用 `file_upload_records` 查找已完成记录；
     - 命中则返回 `key + signature = null`；
  4. 未命中则生成新 `object_key`，写入一条 `status=0` 的文件记录，并返回直传签名。

#### 3.1.2 上传完成通知（commit）

- 接口：`POST /rooms/{room_id}/messages/attachments/commit`
- 请求体：

```json
{
  "key": "messages/{room_id}/...",
  "hash_value": "可选",
  "hash_alg": 1,
  "file_size": 123456
}
```

- 行为：
  1. 校验用户在房间内；
  2. 校验 `key` 非空且前缀为 `messages/{room_id}/`；
  3. 调用 COS `HEAD` 检查对象存在；
  4. 调用 `mark_completed_by_key` 将 `file_upload_records` 中对应记录置为 `status=1`。

> 注意：如果直传签名时客户端未提供 hash，则该 key 可能在 `file_upload_records` 中不存在记录，此时 commit 只起到“业务层确认上传成功”的作用，不参与哈希去重。

### 3.2 用户头像

详见 `backend/docs/api/user-profile.md`：

- `POST /users/me/avatar/direct-upload`：
  - 请求体新增 `file_size`、`hash_value`、`hash_alg`；
  - 只在当前用户的 `avatars/{user_id}/` 前缀下尝试复用；
- `POST /users/me/avatar/commit`：
  - 在成功更新用户资料后，会调用 `mark_completed_by_key` 将对应记录置为完成。

### 3.3 群头像

- `POST /rooms/{room_id}/avatar/direct-upload`：
  - 请求体新增 `file_size`、`hash_value`、`hash_alg`；
  - 仅在 `room_avatars/{room_id}/` 前缀下尝试复用；
- `POST /rooms/{room_id}/avatar/commit`：
  - 在成功更新群头像后，会调用 `mark_completed_by_key` 标记完成。

### 3.4 安装包与热更新补丁

详见 `backend/docs/api/version-management.md`：

- `POST /api/admin/app-versions/upload/signature`：
  - 请求体新增 `file_size`、`hash_value`、`hash_alg`；
  - 生成或复用 `releases/{platform}/{channel}/...` 下的安装包 key。
- `POST /api/admin/app-versions`：
  - 创建版本成功后，会使用 `download_key` 调用 `mark_completed_by_key`。
- `POST /api/admin/hot-updates`：
  - 创建热更新补丁成功后，会使用 `download_key` 调用 `mark_completed_by_key`。

## 4. 兼容性与注意事项

1. 所有新增的哈希相关字段均为可选，旧版本客户端仍然可以正常使用直传能力，只是不会参与哈希去重。
2. 建议所有新版本客户端：
   - 必须在本地计算文件哈希并传入 `hash_value` 和 `file_size`；
   - 统一使用 MD5（`hash_alg = 1`），后续如需扩展 SHA256，可通过 `hash_alg = 2` 实现。
3. 复用已有文件时，接口会返回 `signature = null`，前端必须根据这一点跳过 COS 上传流程，仅使用返回的 `key` 绑定业务数据。
4. 后续如需实现 COS 级的文件清理任务，可根据 `file_upload_records.status = 3` 标记已删除的对象，避免继续被复用。

