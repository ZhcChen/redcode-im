# 对象存储测试接口（Admin）

> 这些接口位于后台管理域下，仅对已登录管理员开放。当前仅支持 **Backblaze B2**，不再包含历史存储专用跨域配置能力。

## POST /api/admin/storage-providers/test/upload

直接上传一个测试对象，验证提供商配置可用。

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID；不填则使用默认提供商 |
| key | string | 是 | 对象键，例如 `test/hello.png` |
| content_type | string | 否 | MIME 类型 |
| content | string | 否 | 可选文本内容 |

### 响应
```json
{
  "success": true,
  "message": "上传成功",
  "url": "https://s3.us-east-005.backblazeb2.com/demo-private-bucket/test/hello.png"
}
```

## POST /api/admin/storage-providers/test/upload/signature

生成前端直传签名。

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |
| key | string | 是 | 对象键，例如 `test/20260413-demo.png` |
| content_type | string | 否 | 实际上传使用的 `Content-Type` |
| file_size | number | 否 | 文件大小（字节），用于哈希去重 |
| hash_value | string | 否 | 文件哈希 |
| hash_alg | number | 否 | 哈希算法，默认 `1=md5` |

### 响应
```json
{
  "success": true,
  "message": "生成直传签名成功",
  "signature": {
    "url": "https://s3.us-east-005.backblazeb2.com/demo-private-bucket/test/20260413-demo.png",
    "method": "PUT",
    "headers": {
      "Authorization": "AWS4-HMAC-SHA256 Credential=...",
      "Content-Type": "image/png"
    },
    "key": "test/20260413-demo.png"
  }
}
```

若命中哈希去重，接口会返回：

```json
{
  "success": true,
  "message": "复用已上传的测试文件，未生成新的直传签名",
  "signature": null
}
```

## POST /api/admin/storage-providers/test/upload/multipart/initiate

初始化分片上传会话。

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |
| key | string | 是 | 对象键 |
| file_size | number | 是 | 文件大小（字节） |
| content_type | string | 否 | MIME 类型 |
| hash_value | string | 否 | 文件哈希 |
| hash_alg | number | 否 | 哈希算法 |

### 响应
```json
{
  "success": true,
  "message": "初始化分片上传会话成功",
  "key": "test/large.bin",
  "session_id": "8df5f87b-...",
  "part_size": 8388608,
  "total_parts": 4
}
```

## POST /api/admin/storage-providers/test/download-url

生成临时下载链接。

### 请求体
| 字段 | 类型 | 必填 | 说明 |
| ---- | ---- | ---- | ---- |
| provider_id | string | 否 | 指定存储提供商 ID |
| key | string | 是 | 对象键 |
| expires_in_seconds | number | 否 | 有效期，默认 3600 |

### 响应
```json
{
  "success": true,
  "message": "生成下载链接成功",
  "url": "https://s3.us-east-005.backblazeb2.com/demo-private-bucket/test/hello.png?X-Amz-Algorithm=AWS4-HMAC-SHA256..."
}
```

## POST /api/admin/storage-providers/test/delete

删除测试对象。

## POST /api/admin/storage-providers/test/exists

检查测试对象是否存在。

### 响应
```json
{
  "success": true,
  "exists": true,
  "message": "文件存在"
}
```

## POST /api/admin/storage-providers/test/buckets

列出当前凭据可访问的 bucket。

## POST /api/admin/storage-providers/test/buckets/create

创建 bucket（取决于提供商权限）。

---

说明：这些接口仅用于配置验证与日常排障，正式业务请使用面向消息、头像、版本管理等业务接口。
