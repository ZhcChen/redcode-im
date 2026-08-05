---
title: "security: U10 E2EE G3-G4 最终收口执行计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: active
current_unit: G4
current_checkpoint: G4.1
verdict: no-go
last_progress_update: 2026-08-06
supersedes: docs/plans/2026-08-06-u10-e2ee-release-gate-final-plan.md
---

# security: U10 E2EE G3-G4 最终收口执行计划

## 1. 唯一执行结论

本文是 U10 E2EE 剩余工作的**唯一 active 计划、进度总账和会话恢复入口**。
此前计划仅保留产品契约、实现过程与验收证据，不再派发任务。

- 唯一剩余链路：`G4.1 -> G4.2 -> G4.3`。
- 当前 checkpoint：`G4.1`，独立复审 G1-G3 并确认无未关闭 P0/P1。
- 当前裁决：生产 E2EE 保持 **No-Go**。
- 当前运行边界：保持 `content_audit_mode=plaintext`、`persist/plaintext` 和
  `security_review_approved=false`。
- 禁止扩展 E2EE API、修改已有 migration、触碰 `im-test-1` 旧主数据库，或把
  dev server 结果冒充真实候选部署证据。

## 2. 已完成事实

以下范围已经完成并推送，后续只在 G4 从干净基线重放门禁，禁止重做实现：

| 范围 | 状态 | 权威证据 |
| --- | --- | --- |
| N1-N7 原生双端接入与三端 E2EE live | 完成 | `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` |
| U7 P0-1 客户端主链 | 关闭 | 三端互解、附件、恢复、rekey、撤销与泄漏检查 |
| G1 / U7 P0-2 备份、灰度与回滚 | 关闭 | `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md` |
| G2 / U7 P0-3 六端供应链门禁 | 关闭 | `docs/reviews/2026-08-06-u10-e2ee-supply-chain-review.md` |
| G3.1 H5 静态发布安全门禁 | 完成 | `docs/reviews/2026-08-06-u10-e2ee-h5-release-g3-1.md` |
| G3.2-G3.3 / U7 P0-4 H5 真实发布安全 | 关闭 | `docs/reviews/2026-08-06-u10-e2ee-h5-release-security-review.md` |

G3.1 实现 commit 为 `cf05af8a`，文档 commit 为 `4a06f61b`。H5 type-check、
262 项 unit、release 正负场景、严格 CSP、11 个资源摘要和 9 个实际响应头均已
通过；独立复审为 P0=0、P1=0。

## 3. 当前恢复点

G3 已完成并推送，禁止重复部署或重做实现。最终候选 commit 为 `a22b65e2`，
manifest SHA-256 为
`393d9efdac67e206728cea79cb33929848d6ef5e776b5faeb054e89aaa70c8a2`；
21 个 release 场景、262 项 unit、真实 Chrome/Caddy 审计和四视角复审均通过。

候选 Caddy route、远端目录、backup、临时配置与浏览器 context 已清理，公开
runtime 为 `persist/plaintext`。后续从 `G4.1` 恢复，不再打开 G3 候选窗口，除非
G4 发现可定位到 G3 的阻断性回归。

## 4. 已关闭 G3

### G3.2a Path-prefix 候选支持（完成）

`da11a6c2` 完成 path-prefix 构建、manifest、server 和负向门禁；`fb88ee9b`
修复 Vue Router base。独立复审发现的点路径段、双向 base 绑定与静态资源 404
缺口由 `87f6c5e5` 关闭，21 个 release 场景通过。

### G3.2b 真实 HTTPS 与浏览器安全验收（完成）

`87f6c5e5` 建立受控 Caddy 候选窗口、远端逐文件摘要、真实 Chrome audit 与失败
自动清理；`a22b65e2` 扩展为全部公开资源/deep-link/404 的 9 项响应头、bytes、
SHA-256 和全 IndexedDB store 扫描。最终候选、故意失败恢复和 SSH 中断恢复均
通过，环境已恢复 `persist/plaintext`。

### G3.3 关闭 U7 P0-4（完成）

正式证据见 `docs/reviews/2026-08-06-u10-e2ee-h5-release-security-review.md`。
四视角复审 P0=0、P1=0、P2=0，U7 P0-4 已关闭。

## 5. 剩余执行队列

### G4.1 独立复审

分别从 correctness、security、reliability、testing 四个视角复审 G1-G3。报告必须
给出可定位证据；发现 P0/P1 时回到最早失败 checkpoint 修复并重新验收，不进入
G4.2。

### G4.2 干净基线全量重放

在无未提交源码改动的基线上依次执行：

```bash
make supply-chain.check
make api.test
make e2ee-core.check
make e2ee-core.check.targets
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make android-app.test
make ios-app.test
make h5-app.check
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.all
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.live
```

结束后清理临时账号、容器、volume、浏览器 profile、候选静态目录、临时报告和
凭据；复核测试环境 runtime 回到 `persist/plaintext`。任何失败均保持 No-Go。

### G4.3 最终裁决

同步 U7 review、`docs/reports/task-list.md` 和本文，记录全部 P0、P1、门禁、环境
清理及 CI 状态。只有所有 DoD 均满足才可裁决 Go，否则明确保持 No-Go 并留下唯一
下一 checkpoint。最终文档使用独立 commit 并立即 push。

## 6. 停止与降级规则

- G3 任一静态、部署、浏览器或 fail-closed 验收失败：停在对应 checkpoint。
- 需要扩展服务端契约：返回产品契约计划评估，不在本计划直接修改 API。
- CRG、浏览器工具或 CI 不可用：降级到源码、`rg`、测试和运行时证据，但不得把
  缺失证据标记为通过。
- G4 存在未关闭 P0/P1、全量/live 失败或清理不完整：保持 No-Go。
- 测试候选窗口结束后必须恢复 `persist/plaintext` 和
  `security_review_approved=false`，无例外。

## 7. Definition of Done

- D1. 本文是唯一 active U10 计划，任务总账与 `current_checkpoint` 一致。
- D2. G3.2a path-prefix 候选支持已测试、独立提交并 push。
- D3. G3.2b 真实 HTTPS、响应头、浏览器存储和 fail-closed 验收全部通过且已清理。
- D4. U7 P0-4 有独立可复现报告并关闭。
- D5. G4 独立复审无未解决 P0/P1。
- D6. 干净基线全量与 live 门禁通过，临时资源和凭据已清理。
- D7. runtime 保持 `persist/plaintext`，`im-test-1` 旧主数据库未触碰。
- D8. 所有 checkpoint 均按最小闭环提交并 push；仅 D1-D7 全部满足才允许 Go。

## 8. 文档边界

| 文档 | 状态 | 用途 |
| --- | --- | --- |
| `2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | superseded | 产品契约与 API 边界 |
| `2026-08-05-u10-e2ee-native-clients-plan.md` 及收口计划 | complete/superseded | N1-N7 与原生验收历史 |
| `2026-08-06-u10-e2ee-release-gate-final-plan.md` | superseded | G2、G3.1 完成事实与设计历史 |
| 本文 | active | 唯一剩余任务派发、进度与恢复入口 |
