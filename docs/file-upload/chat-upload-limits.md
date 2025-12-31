# 上传与消息约束同步（2025-11-05，更新：2025-12-31）

## 背景
- 后端已提供对象存储（COS/S3 等）直传能力；Admin/Flutter/Desktop 需要统一附件限制与校验逻辑。
- 聊天消息支持文本 + 多媒体混合发送；语音消息默认独占（单音频、不可混合其他内容）。
- 直传地址默认私有读：下载通过“下载签名/临时链接”获取；客户端可自行做本地缓存。

## 直传流程（消息附件）
1. 客户端调用 `POST /rooms/{room_id}/messages/attachments/signature` 获取 `key + 签名`。
2. 使用返回的 `url/headers` 直接上传到对象存储；上传中更新进度。
3. 发送消息时带上 `key`；后端校验并广播消息。
4. 下载通过 `GET /rooms/{room_id}/messages/attachments/download?key=...` 获取临时链接（客户端可落地缓存）。

## Upload Policy（动态上传策略下发）

### 作用与场景
- 把“附件大小/数量/MIME 白名单”等限制从客户端硬编码迁移为**后端可配置并下发**。
- 典型场景：临时收紧某类附件大小、允许/禁用某些 MIME、统一多端校验口径（无需客户端发版）。
- **兜底原则**：客户端拉取策略失败时回退本地默认值；后端仍会做严格校验并拒绝不合法请求。

### 接口
- **用户端（登录态）**：`GET /system/upload-policy`
- **管理端（管理员）**：`GET /api/admin/settings/upload-policy`、`PUT /api/admin/settings/upload-policy`
- **Admin 配置入口**：管理后台“通用设置 → 上传策略”

### 存储与缓存
- 配置存储：`general_settings.key = upload_policy`（JSON）。
- 运行时缓存：后端进程内 TTL（默认 60 秒）；未配置/解析失败自动回退内置默认策略 `builtin-v1`。

### 默认策略（builtin-v1）
- `max_total_size_mb = 100`
- `max_attachments_per_message = 10`
- `max_size_mb_by_part_type`（单文件上限，按类型）：
  - `image = 5MB`（与服务端当前图片校验一致）
  - `video = 100MB`
  - `audio = 20MB`
  - `file = 50MB`
- `mime_by_part_type`：由后端白名单常量生成（可直接调用 `GET /system/upload-policy` 查看实时值）。
- `audio_only`：`enabled=true, force_single_attachment=true, allow_text=false`
  - 说明：当前后端固定强制“语音不可混合其他内容”，暂不支持通过策略放开。

### 后端校验点（与策略一致）
- `POST /rooms/{room_id}/messages`：附件数量/总大小/分类型大小/MIME 白名单/危险类型过滤
- `POST /rooms/{room_id}/messages/attachments/signature`：MIME 白名单 + 分类型大小
- `POST /rooms/{room_id}/messages/attachments/multipart/initiate`：MIME 白名单 + 分类型大小

## 未完成 / 下一步
- Flutter：接入 `GET /system/upload-policy`，用下发值替换 `AppConfig` 常量（失败回退本地默认值）。
- Desktop：接入 `GET /system/upload-policy`，替换 `Chat.vue` 内的硬编码大小/MIME 校验（失败回退旧逻辑）。
- Go（Go 1.25）集成测试：覆盖“用户端获取策略 / 管理端更新策略 / 策略变更后校验生效”等关键链路。
