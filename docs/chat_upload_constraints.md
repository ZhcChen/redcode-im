# 上传与消息约束同步（2025-11-05）

## 背景
- 后端已提供 COS 直传 API；Admin、Frontend、Desktop 需统一体验。
- 用户明确：聊天消息需支持文本 + 多媒体混合发送，音频消息独占。
- 直传地址默认私有读，需通过下载签名获取临时链接；前端收到 key 后自行缓存文件。
- 位置共享功能暂不需要；语音指语音消息（非通话）。

## 实施要点
1. **直传流程**
   - 前端调用 `/rooms/:room_id/messages/attachments/signature` 获取 key + 签名。
   - 使用返回的 URL/headers 直传至 COS；上传过程中实时更新进度。
   - 发送消息时附带 key，后端负责值校验并广播消息。
   - 下载通过 `/rooms/:room_id/messages/attachments/download?key=...` 获取临时链接；前端落地缓存（AttachmentCache）。

2. **消息/上传约束（前端已实现，后端需同步）**
   - 单文件 ≤ **50 MB**；单条消息总附件 ≤ **100 MB**；单条附件数量 ≤ **10**。
   - MIME 白名单：
     - 图片 `image/jpeg`、`image/png`、`image/webp`
     - 视频 `video/mp4`、`video/quicktime`
     - 音频 `audio/aac`、`audio/m4a`、`audio/mp4`
     - 文档 `application/pdf`、`application/msword`、`application/vnd.openxmlformats-officedocument.wordprocessingml.document`、`application/vnd.ms-excel`、`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`、`application/vnd.ms-powerpoint`、`application/vnd.openxmlformats-officedocument.presentationml.presentation`、`application/zip`
   - 语音消息只能包含单个音频分片，且不能附带文本/其他附件。
   - 上传前前端校验大小/数量/类型，后端签名及写入处需重复校验。

3. **上传体验**
   - 图片/文件气泡展示上传进度；完成后隐藏，失败展示错误提示，可手动重试。
   - 前端新增 AttachmentCache，本地缓存下载结果。
   - 聊天输入框统一走 `sendRichMessage`，支持文本 + 多附件组合发送。

4. **未实施 / 下一步**
   - 后端提供动态配置接口，下发大小/数量/白名单等策略；前端用接口值替换 `AppConfig` 常量。
   - 桌面端与其他客户端复用同一套逻辑。
   - 产品决定是否引入语音通话、位置分享等额外能力。

## 参考改动
- `AppConfig` 增补上传策略常量。
- `MessageService.sendRichMessage`：校验策略、上传进度、失败重试。
- `ChatProvider` / `ChatDetailPageV2`：统一走 `sendRichMessage`，UI 展示进度、选择文件时校验类型。
- 新增 `AttachmentCache` & `DirectUploadSignature` 工具模块。

## 待办执行计划

### 1. 动态配置接口设计
- **接口路径**：新增 `GET /system/upload-policy`，由配置中心统一返回；在房间上下文下保持 `/rooms/:room_id/messages/attachments/signature` 不变。
- **响应结构**：包含 `max_file_size_mb`、`max_total_size_mb`、`max_attachments_per_message`、`mime_whitelist`、`audio_only` 等字段；保留 `version` 字段用于灰度扩展。
- **权限与缓存**：接口要求登录态；后端通过 Redis 缓存 5 分钟并支持配置热更新，前端在 `AppConfig` 初始化阶段拉取并写入本地缓存（Flutter/桌面均复用）。
- **回滚策略**：若接口不可用，前端回退到 `AppConfig` 本地默认值并上报 Sentry/埋点；后端保持严格校验，拒绝超限请求。
- **时间节点**：
  - 2025-11-06 完成接口定义与伪数据实现。
  - 2025-11-07 接入后端真实配置源（目前为环境变量+数据库快照）。
  - 2025-11-08 Flutter 与桌面端完成请求与缓存集成，自测通过后发起联调。

#### 接口草案
- **请求示例**：
  ```http
  GET /system/upload-policy HTTP/1.1
  Authorization: Bearer <token>
  X-Client-Version: 2.8.0
  ```
