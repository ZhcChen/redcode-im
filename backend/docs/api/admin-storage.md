# 存储测试接口（Admin）

> 这些接口位于「后台管理」域下，默认只对已登录且拥有管理权限的用户开放。用于验证腾讯云 COS 配置、直传签名以及跨域策略等能力，方便日常调试。

## POST /api/admin/storage-providers/test/upload/signature — 生成直传签名

- 认证：需要
- 标识：storage.test.upload-signature

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID，不填时使用默认提供商 |
| key | string | 是 | 对象在 COS 中的存储路径，例如 `test/hello.png` |
| content_type | string | 否 | 传入浏览器实际上传时使用的 `Content-Type` |

示例：
```json
{
  "provider_id": "f5f7b3c8-0ce3-4c3d-a4bf-5f67f8f0d4c2",
  "key": "test/20251104-hello.png",
  "content_type": "image/png"
}
```

### 响应
#### HTTP 200
```json
{
  "success": true,
  "message": "生成直传签名成功",
  "signature": {
    "url": "https://bucket-123.cos.ap-guangzhou.myqcloud.com/test/20251104-hello.png",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=sha1&...",
      "Content-Type": "image/png"
    },
    "key": "test/20251104-hello.png"
  }
}
```

失败时 `success=false`，`message` 包含错误说明。

上传前端需使用返回的 `url`、`method`、`headers` 调用 COS 对象存储，body 即文件内容。

---

## POST /api/admin/storage-providers/test/download-url — 生成带过期时间的私有下载链接

- 认证：需要
- 标识：storage.test.download-url

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID，不填为默认提供商 |
| key | string | 是 | 对象路径，与上传时的 key 一致 |
| expires_in_seconds | number | 否 | 链接有效时间（秒），默认 3600，最小 60，最大 86400 |

示例：
```json
{
  "key": "test/20251104-hello.png",
  "expires_in_seconds": 600
}
```

### 响应
#### HTTP 200
```json
{
  "success": true,
  "message": "生成下载链接成功",
  "url": "https://bucket-123.cos.ap-guangzhou.myqcloud.com/test/20251104-hello.png?q-sign-algorithm=sha1&..."
}
```

前端可直接使用 `url` 访问对象，超过有效期后链接失效。

---

## POST /api/admin/storage-providers/test/cors/list — 查询跨域规则

- 认证：需要
- 标识：storage.test.cors.get

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |

### 响应
```json
{
  "success": true,
  "message": "获取跨域规则成功",
  "rules": [
    {
      "allowed_origins": ["http://localhost:8011"],
      "allowed_methods": ["PUT", "GET"],
      "allowed_headers": ["*"],
      "expose_headers": [],
      "max_age_seconds": 600
    }
  ]
}
```

---

## POST /api/admin/storage-providers/test/cors — 设置跨域规则

- 认证：需要
- 标识：storage.test.cors.set

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |
| rules | array | 是 | CORS 规则数组，至少一条且每条需包含 `allowed_origins`、`allowed_methods` |

示例：
```json
{
  "rules": [
    {
      "allowed_origins": ["http://localhost:8011"],
      "allowed_methods": ["PUT", "GET", "HEAD"],
      "allowed_headers": ["*"],
      "max_age_seconds": 600
    }
  ]
}
```

### 响应
```json
{
  "success": true,
  "message": "跨域规则配置成功"
}
```

若包含 COS 不支持的方法（例如 `OPTIONS`），接口会返回 `success=false` 并提示错误原因。

---

## POST /api/admin/storage-providers/test/buckets — 获取 Bucket 列表

- 认证：需要
- 标识：storage.test.buckets.list

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |

### 响应
```json
{
  "success": true,
  "message": "成功获取 3 个 bucket",
  "buckets": [
    {
      "name": "bucket-123",
      "region": "ap-guangzhou",
      "creation_date": "2025-08-01T09:12:34Z"
    }
  ]
}
```

---

> 说明：上述接口均为「测试」用途，仅用于验证配置或手工调试，正式业务路径仍推荐通过面向业务的 API 访问。
