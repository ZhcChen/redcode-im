---
title: U10 E2EE E2 Restore 整改独立复核
date: 2026-08-06
status: complete
subject: aa60593181a23da77318e166610e51a082d9dafc
scope: 6d3afaac..aa605931
verdict: pass
production_verdict: no-go
---

# U10 E2EE E2 Restore 整改独立复核

## 结论

E1.3 实现与证据在同一已推送 subject `aa605931` 上由四个全新独立上下文完成
correctness、security、reliability、testing 复核。四个视角均为
`P0=0、P1=0、P2=0`，E2 门禁通过，可按唯一 active 计划进入 E3。

本结论只关闭 restore 真实性和边界证据复核，不改变生产裁决。E3-E7 尚未完成，
生产 E2EE 继续 **No-Go**，旧主保持 `persist/plaintext`。

## 独立结果

| 视角 | P0 | P1 | P2 | Verdict |
| --- | ---: | ---: | ---: | --- |
| correctness | 0 | 0 | 0 | PASS |
| security | 0 | 0 | 0 | PASS |
| reliability | 0 | 0 | 0 | PASS |
| testing | 0 | 0 | 0 | PASS |

四个 reviewer 均为 E1.3 提交并推送后创建的新上下文；E1.3 预审和前两轮 E2
reviewer 未复用为通过证据。

## 关闭项

- **附件归属：** 可信 H5 `uploadEncrypted -> sendAttachment -> Android 解密确认`
  runtime 产生 message/object/ciphertext tuple；临时 HMAC 绑定 message id、marker、
  ciphertext SHA-256、kind、object key；scanner 验证 DB message/ciphertext/room 与
  commit/object/room。
- **协议边界：** `SendEncryptedMessagePayload` 使用 `deny_unknown_fields`，encrypted
  endpoint 只持久化占位 text part；不假设 object key 进入 `message_parts`，不扩展
  服务端契约。
- **防拼接：** marker、ciphertext、object、HMAC key、message-room、object-room、
  object-message 错配和重复 room/message/marker 均有 fail-closed 负例。
- **source isolation：** restore API 不接入 `im-test-1-network`；storage network 为
  run-scoped internal 且仅含 API/RustFS，ingress 仅含 API；owner、Internal 和成员
  集合均运行时校验。
- **Push：** 所有关联行逐条校验固定 content/preview；混合正文、缺字段和 JSON
  null 均 fail closed。真实 run 为 `not-observed-live`，未冒充 placeholder 已验证。
- **MONITOR：** 扫描前检查 PID，发送并捕获末端 probe 后才复制不可变快照；提前
  退出、probe 丢失和缺少精确 `PUBLISH room:<uuid>` 均 fail closed。
- **cleanup：** run-scoped container、volume、network、state、HMAC key、MONITOR、
  tunnel 与 `18010` 清零；旧主保持 `persist/plaintext`。
- **第二轮 P2：** candidate 恢复前消息由同 run snapshot、restore 后 history 解密和
  DB 密文扫描覆盖；文档未把 restore MONITOR/API log 夸大为对 candidate 瞬时流量
  的追溯。

## 证据与测试

最终 run `e1fix20260806g`：

- candidate/restore digest：`2c34ac950bee5a780988321a518d589d`。
- full suite：`6 passed | 1 skipped`。
- 四个 scenario、九条 message proof、一个加密附件。
- DB/Redis/API log/RustFS：通过；Push：`not-observed-live`。
- RustFS SHA-256：`98a5247b56dcf90bcc8acbb9f491f82a2974aa570e8d0e305813d37c1846d206`。

四个视角独立运行或核对的门禁：

```text
make e2ee.restore-compose.test
make e2ee.restore-control.test
make e2ee.restore-window.test
make e2ee.restore-boundary.test
make e2ee.restore-live.test
make e2ee.cross-client.isolated.test
cd h5-app && bun run type-check
```

control 9 个网络/cleanup 场景、boundary 22 个 proof/Push/MONITOR 场景、live 8 个
切换/失败清理场景全部通过。复核结束时工作区干净且 `HEAD == origin/main`。

## 后续

进入 E3 H5 production `E2eeSecureStateStorage` Chrome 审计。E3 不得使用替代
AES/IndexedDB 实现或 production 审计后门；E3-E7 全部关闭前生产保持 No-Go。
