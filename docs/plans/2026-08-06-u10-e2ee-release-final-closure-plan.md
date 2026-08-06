---
title: "security: U10 E2EE 发布最终收口计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
status: active
current_unit: C1
current_checkpoint: C1-owned-draft-recovery
verdict: no-go
supersedes: docs/plans/2026-08-06-u10-e2ee-f62-remediation-final-plan.md
---

# security: U10 E2EE 发布最终收口计划

## 1. Goal Capsule

在不重做已完成 E2EE 产品能力、不改变服务端契约、不触碰 `im-test-1` 旧主数据面的
前提下，关闭 Release owned draft 自动恢复的唯一剩余 P1，重建并冻结发布候选，完成
四视角独立复审、干净基线与 live 重放，形成 U10 最终 Go/No-Go 裁决。

本文是 U10 E2EE 当前唯一任务派发、状态恢复和最终收口入口。旧计划与 review 仅作
历史证据，不再承担当前状态管理。

**Product Contract preservation：** 产品范围不变；本文仅收敛剩余发布门禁、执行顺序
和恢复点。

## 2. 边界与硬约束

- 生产 E2EE 保持 **No-Go**，直至 C1-C4 全部通过并形成最终裁决。
- `im-test-1` 旧主保持 `persist/plaintext`；禁止停止、升级或写入旧主数据库。
- 不重做 N1-N7、U1-U7、F1-F6.1 及已经验收的三端 E2EE 产品能力。
- 不扩展服务端 E2EE API，不修改已有 migration，不覆盖远端 `.env`。
- Android 测试固定使用 JDK21。
- 代码、workflow、测试门禁或依赖变化后，已有候选与其 evidence 立即失效；纯状态文档
  和 review 索引不改变候选身份。
- 每个实施单元开始和提交前检查 `git status --short`；只 stage 本单元文件，使用
  Conventional Commits，提交后立即 push。

## 3. 当前事实总账

| 范围 | 状态 | 决定性证据 |
| --- | --- | --- |
| N1-N7 / U1-U7 产品能力 | complete | 原生双端、H5、API、Admin gate、群聊、多设备、附件与跨端 live 历史 plan/review |
| F6.2 原 5 个 P1 整改 | complete | `77ba25ce`、`9e75a89d`、`9c02867b`、`e4128ee9` 及对应测试与环境证据 |
| H5 sidecar 路径修复 | complete | `184603c5`；sidecar 条目使用 basename |
| 四类 provenance 持久验签 | complete | `af8a665f`；H5、Android、API x86_64、API arm64 统一 manifest 与密码学 verifier |
| 最终实现候选 | invalid | `a0b90719976f1847feeb54a2c5a857dbc09b53fe`；第三轮 reliability P1 未关闭 |
| Release workflow | complete/invalidated | run `31115034686` 成功，四类资产通过，signing/publish skipped，tag/Release 零副作用 |
| 持久 provenance evidence | complete/invalidated | `63b78a02` 固化四类 evidence；可验证旧候选，但不能替代 C1 后的新候选 evidence |
| 第三轮独立复审 | fail | `docs/reviews/2026-08-06-u10-e2ee-r4-third-independent-review.md`；仅 reliability 有 1 个 P1 |
| 当前未关闭项 | 1 个 P1 | owned draft 删除瞬时失败后，同 tag、同 candidate 的后续执行被既存 Release 永久阻断 |
| 当前恢复点 | C1 | 修复 `scripts/release/create-github-release.sh` 并补跨执行恢复测试 |

run `31114473217` 仅在 GitHub 下载 action metadata 时遇到 `500/503`，仓库代码未执行且
无 tag/Release 副作用；它不是实现失败证据，也不得 rerun 作为新候选证明。

## 4. 唯一剩余 Finding

### REL-P1-01：owned draft 无法跨执行自动恢复

当前 `scripts/release/create-github-release.sh` 在入口处把任意既存 Release 视为
immutable。若上传失败后的 cleanup 又因瞬时错误未能删除本次 owned draft，后续同 tag、
同 candidate 执行会在读取 marker 前退出，只能人工删除 draft。

修复必须同时满足：

- 已发布 Release 永远 immutable。
- foreign draft 永远 fail closed，不能删除。
- 不同 candidate 的 draft 永远 fail closed，不能删除。
- 同 tag、同 candidate 的 orphan owned draft 可由后续执行识别、删除并重建。
- owner/candidate marker 不能仅依赖会随 workflow run 改变的 token；稳定 candidate 身份
  与单次 transaction owner 的职责必须清晰分离。
- 删除使用有界重试；重试耗尽仍 fail closed，不覆盖原始失败原因或误发布。

## 5. Key Technical Decisions

### KTD-1：稳定归属与单次事务身份分离

- draft 的稳定恢复身份由 repository、release tag、candidate SHA 和固定 marker schema
  共同组成；单次 `run_id/run_attempt` owner token 仅用于审计，不作为跨执行恢复条件。
- 恢复前必须通过 GitHub API 同时验证 `isDraft=true`、tag、target candidate 和完整 marker；
  任一字段缺失或不一致均视为 foreign draft 并 fail closed。
