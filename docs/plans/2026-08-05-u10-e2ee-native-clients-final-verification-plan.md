---
title: "test: U10 E2EE 原生客户端最终验证与裁决计划"
date: 2026-08-05
type: test
artifact_contract: ce-unified-plan/v1
artifact_readiness: complete
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code
status: complete
current_unit: complete
completed_at: 2026-08-05
next_plan: docs/plans/2026-08-05-u10-e2ee-release-readiness-execution-plan.md
---

# test: U10 E2EE 原生客户端最终验证与裁决计划

## 1. 完成结论

本计划已完成，不再作为任务恢复点。R1-R4 全部闭环，U7 P0-1（原生双端聊天
主链接入与 Android/iOS/H5 三端 E2EE live 缺失）已关闭。

生产 E2EE 仍为 **No-Go**。后续唯一 active 入口为
`docs/plans/2026-08-05-u10-e2ee-release-readiness-execution-plan.md`，只处理 U7
剩余三个 P0；不得从本文恢复 N1-N7、A1-A4 或 R1-R4。

## 2. 已完成范围

| 单元 | 结果 | 关键证据 |
| --- | --- | --- |
| R1 审查修复 | 完成 | `22cb78f2`、`a4a703d7`；附件 grant lease、GC 串行化、H5 大小边界和 scanner 加固 |
| R2 三场景复验 | 完成 | run `r21785933828`；H5-H5、Android-H5、iOS-H5 全部通过 |
| R3 N7/U7 裁决 | 完成 | N7 验收记录与 U7 独立安全审查只关闭 P0-1 |
| R4 最终门禁 | 完成 | run `r41785934114`、core 四目标、JDK21 `test.all`、JDK21 `test.live` 全绿 |

最终 live evidence：

- H5-H5 room：`019fd1f8-0791-7c91-8e7d-c1b0492bf191`
- Android-H5 room：`019fd1f8-07a9-75f3-868f-58a799ccdf06`
- iOS-H5 room：`019fd1f8-3a1f-7fb2-ac09-873e311e0418`
- Object key：`messages/019fd1f8-07a9-75f3-868f-58a799ccdf06/files_20260805/58370c00.txt`
- S3 SHA-256：`c0ff04f5ad3fc5ccaa5c0be2ef05cc826994beb74426291cb25c9b0953da21a2`
- DB：ciphertext-only；Redis、logs：marker-free；Push：`not-observed-live`
- 正常、失败、INT、TERM 后 runtime 均恢复 `persist/plaintext`

## 3. 最终门禁

| 门禁 | 结果 |
| --- | --- |
| `make e2ee.cross-client.live` | 通过，run `r41785934114` |
| `make e2ee-core.check` | 通过 |
| `make e2ee-core.check.targets` | 通过，四目标构建成功 |
| JDK21 `make test.all` | 通过 |
| JDK21 `make test.live` | 通过；Android、iOS、Admin、Desktop live smoke 全绿 |

未显式设置 JDK21 的首次 `make test.live` 在 Gradle 配置阶段因 JDK26 失败，不是
代码失败；按仓库固定 JDK21 约束重跑后通过。

## 4. 已关闭与未关闭边界

**本计划已关闭：**

- 原生 Android/iOS FFI、安全存储、设备生命周期、单聊、多设备、群聊与附件。
- Android/iOS/H5 文本和附件跨端互解、恢复、补拉、去重、rekey 与 fail closed。
- DB、Redis、logs、S3 泄漏抽检及 runtime 自动恢复。
- U7 P0-1。

**本计划未关闭：**

1. 生产备份恢复、灰度窗口与滚动部署演练。
2. CI 漏洞扫描与依赖许可证批量核验。
3. H5 严格 CSP、依赖锁定与 WebCrypto 包装密钥发布前检查报告。

## 5. 历史证据入口

- N7：`docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`
- U7：`docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md`
- 产品契约：`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