- **响应示例**：
  ```json
  {
    "version": "2025-11-07",
    "max_file_size_mb": 50,
    "max_total_size_mb": 100,
    "max_attachments_per_message": 10,
    "mime_whitelist": [
      "image/jpeg",
      "image/png",
      "image/webp",
      "video/mp4",
      "video/quicktime",
      "audio/aac",
      "audio/m4a",
      "audio/mp4",
      "application/pdf",
      "application/zip"
    ],
    "audio_only": {
      "enabled": true,
      "force_single_attachment": true,
      "allow_text": false
    }
  }
  ```
- **错误码约定**：`UPLOAD_POLICY_NOT_FOUND`（配置缺失）、`UPLOAD_POLICY_FETCH_FAILED`（远端服务异常）、`FORBIDDEN`（令牌无权限）。全部错误走 `message` + `trace_id` 统一结构。
- **监控要求**：新增 Prometheus 指标 `upload_policy_fetch_latency`、`upload_policy_cache_hit_ratio`，并在 Grafana 仪表盘对接告警阈值（命中率 < 95% 告警）。

### 2. 客户端复用逻辑
- **公共模块**：沉淀 `direct-upload` 工具（签名、上传、重试、事件回调），Flutter 与桌面端分别通过 `AttachmentUploader` 适配 UI；Admin 复用 TypeScript 版本。
- **文件缓存**：统一约束缓存目录命名与过期策略（默认 48 小时）；桌面端落地到 `~/.redcode/attachments`，移动端使用沙箱目录，命中后直接返回本地路径。
- **错误处理**：三端统一上报字段（`module=upload`, `stage=sign|put|send`, `error_code`），后端提供对齐的错误枚举，便于观测。
- **交付目标**：2025-11-10 前完成桌面端复用并通过冒烟测试；其他客户端同步排期。

#### 客户端拆解
- **Flutter**：
  - 2025-11-06 之前完成 `AttachmentCache` 接口定义与缓存目录初始化。
  - 2025-11-08 自测通过文件上传（含失败重试）。
- **桌面端**：
  - 2025-11-07 接入 `direct-upload` 工具，校验多附件组合发送。
  - 2025-11-09 完成冒烟用例（图片、视频、文档、音频）。
- **Admin**：
  - 2025-11-08 接入统一工具，重点校验表单批量上传。
- **数据观测**：2025-11-10 前补充三端埋点，输出仪表盘初版。

## 联调与测试计划
- **接口联调顺序**：先验证签名接口与直传流程（2025-11-08 前完成），再验证下载签名接口，最后回归富文本消息发送。
- **自动化测试**：
  - 后端新增 `uv run python -m pytest backend/tests/upload`，覆盖签名校验、白名单校验、大小限制三大场景。
  - 桌面端增加 `AttachmentUploader` 单元测试以及 `bun run test --filter upload` 冒烟脚本。
  - Flutter 侧补充 `attachment_cache_test.dart`，关注缓存命中与过期。
- **手工测试清单**：
  1. 异常 MIME/大小/数量阻断并提示。
  2. 上传中断后用户手动重试成功。
  3. 同一文件重复发送命中缓存，无重复下载。
  4. 语音消息仅音频附件时成功，其余组合拦截。
- **联调出口**：每日 16:00 前同步联调状态到 `#proj-upload` 频道，阻塞项需在 24 小时内明确责任人。

## 风险与兜底
- **配置下发滞后**：若配置中心不可用，后端 fallback 至环境变量副本并打 Warn 日志；前端沿用本地默认值并弹出弱提醒。
- **上传峰值导致 COS 限流**：提前在 2025-11-07 与运维确认限流阈值，必要时启用分片上传并调整重试退避策略（指数退避 + 抖动）。
- **终端缓存膨胀**：加上 48 小时定时清理任务，桌面端允许用户在设置页手动清理缓存；Flutter 与桌面端均记录缓存命中率，命中率 < 70% 时触发性能检查。
- **日志与隐私**：禁止在日志中记录真实文件名，统一使用散列；Sentry 仅上报错误码与 trace_id。
