---
title: "security: U10 E2EE 最终收口执行计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: active
current_unit: F5
current_checkpoint: F5.4
verdict: no-go
last_progress_update: 2026-08-06
supersedes: docs/plans/2026-08-06-u10-e2ee-remaining-closure-execution-plan.md
---

# security: U10 E2EE 最终收口执行计划

## Goal Capsule

- **目标：** 在不重做已关闭工作的前提下，修复真实 Release workflow 暴露的 CI 差异，完成独立复审、干净基线重放和最终 Go/No-Go 裁决。
- **唯一恢复点：** `F5.4`，从已 push 且工作区干净的修复候选 HEAD 冻结 tag/Release 前态，以 `publish_release=false` 触发全新 Release workflow。
- **固定顺序：** `F5.4 -> F6 -> F7`。除 CI 中互不依赖的观测外，不并行启动后续单元。
- **当前裁决：** 生产 E2EE 保持 **No-Go**；`im-test-1` 旧主保持 `persist/plaintext`，禁止停止、升级或写入旧主数据库。
- **唯一状态源：** 本文 frontmatter、执行看板和恢复快照。历史计划只提供设计与证据追溯，不再承载进度。

## 1. 整理结论

### 1.1 已完成，不重做

| 单元 | 状态 | 决定性证据 |
| --- | --- | --- |
| F1 Restore 三端 live 与数据边界 | complete | commit `d385c88b`；run `e1fix20260806g` |
| F2 Restore 四视角独立复核 | complete | subject `aa605931`；四视角 `P0=0/P1=0/P2=0` |
| F3 H5 production Chrome 审计 | complete | subject `f6944a70`；run `e3prod20260806f` |
| F4 持久脱敏证据 | complete | commit `a383f788`；离线验证与 13 类负例通过 |
| F5.1 Release 前态冻结与首次触发 | complete | subject `32d065af`；run `31061331555` 已触发 |
| F5.2 首次 run 取证与归因 | complete | run `31061331555` failure；H5/Android 两项根因；tag/Release 零副作用 |
| F5.3 CI 差异修复 | complete | commit `e652aaa1`；仓库变量、host cdylib 与 contract tests 已关闭 |

F1-F4 对应旧计划 E1-E4。它们只在后续回归或独立复审发现直接关联的 P0/P1 时，才回到最早受影响单元；不得因文档重排重新执行。

### 1.2 当前真实状态

- 候选分支为 `main`，触发时 `HEAD == origin/main == 32d065af1b5114a8bd61115df09574da7b8519f0`。
- workflow 为 `Build Release Artifacts`，event 为 `workflow_dispatch`，输入为 `publish_release=false`。
- `Validate release inputs` 与 `Supply-chain release gate` 已通过。
- `Build and attest H5 candidate` 已在 `Build and verify H5 candidate` 失败；package、attestation 与 upload 被正确阻断。
- `Build Android app (Kotlin/Compose)` 已在 `Run unit tests` 失败；lint、APK build 与 upload 被正确阻断。
- iOS 与 Desktop 依 workflow 条件跳过；API test 和 x86_64/arm64 image build 全部成功，Publish job 正确跳过。
- tag/Release 前后集合与摘要完全一致：17 个 tag、12 个 Release；tags SHA-256 为 `e023f4b370a568468175d424a832b14e99a2052f6eebc630a1df065961f08cb8`，Releases SHA-256 为 `b9b1303f61ac70002c80585c3b55fa3ab1d0e1c6f463b13b39f6233f52a8fe4f`。
- F5.3 已设置仓库变量 `H5_RELEASE_API_BASE_URL=https://im-test-1.codelib.cc` 与 `H5_RELEASE_WS_URL=wss://im-test-1.codelib.cc/ws`；workflow 在重依赖安装前 fail closed 校验变量。
- Android job 现先以 scanned `Cargo.lock` 执行 `cargo build --locked` 生成 Linux host cdylib，再通过 `E2EE_CORE_LIB_DIR` 运行 JNA 测试；contract test 锁定步骤顺序与路径。

## 2. 范围与约束

### Requirements

- R1. 获取首次真实 workflow 的完整 job、失败日志和最终 conclusion，不用局部成功替代整体结果。
- R2. H5 与 Android 修复必须针对真实 CI 差异，分别增加或收紧本地可复现门禁。
- R3. 新候选必须从已 push 且工作区干净的 HEAD 重新触发，禁止 rerun 旧失败 run 冒充新实现证据。
- R4. `publish_release=false` 的成功 run 不得新增或修改 tag/Release；artifact 与 attestation 必须绑定新候选 HEAD。
- R5. 最终四视角复审必须绑定同一候选 commit，且 `P0=0/P1=0`。
- R6. 干净基线全量、live、证据和环境终验全部通过后，才允许重新讨论生产 Go。

### Scope Boundaries

