# 版本管理 API

本文记录 Admin 端应用版本管理接口以及客户端获取最新版本的公开端点。所有示例均基于已启用的腾讯云 COS 直传能力。

## 1. Admin 模块

除特别说明外，以下接口均需携带 Bearer Token，默认角色要求为 `admin`。

### 1.1 获取直传签名

- **方法**: `POST`
- **路径**: `/api/admin/app-versions/upload/signature`

请求体：

```json
{
  "platform": "desktop",
  "channel": "stable",
  "filename": "bear-chat-setup.dmg",
  "file_size": 194585600,
  "hash_value": "d41d8cd98f00b204e9800998ecf8427e",
  "hash_alg": 1
}
```

响应：

```json
{
  "success": true,
  "message": "生成安装包直传签名成功",
  "key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg",
  "signature": {
    "url": "https://<bucket>.cos.<region>.myqcloud.com/relea...",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=...",
      "Content-Type": "application/octet-stream"
    },
    "key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg"
  }
}
```

> 如果提供了 `hash_value + file_size` 且后端已经记录过相同文件，则可能返回：
> ```json
> {
>   "success": true,
>   "message": "复用已上传的安装包，未生成新的直传签名",
>   "key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg",
>   "signature": null
> }
> ```
> 此时 Admin 端无需再次上传 COS，只需在创建/更新版本时引用该 `download_key` 即可。

上传完成后，应携带 `key` 调用新增/更新接口。

### 1.2 创建版本

- **方法**: `POST`
- **路径**: `/api/admin/app-versions`

请求体示例：

```json
{
  "platform": "desktop",
  "version": "1.0.3",
  "build_number": 103,
  "channel": "stable",
  "download_key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg",
  "download_url": null,
  "file_size": 194585600,
  "checksum": "sha256:...",
  "signature": null,
  "release_notes": "\u2022 新增桌面端版本管理\n\u2022 优化头像上传缓存",
  "mandatory": false,
  "is_active": true,
  "released_at": "2025-11-04T16:05:30Z"
}
```

成功返回 `AppVersionInfo`：

```json
{
  "id": "c6a8d3f2-74a0-4180-9fb8-4ad18f6f3a11",
  "platform": "desktop",
  "version": "1.0.3",
  "build_number": 103,
  "channel": "stable",
  "download_key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg",
  "download_url": null,
  "file_size": 194585600,
  "checksum": "sha256:...",
  "signature": null,
  "release_notes": "…",
  "mandatory": false,
  "is_active": true,
  "created_at": "2025-11-04T16:06:01Z",
  "updated_at": "2025-11-04T16:06:01Z",
  "released_at": "2025-11-04T16:05:30Z"
}
```

### 1.3 更新版本

- **方法**: `PATCH`
- **路径**: `/api/admin/app-versions/{id}`

请求体仅需包含变更字段，例如：

```json
{
  "release_notes": "修复 Windows 证书提示",
  "mandatory": true
}
```

### 1.4 查看 & 分页

- **方法**: `GET`
- **路径**: `/api/admin/app-versions`

查询参数：

| 参数 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `platform` | 是 | — | `desktop` / `frontend` 等 |
| `channel` | 否 | `stable` | 自定义渠道标识 |
| `limit` | 否 | 20 | 范围 1~100 |
| `offset` | 否 | 0 | 数据偏移 |

响应：

```json
{
  "total": 5,
  "items": [
    { "id": "...", "version": "1.0.3", ... }
  ]
}
```

### 1.5 详情、停用、删除

| 操作 | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 查询单条 | `GET` | `/api/admin/app-versions/{id}` | 返回 `AppVersionInfo` |
| 停用版本 | `POST` | `/api/admin/app-versions/{id}/deactivate` | 标记 `is_active=false` 并记录操作者 |
| 删除版本 | `DELETE` | `/api/admin/app-versions/{id}` | 物理删除记录 |

> 停用与删除均不会触发 COS 文件清理，后续可根据需要补充后台作业。

## 2. 客户端公开接口

无需认证，可供官网、桌面端、移动端等直接访问。

### 2.1 查询最新版本

- **方法**: `GET`
- **路径**: `/versions/latest`

参数：

| 参数 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `platform` | 是 | — | 例如 `desktop`、`frontend`
| `channel` | 否 | `stable` | 自定义渠道
| `current_version` | 否 | — | 客户端当前版本号，用于后端判断是否有更新 |

响应示例：

```json
{
  "has_update": true,
  "current_version": "1.0.2",
  "version": {
    "id": "c6a8d3f2-74a0-4180-9fb8-4ad18f6f3a11",
    "version": "1.0.3",
    "build_number": 103,
    "channel": "stable",
    "download_key": "releases/desktop/stable/20251104160502-3a9b4f21.dmg",
    "download_url": null,
    "file_size": 194585600,
    "mandatory": false,
    "release_notes": "..."
  }
}
```

若 `has_update=false`，`version` 字段为 `null`。

### 2.2 生成下载链接

- **方法**: `GET`
- **路径**: `/versions/download`

参数：

| 参数 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `id` | 是 | — | 版本 ID |
| `expires_in_seconds` | 否 | 600 | 下载链接有效期（60~86400 秒） |

成功响应：

```json
{
  "success": true,
  "message": "生成下载链接成功",
  "download_url": "https://<bucket>.cos.<region>.myqcloud.com/...&sign=..."
}
```

客户端应在有效期内完成下载，可视需要缓存到本地，再进行安装或后续比对。

## 3. 使用建议

1. **渠道规划**：建议为测试、预发布、正式渠道分别维护记录（如 `beta`、`stable`）。
2. **构建号**：`build_number` 在同一平台 + 渠道内必须唯一，可与 Flutter/桌面端内部版本号保持一致。
3. **文件校验**：若提供 `checksum` (如 SHA256)，客户端可在下载后比对以验证完整性。
4. **强制更新**：当 `mandatory=true` 时，客户端可据此决定是否允许跳过升级。
5. **权限控制**：Admin API 仅后台控制台调用，勿向前台用户暴露。
