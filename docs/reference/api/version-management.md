# 版本管理 API

本文记录 Admin 端应用版本管理接口以及客户端获取最新版本的公开端点。所有示例均基于已启用的 **S3 兼容对象存储** 直传能力。

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
  "filename": "redcode-im.dmg",
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
  "key": "releases/desktop/stable/20260413120000-demo.dmg",
  "signature": {
    "url": "http://rustfs:9000/demo-private-bucket/releases/desktop/stable/20260413120000-demo.dmg",
    "method": "PUT",
    "headers": {
      "Authorization": "AWS4-HMAC-SHA256 Credential=...",
      "Content-Type": "application/octet-stream"
    },
    "key": "releases/desktop/stable/20260413120000-demo.dmg"
  }
}
```

若提供 `hash_value + file_size` 且已存在相同文件，则可能返回 `signature = null`；此时 Admin 端无需重复上传，只需在创建 / 更新版本时引用该 `download_key`。

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
  "download_key": "releases/desktop/stable/20260413120000-demo.dmg",
  "download_url": null,
  "file_size": 194585600,
  "checksum": "sha256:...",
  "signature": null,
  "release_notes": "• 优化对象存储链路
• 修复后台管理问题",
  "mandatory": false,
  "is_active": true,
  "released_at": "2026-04-13T12:00:00Z"
}
```

### 1.3 更新版本

- **方法**: `PATCH`
- **路径**: `/api/admin/app-versions/{id}`

请求体仅需包含变更字段。

### 1.4 查看 & 分页

- **方法**: `GET`
- **路径**: `/api/admin/app-versions`

### 1.5 详情、停用、删除

| 操作 | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 查询单条 | `GET` | `/api/admin/app-versions/{id}` | 返回 `AppVersionInfo` |
| 停用版本 | `POST` | `/api/admin/app-versions/{id}/deactivate` | 标记 `is_active=false` |
| 删除版本 | `DELETE` | `/api/admin/app-versions/{id}` | 物理删除记录 |

> 停用与删除均不会触发对象存储文件清理，清理由后台异步任务负责。

## 2. 客户端公开接口

无需认证，可供官网、桌面端、移动端直接访问。

### 2.1 查询最新版本

- **方法**: `GET`
- **路径**: `/versions/latest`

### 2.2 生成下载链接

- **方法**: `GET`
- **路径**: `/versions/download`

成功响应：

```json
{
  "success": true,
  "message": "生成下载链接成功",
  "download_url": "http://rustfs:9000/demo-private-bucket/releases/...?..."
}
```

## 3. 使用建议

1. 建议为测试、预发布、正式分别维护渠道。
2. `build_number` 在同一平台 + 渠道内必须唯一。
3. 若提供 `checksum`，客户端应在下载后校验。
4. 当 `mandatory=true` 时，客户端可决定是否允许跳过升级。
5. Admin API 仅后台控制台调用，不应暴露给前台用户。