- 此协议防止误删、陈旧执行和不同候选互相清理，不宣称抵抗已拥有仓库 `contents:write`
  权限的恶意主体伪造 marker；该威胁由 GitHub environment、最小权限和审计边界控制。
- 脚本脱离 GitHub Actions 运行时，必须显式提供 repository、candidate 和 transaction
  owner，缺失上下文不得进入恢复分支。

### KTD-2：同 tag 发布事务串行化

- `.github/workflows/release-artifacts.yml` 继续以 release tag 作为 concurrency key，
  `cancel-in-progress: false`，确保同 tag workflow 不并发执行，也不在 cleanup 中途被新 run
  取消。
- 脚本仍需处理 API 状态在 `view -> delete` 之间变化的 TOCTOU：删除前重新读取并校验
  draft identity；状态变化或删除冲突均 fail closed。
- 脱离 workflow 的直接脚本调用不具备 concurrency 保证，只允许测试夹具或人工单实例
  恢复，不作为正式发布入口。

### KTD-3：真实 GitHub API 只在隔离环境 rehearsal

- `publish_release=false` 的正式候选 run 继续保持零发布副作用，不承担 Release 脚本 live
  证明。
- owned draft 恢复必须额外在 repository-owned 专用测试仓库或等价隔离 GitHub 环境，
  使用一次性 tag、fixture assets 和最小权限 token 完成真实 API rehearsal。
- rehearsal 必须覆盖 draft 创建、注入 cleanup delete 失败、后续同 candidate 恢复、重新
  发布及最终删除 tag/Release；清理失败即阻断 C2，禁止改用正式 tag/Release 验证。
- 若当前没有可审计的隔离仓库或环境，C2 保持 blocked，生产 E2EE 继续 No-Go。

## 6. Implementation Units

### C1. owned draft 跨执行恢复

**目标：** 关闭 REL-P1-01，并保持现有发布不可变与 fail-closed 边界。

**主要文件：**

- `scripts/release/create-github-release.sh`
- `tests/scripts/test-release-reliability.sh`
- 受影响时同步 `.github/workflows/release-artifacts.yml`
- 受影响时同步 workflow contract 测试

实现必须遵守 KTD-1 与 KTD-2，不得仅以 candidate marker 替代归属校验，也不得假设
workflow concurrency 能覆盖脚本的所有直接调用。

**必须覆盖的测试流：**

1. 上传失败，首次 cleanup delete 失败，owned draft 保留。
2. 后续同 tag、同 candidate 执行识别该 draft，删除成功。
3. 重新 create、完整 upload、publish 成功。
4. 已发布 Release、foreign draft、不同 candidate draft 均不删除。
5. 删除重试耗尽时停止，不 create、不 upload、不 publish。
6. 正常首次发布、部分失败后即时清理、同 tag 正常重试继续通过。

**定向门禁：**

```bash
bash tests/scripts/test-release-reliability.sh
make supply-chain.workflow.test
make tests.tooling
git diff --check
git diff --cached --check
```

**退出条件：** 实现与正负测试通过；correctness、security、reliability 定向审查无
P0/P1，结果写入 `docs/reviews/`；最小闭环提交并 push。任何 workflow、脚本或测试门禁
变化都会使 `a0b90719` 及 run `31115034686` 正式失效。C3 仍负责对冻结候选和真实
evidence 做全局四视角复审，两次审查对象不同，不互相替代。

### C2. 新候选、全量回归与 Release evidence

**前置条件：** C1 已提交并 push，工作区干净且 `HEAD == origin/main`。

1. 使用 JDK21 执行 `make test.all`。
2. 按 KTD-3 在隔离 GitHub 环境执行真实 Release API rehearsal，并保存 run-scoped 证据；
   临时 tag/Release 未完整清理时停止。
3. 冻结正式仓库 tag/Release 前态和新的 `implementation_candidate_sha`。
4. 以 `publish_release=false` 触发全新 Release workflow；不 rerun 旧 run。
5. 验证所有必需 jobs、四类 artifact、sidecar、bundle、trusted root 与 source commit。
6. 验证 Android signing 和 Publish skipped，正式仓库 tag/Release 前后逐字节一致。
7. 更新 `docs/reviews/evidence/u10-e2ee/` 的机器 evidence。
8. 执行 `make e2ee.evidence.verify e2ee.evidence.test`，提交 evidence 并 push。

**退出条件：** 隔离 rehearsal 证明真实 API 恢复链路且临时资源清零；正式候选 run
成功，四类 provenance 可从干净 checkout 密码学验签并保持零发布副作用；候选 SHA、
run ID 与 evidence commit 已固化。

### C3. 第四轮四视角独立复审

对 C2 冻结候选启动 correctness、security、reliability、testing 四个全新独立上下文。
审查必须覆盖 C1 的跨执行恢复、C2 的真实 workflow/evidence 以及既有生产 environment
边界。结果持久化到 `docs/reviews/`。

**退出条件：** 去重结果为 `P0=0/P1=0`。发现 P0/P1 时候选失效，并回到最早受影响
单元；不得带 finding 进入 C4。