- **范围内：** `.github/workflows/release-artifacts.yml`、H5/Android 的 CI 可复现问题、相关测试、持久 evidence、最终 review 与任务总账。
- **按发现纳入：** API job 若最终失败，只修复能在本地重现且属于当前候选的 CI 差异。
- **范围外：** 新服务端 E2EE API、协议扩展、已有 migration 修改、旧主部署变更、U11/U13 产品功能。
- **提交边界：** H5、Android、workflow/测试、review 文档按最小可解释闭环拆分；每个 commit 后立即 push。

## 3. 执行看板

| Unit | Status | Exit condition |
| --- | --- | --- |
| F1 Restore live 与边界 | complete | 已关闭，不重做 |
| F2 Restore 独立复核 | complete | 已关闭，不重做 |
| F3 H5 production 审计 | complete | 已关闭，不重做 |
| F4 持久脱敏证据 | complete | 已关闭，不重做 |
| F5.1 前态冻结与首次触发 | complete | run `31061331555` 绑定 `32d065af` |
| F5.2 首次 run 取证与归因 | complete | run `31061331555` 结束；H5/Android 根因与 tag/Release 零副作用已确认 |
| F5.3 CI 差异修复 | complete | `e652aaa1` 已 push；本地同构门禁和干净 H5 candidate build 通过 |
| F5.4 新候选真实 workflow | in_progress | 冻结新候选与前态后触发全新 run；全部必需 jobs、artifact、attestation、HEAD 绑定和零副作用通过 |
| F6 最终四视角重审 | pending | 同一候选上 correctness/security/reliability/testing 均 `P0=0/P1=0` |
| F7 干净基线重放与裁决 | pending | 全部门禁、live、环境清理和证据通过，形成最终 review |

## 4. Implementation Units

### F5.2 首次 Release run 取证与归因

- **Goal:** 把首次真实 CI 失败转化为可复现、可归属的修复输入，同时确认失败 run 没有发布副作用。
- **Files:** `.github/workflows/release-artifacts.yml`、对应 job 调用的脚本与测试；本阶段只读取，归因明确前不改实现。
- **Approach:** 等待 run `31061331555` 完整结束，保存 run/job 元数据与 failed logs；逐项区分代码缺陷、CI 环境差异、依赖输入和偶发基础设施问题。比较触发前后的 tag/Release 集合。
- **Test scenarios:** H5 build 失败；Android JVM test 失败；API 成功或失败；失败后下游 artifact/attestation/upload 阻断；tag/Release 集合无差异。
- **Exit:** 每个失败都有具体命令、文件和错误归属；无副作用结论有前后摘要支撑；不把该 run 标为通过。

### F5.3 CI 差异修复

- **Goal:** 用最小变更关闭 F5.2 的确定性问题，并让本地门禁覆盖 CI 路径。
- **Files:** 由 F5.2 归因决定；优先复用现有 H5 release、Android JDK21 与 workflow contract 测试。
- **Approach:** H5、Android、API（若适用）分模块处理。先添加最小复现或回归断言，再修改实现或 workflow；不通过降低、跳过或 `continue-on-error` 绕过门禁。
- **Test scenarios:** CI 同命令本地通过；缺少产物、错误 HEAD、供应链门禁失败仍 fail closed；Android 固定 JDK21；H5 candidate 校验仍在 package/attestation 前执行。
- **Verification:** `make supply-chain.workflow.test`；H5 执行 `make h5-app.check h5-app.release.test`；Android 使用指定 JDK21 执行 `make android-app.test`；API 若改动执行 `make api.test`；提交前执行 Git diff 门禁。
- **Exit:** 模块测试通过，改动按模块 commit 并 push，`HEAD == origin/main`，工作区干净。

### F5.4 新候选真实 Release workflow

- **Goal:** 在修复后的新 HEAD 上证明 release 依赖、产物和 provenance 契约真实成立。
- **Approach:** 重新冻结 tag/Release 前态，以 `publish_release=false` 触发全新 run；禁止 rerun `31061331555` 作为最终证据。
- **Test scenarios:** 必需 jobs 成功；供应链 gate 不可绕过；H5/Android/API 产物存在且绑定 head SHA；attestation subject 匹配；无 tag/Release 副作用。
- **Exit:** 新 run conclusion 为 success，机器证据可持久化验证，前后 tag/Release 差集为空。

### F6 G4 最终四视角重审

- **Goal:** 在 F5.4 的同一候选 HEAD 上独立审查全部整改和发布证据。
- **Files:** 当前候选 diff、F1-F5 reviews/evidence，并新增 `docs/reviews/` 最终复核记录。
- **Approach:** correctness、security、reliability、testing 使用四个独立上下文；finding 回到最早受影响单元，不合并或降级隐藏。
- **Test scenarios:** R1-R6 可追溯；证据 subject 一致；失败清理有效；旧主仍 plaintext；任一 P0/P1 阻断 F7。
- **Exit:** 四视角均 `P0=0/P1=0`，review 与候选 commit 已 push。

