---
title: "security: U10 E2EE 发布收口恢复执行计划"
date: 2026-08-07
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
status: superseded
current_unit: C2
current_checkpoint: C2.1-wait-github-actions-recovery
verdict: no-go
supersedes: docs/plans/2026-08-06-u10-e2ee-release-final-closure-plan.md
superseded_by: docs/plans/2026-08-07-u10-e2ee-local-release-closure-plan.md
---

# security: U10 E2EE 发布收口恢复执行计划

## 1. 目标与定位

本文已由 `docs/plans/2026-08-07-u10-e2ee-local-release-closure-plan.md` 取代。GitHub
Actions 已按决策暂时全部注释，本文件仅保留为历史恢复记录，不再派发 C2-C4。

目标是在不改变产品范围、不扩展服务端契约、不触碰 `im-test-1` 旧主数据面的前提下，
为实现候选 `6a1585ddb68b1947fc5d6e34c7df680c1b322fd2` 重建 Release evidence，完成
四视角复审、干净基线与 live 重放，并形成最终 Go/No-Go 裁决。

**Product Contract preservation：** 产品契约不变；本次仅重组剩余发布门禁和恢复步骤。

## 2. 不可变边界

- 生产 E2EE 始终保持 **No-Go**，直至 C2-C4 全部通过并形成最终裁决。
- `im-test-1` 旧主始终保持 `persist/plaintext`；禁止停止、升级或写入旧主数据库。
- 不重做已完成的产品能力，不扩展 E2EE API，不修改已有 migration，不覆盖远端 `.env`。
- Android 测试固定使用 JDK21。
- GitHub 外部故障不得放宽门禁；失败 run 不得 rerun，只能确认零副作用后触发全新 run。
- 每单元开始及提交前执行 `git status --short`；只提交本单元文件，commit 后立即 push。

## 3. 当前进度快照

### 3.1 已完成，不再重做

| 范围 | 状态 | 决定性证据 |
| --- | --- | --- |
| N1-N7、U1-U7 | complete | 原生双端、H5、API、Admin gate、多设备、群聊、附件和三端 live 历史验收 |
| F1-F6.2 | complete | 历史整改、供应链门禁和 provenance 实现提交 |
| C1 owned draft 恢复 | complete | `6a1585dd`；`docs/reviews/2026-08-07-u10-e2ee-c1-owned-draft-recovery.md` |
| C1 定向复审 | complete | correctness/security/reliability 均 `P0=0/P1=0` |
| C2 JDK21 全量回归 | complete | `make test.all` 返回 `0`，候选为 `6a1585dd...` |
| C2 隔离 API rehearsal | complete | orphan draft 恢复、stale ETag fail closed、临时 tag/Release 清零 |

### 3.2 当前阻塞与无效证据

| 项目 | 状态 | 处理规则 |
| --- | --- | --- |
| GitHub Actions | external-blocked | 官方状态仍为 `major_outage`；恢复前不触发新 run |
| run `31120768166` | infrastructure-failure | 未分配 runner，`steps=[]`；禁止 rerun |
| run `31121705433` | infrastructure-failure | 仅 `Set up job` 失败；禁止 rerun |
| candidate `a0b90719...` | invalid | C1 前候选，不得复用其 run/evidence |
| run `31115034686` | invalidated | 仅证明 C1 前实现，不得作为最终 evidence |
| 恢复点提交 `3b786175...` | docs-only | 仅记录 Actions 中断，不是 implementation candidate |

两次 infrastructure failure 后，正式仓库 tag/Release 与冻结前态逐字节一致。生产结论
仍为 **No-Go**，当前唯一 checkpoint 是 `C2.1-wait-github-actions-recovery`。

## 4. 候选身份规则

实现候选固定为：

```text
6a1585ddb68b1947fc5d6e34c7df680c1b322fd2
```

- 后续纯文档/evidence commit 不改变 implementation candidate。
- Release workflow 的 `headSha`、artifact 文件名、attestation subject 和 evidence manifest
  必须绑定上述完整 SHA。
