---
title: U10 E2EE U5 附件加密与外围功能边界验收
date: 2026-08-05
status: partial
scope: api,h5-app
---

# U10 E2EE U5 附件加密与外围功能边界验收

## 结论

U5 的 H5 与 API 侧已形成自动化闭环：附件在端侧独立随机 DEK/nonce 用 AES-GCM
加密后上传，对象存储与数据库只接触密文；AAD 绑定 room/part_key/part_position/
object_key，重试不复用 nonce；E2EE 模式 Push 正文与预览置占位符、服务端全文
搜索返回空、转发明确拒绝。H5 解密后的附件以 objectURL 形式驻留受控内存，不写
入 IndexedDB 明文缓存，DEK/nonce 也不随消息缓存落盘。

原生双端 E2EE 附件专项尚未落地，按
`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 边界交由原生
E2EE 专项补齐；因此 U5 保持 `partial`，生产 E2EE 继续 No-Go，runtime 保持
`persist/plaintext`。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| E2EE 模式搜索空 | `api/tests/e2ee_runtime_boundary.rs` | 明文基线搜索命中；切 e2ee 后 search/suggestions/trending 返回空 |
| E2EE 模式转发拒绝 | 同文件 | `POST /messages/forward` 返回 400「E2EE 模式暂不支持转发消息」 |
| Push 占位符 | `api/src/services/push.rs` `sanitize_for_e2ee` + 单元测试 | content=`【加密消息】`、preview=`你收到一条加密消息` |
| API 全量回归 | `make api.test`（rust-tests 容器） | unit + integration 全通过 |
| 附件加解密往返 | `h5-app/test/e2ee-attachment-crypto.test.ts` | 往返一致；AAD 篡改失败；每次 nonce/DEK 全新；part_position BE32；非法 UUID 抛错 |
| 加密上传流程 | `h5-app/test/message-attachment-upload-service.test.ts`（现有上传用例保持）+ 类型检查 | 签名 → 加密 → 密文 PUT → commit 顺序不变 |
| attachment payload 发送/解密 | `h5-app/test/e2ee-direct-message-coordinator.test.ts` | 发送 payload 为 `{version:1,type:'attachment',parts:[...]}`，密文外字段无明文；decryptPayload 还原 parts |
| 附件消息映射 | `h5-app/test/e2ee-message-service.test.ts` | 解密后生成 attachments 与内存态 `raw.e2ee_parts`，`e2ee_epoch` 保留 |
| E2EE 附件发送链路 | `h5-app/test/chat-detail-store.test.ts` | `uploadEncrypted` → `prepareAttachment` → 乐观附件消息 → `retryPendingSend` |
| 明文不落盘 | `h5-app/test/message-storage.test.ts` | 持久化剔除 `raw.e2ee_parts`，保留 `e2ee_epoch` 与 attachments |
| 密文下载即解密 | `h5-app/test/media-cache-service.test.ts` | 签名 URL 下载密文 → 内存解密 → objectURL，不写 blob cache |
| H5 全量回归 | `npx vue-tsc --noEmit` + `VITE_USE_MOCK_DATA=true npx vitest run` | 类型检查通过；261 项通过、8 项跳过 |

## 实现边界

- K1：附件 DEK/nonce 只随 E2EE application payload 传递；`E2eeAttachmentPart`
  包含 partKey/objectKey/name/mimeType/size/partPosition/nonce/dek。
- K2：AAD = `redcode-im/e2ee/attachment/v1\0 || room_id(raw UUID) ||
  part_key(raw UUID) || part_position(BE32) || object_key(UTF-8)`；part_key 由
  客户端随机生成且只在一条消息中使用一次；发送失败重试必须重新走
  `uploadEncrypted` 生成新 partKey/nonce/DEK。
- K3：`uploadEncrypted` 先签名 → 加密 → PUT 密文 → commit；`part` 仅含密文
  object key 与元数据，E2EE 附件元数据随 payload 走加密通道。
- K4：`loadEncryptedAttachment` 下载密文后在受控内存解密为 objectURL；
  `messageStorage` 持久化前剔除 `raw.e2ee_parts`，密钥不落盘；页面卸载时
  `revoke` 回收 objectURL。
- K5：E2EE 模式 Push 无正文、服务端搜索空、转发 400；引用保持端侧不可用；
  举报仅用户主动提交证据，服务端不解析密文。
- 文本消息 payload 仍为 `{version:1,type:'text',text}`，与历史格式兼容；
  附件消息为 `{version:1,type:'attachment',parts:[...]}`。

## 环境说明

- API 测试在 `tests/docker-compose.test.yml` 的 rust-tests 容器内执行，未映射
  PG/Redis 宿主端口。
- 未切换 E2EE runtime；`persist/plaintext` 保持不变；本单元不涉及 live 联调，
  原生端专项待补。
