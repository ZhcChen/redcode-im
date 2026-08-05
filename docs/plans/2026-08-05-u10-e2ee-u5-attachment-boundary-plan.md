---
title: "feat: U10 E2EE U5 附件加密与外围功能边界执行计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: active
---

# feat: U10 E2EE U5 附件加密与外围功能边界执行计划

## Goal Capsule

- **目标：** 在 U3/U4 的 active epoch 之上，让附件在端侧独立随机 DEK + AES-GCM
  AEAD 加密后上传，对象存储/数据库只保存密文；E2EE 模式下 Push 无正文、服务端
  全文搜索与转发明确禁用、引用保持端侧不可用、举报只提交用户主动选择的证据。
- **前置状态：** U4 已完成（`docs/reviews/2026-08-05-u10-e2ee-u4-group-chat.md`）；
  服务端 E2EE 消息链路、房间 epoch 门禁、H5 房间级协调器已就绪。
- **发布约束：** 原生双端 E2EE 专项未落地前 U5 保持 partial；生产 E2EE No-Go，
  runtime 保持 `persist/plaintext`。

## 关键设计决策

- K1. **附件密钥只在端侧 E2EE application payload 中传递。** 每个附件 part 使用
  独立随机 32 字节 DEK 与 12 字节 nonce；DEK/nonce 随
  `{version:1, type:'attachment', parts:[...]}` 密文 payload 发送，服务端不可见。
- K2. **AAD 绑定 room、part 与 object key。** AAD =
  `redcode-im/e2ee/attachment/v1\0 || room_id || part_key || part_position(BE32) ||
  object_key`；part_key 由客户端随机生成且只在一条消息中使用一次，等价绑定
  message；重试必须重新生成 nonce 与 part_key，禁止复用。
- K3. **上传链路上传的是密文。** 先请求签名拿到 object key，再生成 AAD 加密，
  再 PUT 密文并 commit；对象存储、数据库 attachment 记录只出现密文 key。
- K4. **解密结果只驻留受控内存。** E2EE 附件下载后解密为 Blob，仅在本页
  objectURL 生命周期内使用，不写入 IndexedDB 明文缓存；退出账号/刷新时回收。
- K5. **外围功能 fail closed。** E2EE 模式：Push 正文与预览置占位符；服务端全文
  搜索返回空；转发返回明确错误；引用保持“后续版本支持”的端侧明确不可用；
  举报只允许用户主动上传的外部截图证据。

## Implementation Units

### U5-A. H5 附件加密与展示

- `h5-app/src/e2ee/attachment-crypto.ts`：DEK/nonce 生成、AES-GCM 加解密、
  AAD 构造、`E2eeAttachmentPart` 类型。
- `h5-app/src/services/message-attachment-upload-service.ts`：
  `uploadEncrypted`（签名 → 加密 → 密文上传 → commit → part + e2eePart）。
- `h5-app/src/e2ee/direct-message-coordinator.ts`：payload 泛化
  （`type:'text'` / `type:'attachment'`），`sendAttachment` 与通用 payload 解密。
- `h5-app/src/services/message-service.ts`：attachment 消息解密映射与
  `raw.e2ee_parts`。
- `h5-app/src/services/attachment-cache.ts` + `CachedAttachment.vue`：E2EE
  附件下载即解密、不持久缓存明文。
- `h5-app/src/stores/chat-detail.ts`：E2EE 附件发送链路接入。

### U5-B. 服务端外围边界

- `api/src/handlers/message.rs`：E2EE 模式转发拒绝；Push snapshot 正文/预览置
  占位符。
- `api/src/handlers/message_search.rs`：E2EE 模式搜索返回空。
- 测试：Push 无正文、搜索空结果、转发拒绝。

### U5-C. 测试与验收

- H5：加密往返/AAD 篡改失败/nonce 不复用、加密上传流程、attachment payload
  发送与解密、聊天页附件发送。
- API：e2ee 模式 search/forward/push 边界。
- 全量回归：`cargo test --tests`、`vue-tsc --noEmit`、vitest。
- `docs/reviews/2026-08-05-u10-e2ee-u5-attachment-boundary.md`。

## Definition of Done

- D1. H5 E2EE 附件完成加密上传、密文下载解密与受控展示；AAD 绑定 room/part/
  object key，重试不复用 nonce。
- D2. S3/DB/API 日志中附件链路只有密文与占位符，无正文/DEK marker。
- D3. E2EE 模式 Push 无正文、服务端搜索空、转发明确失败、引用端侧不可用、
  举报仅用户主动证据。
- D4. 计划与验收记录同步；U5 保持 partial（原生端专项未落地），生产 No-Go。

## 执行状态（2026-08-05）

- U5-A（H5 附件加密与展示）：完成。attachment-crypto、uploadEncrypted、
  coordinator payload 泛化、message-service 映射、下载即解密与 chat-detail
  发送链路均已接入并通过测试。
- U5-B（服务端外围边界）：完成。Push 占位符、搜索空、转发拒绝与边界测试
  已合入 API。
- U5-C（测试与验收）：H5/API 自动化全通过（vue-tsc、vitest 261 通过、
  `make api.test` 全通过），验收记录见
  `docs/reviews/2026-08-05-u10-e2ee-u5-attachment-boundary.md`。
- 原生双端 E2EE 附件专项未落地，U5 保持 `partial`；生产 E2EE No-Go。
