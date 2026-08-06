---
title: U10 E2EE E4 持久脱敏证据验收
date: 2026-08-06
status: complete
scope: evidence,sanitization,offline-verification,g1,g3
verdict: pass
evidence_commit: a383f788ee310211c60b137d16a4d75858520785
---

# U10 E2EE E4 持久脱敏证据验收

## 结论

E4 已完成。G1 restore 和 G3 H5 production 的机器证据已按白名单从本地
`.artifacts/` 生成可提交 JSON，并在 evidence commit `a383f788` 中持久化。两份
证据可从不含 `.artifacts/` 的干净 detached worktree 离线验证，不依赖 GitHub
artifact retention、远端服务或运行时环境。

本报告只关闭 E4，不构成生产 E2EE Go。唯一 active 计划推进到 E5.1，生产继续保持
**No-Go**。

## 证据身份

| Evidence | Subject commit | 文件 SHA-256 |
| --- | --- | --- |
| `docs/reviews/evidence/u10-e2ee/g1-backup-rollout.json` | `d385c88b9c83b911acc2c6a7189ee6fa745f05dd` | `3edd8d3244e0424a29f14baf2da4b6b467dcc7aeab9b0e28a33ad61879a6690e` |
| `docs/reviews/evidence/u10-e2ee/g3-h5-release.json` | `f6944a70fd314a90b82abf065649b3e679b1750b` | `415a311af78879396451ca95ef0e06f9bde1710b08dcf9ee198588f47e1a2d1a` |
| `scripts/e2ee-evidence/schema-v1.json` | evidence contract v1 | `de55d1e73ab472d194186352d0c29cad409604756a0fbf4fa47df53f672a789a` |

G1 subject 使用真实 run 所执行的实现提交 `d385c88b`；后续 `aa605931` 是 review
文档提交，不冒充运行 subject。G3 subject 使用最终完整 Chrome run 对应的
`f6944a70`。每个 subject 都必须是完整小写 SHA、存在于当前仓库并为当前 HEAD 的
ancestor。

## 白名单与脱敏

- envelope 仅允许 `schema`、`evidence_type`、`subject_commit`、commit 时间、
  generator 身份、assertions 和 `integrity_sha256`。
- G1 只保留 snapshot 计数/digest、隔离 runtime 断言、scenario/proof 数量、恢复
  连续性布尔值、post-live 计数和 DB/Redis/log/Push/RustFS 枚举及摘要。
- G3 只保留 manifest 摘要、production store/CryptoKey/AAD fail-closed 布尔值、
  encrypted record/Network/WebSocket/Console/page error 计数和私有资源 404 断言。
- 禁止提交账号、token、密码、连接串、私钥、DEK、nonce、room/message/user UUID、
  object key、plaintext marker、HMAC、可复用 URL 及原始 Console/Network/log 内容。
- sanitizer 在计数前验证 G1 每条 raw proof 的精确字段、message ID、ciphertext
  SHA-256、binding HMAC 和 attachment object 结构；G3 原始 browser/attestation
  必须精确匹配 subject 与 manifest SHA-256。
- 每份 evidence 的 `integrity_sha256` 覆盖规范化 envelope；Git evidence commit 和
  本报告记录的文件摘要提供长期不可变身份，避免把自摘要当作签名。

## 离线验证

`make e2ee.evidence.verify` 检查：

- schema 和 evidence 精确字段白名单，禁止 additional properties；
- integrity SHA-256、subject commit 可达性、commit 时间与 generator 身份；
- G1 snapshot 完全一致、source network 不可达、旧主连接为零、4 scenario/9 proof/
  1 attachment、恢复前后历史与新消息可解密、所有外围边界枚举通过；
- G3 production path 全部布尔断言、至少一个 encrypted record/Network URL/WebSocket
  frame、page error 为零、私有文件和缺失资源为 404；
- 整个 envelope 的敏感字段和值扫描为零。

在 detached worktree `a383f788` 中执行：

```text
make e2ee.evidence.verify e2ee.evidence.test
```

结果为 2 份 committed evidence 通过，且不读取当前工作区 `.artifacts/`。临时
worktree 在测试后已删除。

## 负向测试

`make e2ee.evidence.test` 覆盖并 fail closed：

- payload 修改但未更新 integrity；
- 重算 integrity 后增加未审字段；
- 重算 integrity 后加入 plaintext marker；
- 重算 integrity 后将 snapshot 改为不匹配；
- 重算 integrity 后移除 WebSocket 观测；
- subject commit 不可达；
- 任一 evidence 文件缺失；
- schema 允许 additional properties；
- raw browser evidence 增加额外字段；
- raw G1 proof 的 binding HMAC 格式损坏。

合成 raw G1/G3 报告重新生成 evidence 后也通过同一 verifier，证明 generation 与
offline verification 是一条完整路径，而不是只校验手写 fixture。

## 下一步

按唯一 active 计划进入 E5.1：从干净且已 push 的候选 commit 手工触发
`Build Release Artifacts`，固定 `publish_release=false`，验证 supply-chain job 依赖、
head SHA、artifact identity、tag/Release 零副作用。E5 完成前生产 E2EE 保持
**No-Go**。
