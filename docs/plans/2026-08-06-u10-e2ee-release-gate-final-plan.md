---
title: "security: U10 E2EE 发布门禁最终执行计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code
status: active
current_unit: G2
current_checkpoint: G2.4
verdict: no-go
last_progress_update: 2026-08-06
supersedes: docs/plans/2026-08-05-u10-e2ee-release-readiness-execution-plan.md
---

# security: U10 E2EE 发布门禁最终执行计划

## 1. 执行结论

本文是 U10 E2EE 后续工作的**唯一 active 计划、进度总账和会话恢复点**。历史
U10/E2EE 计划只保留产品契约、实现过程和验收证据，不再派发任务。

- 固定顺序：`G2 供应链门禁 -> G3 H5 发布安全 -> G4 独立复审与裁决`。
- 当前 checkpoint：`G2.4`，接入 CI 与 release 阻断。
- 当前裁决：生产 E2EE 为 **No-Go**。
- 运行约束：保持 `content_audit_mode=plaintext`；测试候选环境结束后必须恢复
  `persist/plaintext` 和 `security_review_approved=false`。
- 范围约束：不扩展 E2EE API，不修改已有 migration，不触碰 `im-test-1` 旧主库。

## 2. 已完成基线

以下工作已经完成并推送，禁止重做：

| 范围 | 状态 | 关键证据 |
| --- | --- | --- |
| N1-N7 原生双端 E2EE 接入 | 完成 | `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` |
| 三端 live、附件、恢复、rekey、撤销与泄漏检查 | 完成 | `docs/plans/2026-08-05-u10-e2ee-native-clients-final-verification-plan.md` |
| U7 P0-1 客户端主链 | 关闭 | Android/iOS/H5 三端真实互解与全量门禁 |
| G1 / U7 P0-2 备份恢复与灰度回滚 | 关闭 | `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md` |
| API 风险依赖清理 | 完成 | `9e67ff9a`；API unit 188/188 与 integration 通过 |
| H5 风险依赖清理 | 完成 | `e3201bda`；type-check、262 tests 通过 |
| Admin 风险依赖与构建更新 | 完成 | `6cbf6e3e`；`pnpm build:check` 通过 |
| Android 发布工具链更新 | 完成 | `a0bde724`；JDK21 JVM tests 通过 |
| E2EE core 与 iOS 回归 | 完成 | core 四目标通过；iOS 242 tests、9 live skipped、0 failures |

已关闭单元只在 G4 从干净基线重放门禁，不再进入功能实现。

## 3. 当前工作区快照

`G2.2` 已完成以下实现，后续必须基于这些文件继续，不得重新生成平行方案：

- `Makefile`
- `config/supply-chain/policy.json`
- `config/supply-chain/exceptions.json`
- `scripts/supply-chain/check.sh`
- `scripts/supply-chain/evaluate.ts`
- `scripts/supply-chain/scan-swift.ts`

当前实现覆盖 API、e2ee-core、Android、iOS、H5、Admin 六端，固定使用
OSV-Scanner 2.2.4，并生成 `.artifacts/supply-chain/` 机器报告。Android 完整 lock
继续用于可复现构建，供应链扫描使用派生的 release runtime 依赖集合。

2026-08-06 已通过统一门禁：API 432、e2ee-core 193、Android 119、iOS 1、
H5 217、Admin 811 个组件；29 个精确限时例外，0 个阻断项。六份漏洞报告与
六份 CycloneDX SBOM 完整，敏感 marker 无命中；Admin `pnpm build:check` 通过。

## 4. 剩余执行队列

### G2.2 六端统一供应链门禁（完成）

**目标：** 完成锁定输入、CycloneDX SBOM、漏洞、许可证和限时豁免的统一
fail-closed 入口。

**完成证据：** `make supply-chain.check` 与 Admin `pnpm build:check` 通过；六端
机器报告完整且不含敏感 marker；Admin 旧 `postcss 8.4.49` 已统一到 8.5.25。

### G2.3 负向夹具与报告完整性（完成）

**目标：** 证明门禁会阻断，而不只是生成报告。

**文件：** `tests/scripts/test-supply-chain-check.sh`、
`tests/fixtures/supply-chain/`、必要的 `scripts/supply-chain/` 测试注入接口。

**必须覆盖：** 正常通过、known high/critical、unknown severity、reject license、
expired exception、missing owner、wildcard、unused exception、scanner unavailable、
数据库/下载失败、截断 JSON、缺失模块/报告、敏感 marker 泄漏。

