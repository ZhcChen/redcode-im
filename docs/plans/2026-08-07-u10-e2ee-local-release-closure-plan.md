---
title: "security: U10 E2EE 本地发布收口计划"
date: 2026-08-07
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
status: active
current_unit: L1
current_checkpoint: L1-disable-github-actions
verdict: no-go
supersedes: docs/plans/2026-08-07-u10-e2ee-release-closure-resume-plan.md
---

# security: U10 E2EE 本地发布收口计划

## 1. 目标与决策

本文是 U10 E2EE 发布收口的唯一 active 计划。根据 2026-08-07 决策，仓库暂时禁用
全部 GitHub Actions，不再依赖 GitHub runner、artifact、attestation 或 Release workflow
完成构建与验收。原 C2 GitHub Actions 恢复路径停止执行。

剩余工作改为：`L1 禁用 Actions -> L2 本地候选与机器证据 -> L3 四视角复审 ->
L4 干净基线/live/最终裁决`。

**Product Contract preservation：** E2EE 产品能力和安全边界不变；仅替换构建与证据
生产方式。GitHub keyless attestation 暂时不可用不等于门禁通过，必须由本地可复跑证据
明确记录该差异。

## 2. 不可变边界

- 生产 E2EE 保持 **No-Go**，直至 L1-L4 全部通过并形成最终裁决。
- `im-test-1` 旧主保持 `persist/plaintext`；禁止停止、升级或写入旧主数据库。
- `.github/workflows/*.yml` 必须保持全文件注释；本地测试应 fail closed 检测任何恢复行。
- 不创建 GitHub Actions run，不上传 GitHub artifact，不创建正式 tag/Release。
- 不把本地 checksum 或自签名材料冒充 GitHub/Sigstore keyless provenance。
- Android 固定 JDK21；不扩展 E2EE API，不修改已有 migration，不覆盖远端 `.env`。
- 每单元开始及提交前检查 `git status --short`；最小闭环提交后立即 push。

## 3. 已完成基线与失效项

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| N1-N7、U1-U7、F1-F6.2、C1 | complete | 产品能力、历史整改和 owned draft 恢复不重做 |
| `6a1585dd...` | invalidated | Actions 配置和本地合同变化后不再是当前候选 |
| run `31115034686` | historical | 只证明旧候选，不作为本地新候选证据 |
| run `31120768166` / `31121705433` | historical-infrastructure-failure | 禁止 rerun；本计划不再等待 Actions |
| 历史四类 GitHub provenance | historical | 保留审计，不替代新候选的本地证据 |

## 4. Implementation Units

### L1. 禁用 GitHub Actions 并保留可恢复合同

1. 对 `.github/workflows/release-artifacts.yml` 和 `supply-chain.yml` 全文件逐行注释。
2. 本地 workflow contract 测试必须先断言每一行均为注释，再在内存中恢复 YAML 并执行
   原有权限、依赖、签名、Release fail-closed 合同检查。
3. 确认 GitHub 无可触发的 `on:` 配置，仓库内仍可审查和恢复原定义。

验证：

```bash
make supply-chain.workflow.test
make tests.tooling
git diff --check
git diff --cached --check
```

**退出条件：** 两个 workflow 全文件注释；本地合同测试通过；提交并 push。

### L2. 本地候选构建与机器证据

1. 以 L1 提交后的干净 checkout 冻结新的 `implementation_candidate_sha`。
2. 使用 JDK21 执行 `make test.all` 和完整 Verification Contract。
3. 在干净 worktree 本地构建并保存：Android unsigned APK、iOS Simulator build、H5
   production archive、API linux/amd64 与 linux/arm64 image/binary archive。
4. 运行六端供应链扫描，保存 SBOM、policy report 和 summary。
5. 为每项资产生成 SHA-256；生成 machine manifest，绑定候选 SHA、git tree、构建命令、
   工具版本、平台、开始/结束时间、资产路径与摘要。
6. 增加本地 verifier 和篡改负例；禁止把无可信身份签名的 manifest 标为 SLSA provenance。
7. 验证 GitHub tag/Release 前后不变，`.github/workflows` 仍全部注释。

**退出条件：** 五类本地资产、SBOM、manifest、checksum 和 verifier 可从干净 checkout
复跑；篡改负例 fail closed；候选 SHA 与证据已固化。

### L3. 四视角独立复审

对 L2 evidence commit 使用 correctness、security、reliability、testing 四个全新独立
上下文，重点审查本地构建隔离、候选绑定、checksum/SBOM 完整性、GitHub provenance
缺失的残余风险和 fail-closed 边界。

**退出条件：** 去重后 `P0=0/P1=0`。发现 P0/P1 时回到最早受影响单元，不得进入 L4。

### L4. 干净基线、live 与最终裁决

1. 从 L2 evidence commit 的干净 checkout 重放 Verification Contract 和本地 verifier。
2. 执行 `make test.live`，保存 run-scoped 资源与清理证据。
3. 对 `im-test-1` 只读核对，确认旧主仍为 `persist/plaintext`。
4. 更新最终 review、本文与 `docs/reports/task-list.md`，形成 Go/No-Go。

**退出条件：** 本地全量、五类构建、供应链、证据 verifier、live、资源清理和旧主只读
核对全部通过。若可信发布签名或 provenance 仍缺失，最终裁决必须明确保留对应 No-Go，
不得以本地 checksum 替代身份真实性证明。

## 5. Verification Contract

| Gate | 命令或证据 | 通过条件 |
| --- | --- | --- |
| Actions disabled | `make supply-chain.workflow.test` | 所有 workflow 全文件注释，保留合同可解析 |
| Supply chain | `make supply-chain.check supply-chain.test` | 六端 SBOM/report 完整且无 blocking finding |
| Tooling | `make tests.tooling` | 本地发布与 fail-closed 契约通过 |
| H5 | `make h5-app.check h5-app.release.test` | 类型、单测、release security 通过 |
| Android | JDK21 `make android-app.test` | JVM、lint、build 通过 |
| iOS/API/Core | `make ios-app.test api.test e2ee-core.check e2ee-core.check.targets` | 模块门禁通过 |
| Full | JDK21 `make test.all` | 自包含全量回归通过 |
| Local artifacts | L2 manifest + verifier | 五类资产、命令、环境与 SHA-256 绑定同一候选 |
| Review | 四个全新独立上下文 | 去重 `P0=0/P1=0` |
| Live/environment | `make test.live`、资源清理、旧主只读核对 | 联调通过、资源清零、旧主未变化 |

JDK21：

```text
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home
```

## 6. Definition of Done

- D1. GitHub Actions 全部注释且本地 fail-closed 合同测试通过。
- D2. 新候选通过本地全量测试和五类构建。
- D3. SBOM、checksum、machine manifest 与候选 SHA 一致，verifier 和篡改负例通过。
- D4. 正式 tag/Release 零变化，GitHub Actions 未参与构建或证据生产。
- D5. L3 四视角结果为 `P0=0/P1=0`。
- D6. L4 live、资源清理和旧主只读核对通过。
- D7. 最终文档明确区分完整性证据与发布身份/provenance，给出真实 Go/No-Go。

## 7. 恢复快照

| Field | Value |
| --- | --- |
| Active unit | L1 |
| Active checkpoint | `L1-disable-github-actions` |
| Previous candidate | `6a1585ddb68b1947fc5d6e34c7df680c1b322fd2`，invalidated |
| Candidate | 待 L1 提交后冻结 |
| GitHub Actions | 全部注释，不再作为依赖 |
| Earliest action | 完成 L1 本地门禁、提交并 push |
| Final verdict | No-Go |