### C4. 干净基线、live 重放与最终裁决

**前置条件：** C3 通过。

- 从 C2 evidence commit 的干净 checkout 执行完整 Verification Contract；机器 evidence
  及 verifier 必须绑定 C2 的 `implementation_candidate_sha`，不得把后续纯 evidence/doc
  commit 当作新的实现候选。
- 执行 `make test.live`，保存真实后端联调结果与临时资源清理证据。
- 对 `im-test-1` 仅做只读状态核对，确认旧主仍为 `persist/plaintext`。
- 更新最终 review、本计划恢复快照和 `docs/reports/task-list.md`。
- 明确记录 Go/No-Go；任何门禁失败均保持 No-Go 并给出最早恢复点。

**退出条件：** Verification Contract、live、持久 evidence、资源清理与旧主只读核对均
通过，最终文档与任务总账一致。

## 7. Verification Contract

| Gate | 命令或证据 | 通过条件 |
| --- | --- | --- |
| Release reliability | `bash tests/scripts/test-release-reliability.sh` | owned orphan 恢复及所有 immutable/foreign 负例通过 |
| Tooling / workflow | `make supply-chain.workflow.test supply-chain.check supply-chain.test tests.tooling` | 发布边界、contract 和供应链报告完整 |
| Evidence | `make e2ee.evidence.verify e2ee.evidence.test` | 四类 provenance 密码学验签及篡改负例通过 |
| H5 | `make h5-app.check h5-app.release.test` | check、unit、build 与 candidate security 通过 |
| Android | JDK21 `make android-app.test` | JVM、lint、构建与 signing 边界通过 |
| iOS / API / Core | `make ios-app.test api.test e2ee-core.check e2ee-core.check.targets` | 各模块门禁通过 |
| Full | JDK21 `make test.all` | 自包含全量回归通过 |
| GitHub | 全新 Release run、四类 attestation、tag/Release 差分 | 同候选、必需 jobs 成功、零发布副作用 |
| Release rehearsal | 隔离仓库/环境的真实 GitHub API 证据 | orphan draft 恢复成功，临时 tag/Release 全部清理 |
| Independent review | 四个全新独立上下文 | 去重 `P0=0/P1=0` |
| Live / environment | `make test.live`、run-scoped cleanup、旧主只读核对 | 联调通过、临时资源清零、旧主未变化 |

Android JDK：

```bash
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home
```

## 8. 风险与停止条件

- **误删 Release：** 仅凭 tag 或易变 run owner 判断归属会误删 foreign draft。必须同时
  校验 draft 状态、稳定 candidate marker 与预期发布身份。
- **并发执行：** 两次同 candidate 执行可能竞争恢复同一 draft。删除失败、状态变化或
  marker 不一致时立即 fail closed，不把并发冲突解释为成功；正式 workflow 另以同 tag
  concurrency group 串行化。
- **证据漂移：** C1 后继续复用旧 run/evidence 会把旧实现证明冒充新候选证明。C2 必须
  全新 run、全新 bundles、全新 evidence。
- **外部故障：** GitHub 基础设施失败不放宽门禁；确认无副作用后只能触发全新 run。
- **环境污染：** live 临时资源未清理或旧主状态无法只读确认时，保持 No-Go。
- **rehearsal 资源：** 缺少专用隔离仓库/环境时不得用正式 Release 代替，C2 直接阻断。

## 9. Definition of Done

- D1. REL-P1-01 有实现、正负测试、独立审查和提交证据。
- D2. 同 tag、同 candidate 可从 cleanup delete 瞬时失败中自动恢复。
- D3. foreign draft、不同 candidate draft 与已发布 Release 始终不可被删除。
- D4. 新候选通过 JDK21 全量回归和全新 `publish_release=false` workflow。
- D5. 隔离环境真实 GitHub API rehearsal 通过，临时 tag/Release 完整清理。
- D6. 四类 provenance 与 source commit 一致，可从干净 checkout 密码学验签。
- D7. 第四轮四视角独立复审为 `P0=0/P1=0`。
- D8. 干净基线、`make test.live`、资源清理和旧主只读核对全部通过。
- D9. 最终 review、active plan 与任务总账状态一致。
- D10. `im-test-1` 旧主全过程保持 `persist/plaintext`，未被停止、升级或写入。

## 10. 恢复快照

| Field | Value |
| --- | --- |
| Active unit | C1 |
| Active checkpoint | `C1-owned-draft-recovery` |
| Open blockers | `REL-P1-01`，共 1 个 P1 |
| Invalid implementation candidate | `a0b90719976f1847feeb54a2c5a857dbc09b53fe` |
| Invalidated successful run | `31115034686`；成功但仅证明 C1 修复前实现 |
| Last evidence commit | `63b78a02d82ad03ab3ca419fc901509e128ef22d` |
| Completed | N1-N7、U1-U7、原 F6.2 五项整改、H5 sidecar、四类 provenance、R4 真实 run/evidence |
| Earliest resume action | 检查 `git status --short`，实施 C1 并补跨执行恢复测试 |
| Final verdict | No-Go |