- workflow dispatch 的 `ref` 应使用临时受控远端分支，例如
  `u10-c2-candidate-6a1585dd`，且该分支必须精确指向候选 SHA。
- 临时分支只用于 GitHub Actions 定位候选，不得合并、不得创建正式 release tag；C2
  evidence 固化后删除远端分支，并记录创建、SHA 校验和删除证据。
- 若远端策略禁止创建临时分支，C2 保持 blocked；不得改写历史或把 docs-only HEAD
  冒充实现候选。

## 5. 剩余实施单元

### C2. 候选 workflow 与四类 Release evidence

#### C2.1 等待外部恢复

每次恢复前先执行：

```bash
git status --short
curl -fsSL https://www.githubstatus.com/api/v2/components.json \
  | jq -r '.components[] | select(.name=="Actions") | [.status,.updated_at] | @tsv'
```

仅当 Actions 不再是 `major_outage`/`partial_outage` 且新任务可正常获得 runner 时进入
C2.2。不得用重复触发来探测恢复状态。

#### C2.2 固定候选并触发全新 run

1. 复核候选 commit、workflow 文件和正式 tag/Release 冻结前态。
2. 创建临时受控远端分支，使其精确指向 `6a1585dd...`；push 后通过 GitHub API 再校验 SHA。
3. 使用该分支触发全新 `release-artifacts.yml`，输入 `publish_release=false`。
4. 记录新 run ID、`headSha`、event、ref、所有 job/step 状态。
5. 若失败，先确认正式 tag/Release 零副作用；不得 rerun，按最早失败阶段决定是否另开 run。

受控 ref 操作基线：

```bash
candidate=6a1585ddb68b1947fc5d6e34c7df680c1b322fd2
candidate_ref=u10-c2-candidate-6a1585dd
git push origin "${candidate}:refs/heads/${candidate_ref}"
gh api "repos/{owner}/{repo}/git/ref/heads/${candidate_ref}" --jq '.object.sha'
gh workflow run release-artifacts.yml --ref "${candidate_ref}" -f publish_release=false
```

API 返回 SHA 不等于 `$candidate` 时禁止触发 workflow。

#### C2.3 固化和验证 evidence

1. 下载 H5、Android、API x86_64、API arm64 四类 artifacts。
2. 下载四类 provenance bundles 和 trusted root，生成新的 raw workflow JSON 与 manifest。
3. 验证 source commit、subject digest、artifact digest、workflow identity 和 issuer。
4. 验证 Android signing 与 Publish jobs 均 skipped。
5. 验证正式 tag/Release 与 C2.2 前态逐字节一致。
6. 更新 `docs/reviews/evidence/u10-e2ee/`，执行：

```bash
make e2ee.evidence.verify e2ee.evidence.test
```

7. 提交并 push evidence 后执行 `git push origin --delete u10-c2-candidate-6a1585dd`，通过
   GitHub API 确认 ref 已不存在，再确认正式 tag/Release 未变化。

**C2 退出条件：** 新 run 成功；四类 provenance 可密码学验签；所有 evidence 绑定
`6a1585dd...`；sign/publish skipped；临时分支已删除；正式 tag/Release 零副作用。

### C3. 第四轮四视角独立复审

使用四个全新独立上下文审查 C2 evidence commit：

| Lens | 必查范围 |
| --- | --- |
| correctness | 候选身份、artifact/bundle 对应关系、恢复和回退状态机 |
| security | provenance 信任根、workflow 权限、Release immutable/fail-closed 边界 |
| reliability | 外部失败恢复、owned draft、并发、临时 ref 和资源清理 |
| testing | 正负例、篡改检测、跨平台矩阵、live 验收覆盖 |

结果写入新的 `docs/reviews/` 文档并去重。仅当 `P0=0/P1=0` 才能进入 C4；发现 P0/P1
时，候选或 evidence 按影响范围失效并回到最早受影响单元。

### C4. 干净基线、live 重放与最终裁决