### F7 干净基线重放与最终裁决

- **Goal:** 从干净 checkout 完成全量、本地 live、远端只读终验和唯一 Go/No-Go 记录。
- **Files:** 最终 G4/U7 review、本文、`docs/reports/task-list.md`。
- **Approach:** 所有验证绑定同一候选 commit；任一失败记录最早 checkpoint 并保持 No-Go，不降低门禁换取成功。
- **Test scenarios:** 六端供应链、API、core、Android、iOS、H5、`test.all`、`test.live`、持久 evidence、临时资源清零、旧主未触碰。
- **Exit:** Definition of Done 全部满足并形成最终裁决；否则明确剩余阻断并保持 **No-Go**。

## 5. Verification Contract

| Gate | Command / evidence | Pass condition |
| --- | --- | --- |
| Workflow contract | `make supply-chain.workflow.test` | release 依赖和负向阻断通过 |
| Supply chain | `make supply-chain.check supply-chain.test` | 六模块报告完整、fail closed |
| H5 | `make h5-app.check h5-app.release.test` | type-check、unit、build、candidate security 通过 |
| Android | JDK21 执行 `make android-app.test` | JVM tests 全部通过 |
| iOS | `make ios-app.test` | Swift tests 通过，live skip 单独解释 |
| API | `make api.test` | Compose unit/integration 通过 |
| Core | `make e2ee-core.check && make e2ee-core.check.targets` | host 与移动目标构建通过 |
| Evidence | `make e2ee.evidence.verify e2ee.evidence.test` | schema、摘要、敏感扫描与负例通过 |
| Full | JDK21 执行 `make test.all` | 自包含全量回归通过 |
| Live | JDK21 执行 `make test.live` | 原生双端、H5、API、Admin live 通过 |
| GitHub | 新 workflow run + tag/Release 前后差分 | 必需 jobs 成功、身份一致、零发布副作用 |
| Environment | 远端只读核对与 run-scoped cleanup | 临时资源清零；旧主 `persist/plaintext` 且未停止、升级或写入 |
| Git | `git diff --check`、`git diff --cached --check`、staged diff | 只提交本单元文件，commit 后已 push |

Android JVM/Gradle 命令固定使用：

```bash
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home
```

## 6. Definition of Done

- D1. 本文是唯一 active U10 E2EE 计划；索引和任务总账不再指向旧 checkpoint。
- D2. 首次失败 run 的完整日志、根因和 tag/Release 零副作用均已记录。
- D3. 所有 CI 差异都有本地回归门禁，修复未降低 release、供应链或安全检查。
- D4. 修复后全新 Release workflow 成功，artifact/attestation 与候选 HEAD 一致且没有 tag/Release 副作用。
- D5. 最终四视角独立复审为 `P0=0/P1=0`。
- D6. 干净基线全量、live、证据与环境终验全部通过。
- D7. 临时 container、volume、network、端口和 artifact 清零；`im-test-1` 旧主始终保持 `persist/plaintext` 且未被停止、升级或写入。
- D8. 只有 D1-D7 全部满足，最终 review 才允许给出生产 E2EE Go；否则保持 **No-Go**。

## 7. 恢复快照

| Field | Value |
| --- | --- |
| Active unit | F5 |
| Active checkpoint | F5.4 新候选真实 Release workflow |
| Candidate HEAD | F5.3 implementation commit `e652aaa15cf16017196ec4cad6646715fd91b2bc`；本文进度提交后以新 HEAD 为最终 subject |
| First workflow run | `31061331555`，failure，subject `32d065af` |
| First run pass | Validate、Supply-chain、API test、API arm64/x86_64 build |
| First run failure | H5 缺失仓库变量；Android 缺失 Linux host cdylib |
| F5.3 verification | workflow contract、供应链 32 类负例、Android JVM/lint/APK、H5 check/release 21 场景、干净 candidate build、API Compose 全部通过 |
| Before-state SHA | tags `e023f4b370a568468175d424a832b14e99a2052f6eebc630a1df065961f08cb8`；Releases `b9b1303f61ac70002c80585c3b55fa3ab1d0e1c6f463b13b39f6233f52a8fe4f` |
| Old primary | `persist/plaintext`，禁止停止、升级或写入 |
| Immediate action | 提交并 push 本次进度文档，确认工作区干净和 `HEAD == origin/main`；重新冻结 tag/Release 前态并触发全新 `publish_release=false` workflow |

## 8. 历史映射

| 当前文档 | 旧文档单元 | 说明 |
| --- | --- | --- |
| F1-F4 | E1-E4 | 已完成事实基线，不重做 |
| F5 | E5 | 拆分为首次取证、修复和新候选重跑 |
| F6 | E6 | 最终四视角独立复审 |
| F7 | E7 | 干净基线重放与最终裁决 |

历史完整设计与执行日志保留在 `docs/plans/2026-08-06-u10-e2ee-remaining-closure-execution-plan.md`，但其状态已 superseded。
