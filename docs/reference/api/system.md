# 系统管理接口

## GET /healthz — 健康检查

检查服务器运行状态，用于负载均衡器和监控系统的健康检查。

- 需要认证：否
- 标识：health

### 请求体
无

### 响应
#### HTTP 200
服务器运行正常
示例：
```json
"ok"
```

## GET / — 根路径

获取API基础信息。

- 需要认证：否
- 标识：root

### 请求体
无

### 响应
#### HTTP 200
成功获取基础信息
示例：
```json
"redcode IM api"
```

## GET /readyz — 就绪检查

检查 PostgreSQL、Redis（session/cache）依赖是否可用；任一依赖异常返回
HTTP 503。

- 需要认证：否
- 标识：ready

### 响应
#### HTTP 200
```json
{
  "status": "ok",
  "checks": {
    "database": { "status": "ok" },
    "redis_session": { "status": "ok" },
    "redis_cache": { "status": "ok" }
  }
}
```

#### HTTP 503
依赖不可用（`status` 为 `unhealthy`，对应 `checks` 项为 `error`）。

## 公开设置接口

以下接口均无需认证，供客户端启动时拉取全局配置。

### GET /settings/privacy-policy

获取隐私政策文档，未配置时返回内置占位内容。

响应（`DocumentContent`，见 `models.md`）：

```json
{
  "key": "privacy_policy",
  "title": "隐私政策",
  "content": "<p>...</p>",
  "updated_at": "2026-08-04T10:00:00Z",
  "updated_by": null
}
```

### GET /settings/user-agreement

获取用户协议文档，结构与隐私政策一致。

### GET /settings/general

获取通用设置（应用名称与消息运行时模式）：

```json
{
  "app_name": "RedCode IM",
  "message_runtime": {
    "server_storage_mode": "persist",
    "content_audit_mode": "none",
    "updated_at": null,
    "updated_by": null
  }
}
```

### GET /settings/app-name

获取应用名称：

```json
{
  "app_name": "RedCode IM"
}
```

### GET /settings/captcha

获取验证码登录开关：

```json
{
  "require_captcha_for_login": false
}
```

## GET /system/upload-policy

获取当前上传策略（附件大小/数量/MIME 白名单等），供客户端发送消息前校验。

- 需要认证：是

响应包含 `version`、`max_total_size_mb`、
`max_attachments_per_message`、`max_size_mb_by_part_type`、
`mime_by_part_type`、`mime_whitelist`、`audio_only` 等字段。