**完成证据：** `make supply-chain.test` 的 16 个隔离场景全部通过；fixture 不依赖
真实网络、不调用 Docker daemon、不改写真实 lockfile，并已接入 `tests.tooling`。

### G2.4 CI 与 release 阻断

**目标：** PR 与 release workflow 调用同一个 `make supply-chain.check`，上传机器
报告，并让失败阻断 API、Android 和最终发布 job。

**文件：** `.github/workflows/supply-chain.yml`、
`.github/workflows/release-artifacts.yml`、必要的 `Makefile` 调整。

**完成条件：** workflow 语法通过；工具版本固定；报告缺失即失败；正常和负向
CI 证据可复现；独立 CI commit 已推送。

### G2.5 关闭 U7 P0-3

更新 SBOM 报告、供应链独立 review、U7 review、任务总账和本文 checkpoint。只有
G2.2-G2.4 全部通过才关闭 P0-3。完成后进入 `G3.1`，生产仍为 No-Go。

### G3 H5 发布安全

1. `G3.1`：对可追溯 production build 检查严格 CSP、安全响应头、公开 source map、
   静态资源与 commit/lockfile 绑定。
2. `G3.2`：在隔离浏览器会话验证 WebCrypto wrapping key 不可导出，存储、Network、
   Console 和日志无敏感数据；状态损坏、身份变化、未知 epoch 与解密失败均 fail closed。
3. `G3.3`：形成 H5 发布安全 review，关闭 U7 P0-4，并进入 `G4.1`。

不得通过加入不受控 `unsafe-inline`、`unsafe-eval` 或 plaintext fallback 通过验收。

### G4 独立复审与最终裁决

1. `G4.1`：独立 correctness/security/reliability/testing 复审 G1-G3，关闭全部 P0/P1。
2. `G4.2`：从干净基线重跑 core、API、Android、iOS、H5、供应链、`test.all` 和
   `test.live`，清理临时账号、容器、volume、浏览器 profile、报告与凭据。
3. `G4.3`：同步 U7 review、任务总账和本文，作出唯一 Go/No-Go 裁决。

任一 P0/P1、fail-closed 场景、全量门禁或环境清理未通过，最终裁决保持 No-Go。

## 5. 验收入口

| 范围 | 命令 |
| --- | --- |
| 供应链 | `make supply-chain.check` |
| 供应链负向 | `tests/scripts/test-supply-chain-check.sh` |
| API | `make api.test` |
| E2EE core | `make e2ee-core.check && make e2ee-core.check.targets` |
| Android | `JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make android-app.test` |
| iOS | `make ios-app.test` |
| H5 | `make h5-app.check` 及 G3 新增 release security 入口 |
| 全量 | JDK21 环境执行 `make test.all` |
| live | JDK21 环境执行 `make test.live`，结束后验证 runtime 恢复 |
| Git | `git diff --check`、`git diff --cached --check`、staged diff review |

每个 checkpoint 必须按“实现 -> 定向验证 -> 最小闭环 commit -> push -> 更新进度”
执行，不得跨 checkpoint 合并半成品。

## 6. Definition of Done

- D1. 本文保持唯一 active，任务总账与 `current_checkpoint` 一致。
- D2. 六端供应链正常和负向门禁在本地与 CI 使用同一入口并通过。
- D3. U7 P0-3、P0-4 均有独立、可复现的关闭证据。
- D4. H5 候选产物和浏览器运行时安全边界全部通过，不回退 plaintext。
- D5. G4 独立复审无未解决 P0/P1，全量与 live 门禁从干净基线通过。
- D6. 临时资源已清理，runtime 恢复 `persist/plaintext`，`im-test-1` 旧主未触碰。
- D7. 所有 checkpoint 均已按边界提交并推送。
- D8. 仅 D1-D7 全部满足时允许裁决 Go，否则保持明确的 No-Go 和下一 checkpoint。

## 7. 历史文档边界

| 文档 | 状态 | 后续用途 |
| --- | --- | --- |
| `2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | superseded | 产品契约与服务端边界 |
| `2026-08-05-u10-e2ee-native-clients-plan.md` 及 closure 系列 | superseded/complete | N1-N7 实现和验收证据 |
| `2026-08-05-u10-e2ee-release-readiness-execution-plan.md` | superseded | G1 与 G2 策略设计历史 |
| 本文 | active | 唯一任务派发与会话恢复入口 |