1. 从 C2 evidence commit 创建干净 checkout，确认 verifier 仍绑定实现候选 `6a1585dd...`。
2. 按 Verification Contract 重放全部本地门禁，Android 使用 JDK21。
3. 执行 `make test.live`，保存真实后端联调、run-scoped 资源和清理证据。
4. 对 `im-test-1` 仅做只读核对，确认旧主仍为 `persist/plaintext` 且未被停止、升级或写入。
5. 更新最终 review、本文状态和 `docs/reports/task-list.md`，明确最终 Go/No-Go。

**C4 退出条件：** 全部门禁与 live 通过；临时资源清零；旧主只读核对通过；最终 review、
active plan 和任务总账结论一致。

## 6. Verification Contract

| Gate | 命令或证据 | 通过条件 |
| --- | --- | --- |
| Reliability | `bash tests/scripts/test-release-reliability.sh` | orphan 恢复及 immutable/foreign 负例通过 |
| Supply chain | `make supply-chain.workflow.test supply-chain.check supply-chain.test tests.tooling` | workflow contract 与供应链报告完整 |
| Evidence | `make e2ee.evidence.verify e2ee.evidence.test` | 四类 provenance 验签和篡改负例通过 |
| H5 | `make h5-app.check h5-app.release.test` | check、unit、build、candidate security 通过 |
| Android | JDK21 `make android-app.test` | JVM、lint、build、signing 边界通过 |
| iOS/API/Core | `make ios-app.test api.test e2ee-core.check e2ee-core.check.targets` | 对应模块门禁通过 |
| Full | JDK21 `make test.all` | 自包含全量回归通过 |
| GitHub | 全新 run、四类 attestation、ref/tag/Release 差分 | 同候选、必需 jobs 成功、无发布副作用 |
| Review | 四个全新独立上下文 | 去重后 `P0=0/P1=0` |
| Live/environment | `make test.live`、资源清理、旧主只读核对 | 联调通过、资源清零、旧主未变化 |

JDK21：

```text
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home
```

## 7. 回退与停止规则

- workflow 未执行 checkout：记录 infrastructure failure，确认零副作用后停在 C2.2。
- workflow 执行仓库步骤后失败：先完成 tag/Release 与临时资源审计，再定位最早失败 gate。
- 候选 SHA 不一致、provenance 无法验签或 Publish 非预期执行：立即 fail closed，C2 不通过。
- C3 出现 P0/P1：回到最早受影响单元；代码/workflow 变化时重新冻结 implementation candidate。
- C4 本地或 live 失败：保持 No-Go，保留最小复现证据，不进入最终发布切换。
- `im-test-1` 无法只读确认或发现状态变化：立即停止，禁止用写操作修复或验证。

## 8. Definition of Done

- D1. C2 新 run 和四类 evidence 全部绑定 `6a1585dd...`。
- D2. provenance 可从干净 checkout 密码学验签，篡改负例通过。
- D3. signing/publish skipped，正式 tag/Release 前后一致，临时分支与 rehearsal 资源清零。
- D4. C3 四视角去重结果为 `P0=0/P1=0`。
- D5. C4 Verification Contract 与 `make test.live` 通过。
- D6. `im-test-1` 旧主全过程保持 `persist/plaintext`，未停止、升级或写入。
- D7. 最终 review、active plan 与任务总账一致，并明确记录 Go/No-Go。

## 9. 恢复快照

| Field | Value |
| --- | --- |
| Active unit | C2 |
| Active checkpoint | `C2.1-wait-github-actions-recovery` |
| Implementation candidate | `6a1585ddb68b1947fc5d6e34c7df680c1b322fd2` |
| Resume-point docs commit | `3b7861756db724b967508cf21734e5c457681dd0` |
| External blocker | GitHub Actions `major_outage` |
| Forbidden reruns | `31120768166`、`31121705433` |
| Earliest resume action | 查询官方 Actions 状态；恢复后创建候选临时分支并触发全新 run |
| Final verdict | No-Go |
