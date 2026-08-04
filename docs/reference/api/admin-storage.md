# 对象存储测试接口（Admin）

> 这些接口位于后台管理域下，仅对已登录管理员开放。当前仅支持 **S3 兼容对象存储**，不再包含历史存储专用跨域配置能力。

## RustFS 配置

API 直接使用 `aws-sdk-s3` 和 path-style addressing，不需要 RustFS 专用 SDK。推荐环境变量：

```text
REDCODE_IM_S3_ENDPOINT=http://rustfs:9000
REDCODE_IM_S3_REGION=us-east-1
REDCODE_IM_S3_ACCESS_KEY=<access-key>
REDCODE_IM_S3_SECRET_KEY=<secret-key>
REDCODE_IM_S3_PRIVATE_BUCKET=redcode-im-private
REDCODE_IM_S3_PUBLIC_BUCKET=redcode-im-public
REDCODE_IM_S3_PUBLIC_BASE_URL=https://media.example.com
REDCODE_IM_S3_PRESIGN_PUBLIC_ENDPOINT=https://storage.example.com
```

`REDCODE_IM_S3_PRESIGN_PUBLIC_ENDPOINT` 仅在容器内部 endpoint 无法被客户端访问时设置，用于改写预签名 URL 的 scheme、host 和 port。旧 `REDCODE_IM_B2_*` 变量仅作为迁移期 fallback，不再推荐使用。

管理接口的 `provider_type` 使用 `s3_compatible`。迁移期仍接受旧请求值 `backblaze_b2`，响应统一返回 `s3_compatible`。服务端没有本地文件 provider。

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
  "url": "http://rustfs:9000/demo-private-bucket/test/hello.png"
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
    "url": "http://rustfs:9000/demo-private-bucket/test/20260413-demo.png",
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
  "url": "http://rustfs:9000/demo-private-bucket/test/hello.png?X-Amz-Algorithm=AWS4-HMAC-SHA256..."
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

## 存储提供商管理

| 操作 | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 列表 | `GET` | `/api/admin/storage-providers` | 获取全部存储提供商 |
| 创建 | `POST` | `/api/admin/storage-providers` | 新增提供商（`provider_type` 当前为 `s3_compatible`） |
| 默认提供商 | `GET` | `/api/admin/storage-providers/default` | 获取当前默认提供商 |
| 更新 | `PATCH` | `/api/admin/storage-providers/{provider_id}` | 修改提供商配置 |
| 删除 | `DELETE` | `/api/admin/storage-providers/{provider_id}` | 删除提供商 |

## 存储配置管理

存储配置采用「验证 → 探测 → 应用 → 可回滚」的流程，全部接口仅管理员可用：

| 操作 | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 当前配置 | `GET` | `/api/admin/system/storage-config` | 返回 `{ "current": {...} }` |
| 校验 | `POST` | `/api/admin/system/storage-config/validate` | 校验配置合法性，返回 `{ "valid": true, "normalized": {...} }` |
| 探测 | `POST` | `/api/admin/system/storage-config/probe` | 校验并探测连通性/权限，返回 `{ "normalized": ..., "probe": ... }` |
| 应用 | `POST` | `/api/admin/system/storage-config/apply` | 应用新配置并记录历史 |
| 历史 | `GET` | `/api/admin/system/storage-config/history` | 返回 `{ "list": [...] }` |
| 初始化 bucket | `POST` | `/api/admin/system/storage-config/init-bucket` | 按配置创建私有/公开 bucket |
| 回滚 | `POST` | `/api/admin/system/storage-config/rollback` | 回滚到上一份可用配置 |

> 应用或回滚前建议先执行 `validate` + `probe`；`RUSTFS_INTERNAL_ENDPOINT` 等
> 容器内地址不应改为公网域名，否则对象存储签名链路会绕回反代导致上传/下载异常
> （见 `deploy/im-test-1/README.md`）。
