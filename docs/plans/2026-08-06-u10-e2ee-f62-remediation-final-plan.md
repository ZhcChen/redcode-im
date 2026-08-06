---
title: "security: U10 E2EE F6.2 整改与最终裁决计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
status: active
current_unit: R3
current_checkpoint: R3-implementation-complete-pending-full-regression
verdict: no-go
supersedes: docs/plans/2026-08-06-u10-e2ee-final-closure-execution-plan.md
---

# security: U10 E2EE F6.2 整改与最终裁决计划

## 1. 唯一执行结论

- 本文是 U10 E2EE 当前唯一任务派发、状态恢复和最终收口入口。
- 已完成的 N1-N7、F1-F5、F6.1 首轮整改和两次真实 Release workflow 不重做。
- F6.2 为 `P0=0/P1=5/P2=0`，候选 `1bedf20a` 已失效。
- 严格按 `R1 -> R2 -> R3 -> R4 -> R5` 执行；实现或门禁变化后必须生成全新候选。
- 生产 E2EE 保持 **No-Go**。`im-test-1` 旧主保持 `persist/plaintext`，禁止停止、升级或写入旧主数据库。

## 2. 当前进度

| 项目 | 状态 | 证据或说明 |
| --- | --- | --- |
| N1-N7 / U1-U7 | complete | 原生双端、H5、API、Admin gate、附件与跨端 live 历史提交及 review |
| F6.1 首轮整改 | complete | `1bedf20a`；JDK21 `make test.all` 返回 0 |
| Release workflow | complete | run `31071229063`；必需 jobs 成功；Publish skipped；零发布副作用 |
| F6.2 独立重审 | complete/fail | `docs/reviews/2026-08-06-u10-e2ee-f62-independent-review.md` |
| 当前候选 | invalid | `1bedf20a8225257f7c01edac2bd02aee920dea16`，不得进入 F7 |
| 当前工作区 | in_progress | P1-04、P1-05 已实现并通过定向测试，尚未提交 |

历史设计和已关闭 finding 保留在旧计划与 `docs/reviews/` 中，但不再从那些文档恢复执行状态。

## 3. F6.2 阻断总账

| ID | 问题 | 状态 | 关闭条件 |
| --- | --- | --- | --- |
| F62-P1-01 | 持久 evidence 仅覆盖 H5 provenance | implemented/pending-live-evidence | H5、Android、API 两架构可从干净 checkout 离线重放 |
| F62-P1-02 | verifier 未验证签名、证书身份和透明日志 | implemented/pending-live-evidence | 可信根密码学验签；错误签名、repo、workflow、source 均 fail closed |
| F62-P1-03 | Android signing / Publish 未绑定受保护 environment | implemented/pending-full-regression | 绑定 `production-release`，并持久化 live policy 证据 |
| F62-P1-04 | Release 部分上传失败留下半成品 | complete | draft 完整上传后 publish；仅清理本次 owned draft；测试和审查通过 |
| F62-P1-05 | H5 lock 存在无 owner 窗口 | complete | owner lock 原子创建；非 owner/旧锁 fail closed；测试和审查通过 |

## 4. 执行单元

### R1. 收口可靠性整改

- 审查当前 P1-04、P1-05 实现，不直接采信并行结果。
- 分别运行 Release reliability、H5 candidate window 正负测试及受影响 tooling 测试。
- 按独立业务闭环提交并立即 push，不 stage 其他文件。

退出条件：P1-04、P1-05 的实现、测试、提交和远端分支一致。

### R2. 完整 provenance 与密码学验签

- workflow 为 H5、Android、API arm64、API x86_64 生成 SHA-256 sidecar 并 attestation。
- 持久化四类 sidecar、对应 bundle 和 Sigstore trusted root，不提交大型构建产物。
- verifier 使用 `gh attestation verify --bundle --custom-trusted-root` 验证签名、证书、透明日志、repo、signer workflow 和 source digest。
- sidecar 绑定真实 artifact digest；缺类别、bundle 篡改或 identity/source 错误均 fail closed。
- evidence、workflow contract、供应链正负测试通过后提交并 push。

退出条件：P1-01、P1-02 可在无网络的干净 checkout 中重放。

### R3. 生产 environment 边界

- candidate 构建不得取得 production signing secrets。
- 正式 Android signing 和 Publish job 绑定 `production-release` environment。
- candidate/tag 非发布路径保持无生产密钥边界。
- 配置 GitHub live environment policy 并保存脱敏 API 证据；文档声明不能代替 live 配置。
- 若当前仓库身份无法形成有效独立审批，记录阻断并保持 No-Go，不降低门禁。

退出条件：P1-03 的 workflow contract、负例和 live policy 证据均通过。

### R4. 新候选与第三轮独立复审

1. 工作区干净且 `HEAD == origin/main` 后冻结 tag/Release 前态。
2. 以 `publish_release=false` 启动全新 Release workflow，不 rerun 旧 run。
3. 验证必需 jobs、四类 provenance、artifact digest、持久 evidence 和零发布副作用。
4. 冻结新的 `implementation_candidate_sha` 与 run ID。
5. 用 correctness、security、reliability、testing 四个全新独立上下文复审。

退出条件：workflow 成功且复审去重为 `P0=0/P1=0`；否则候选失效并回到最早受影响单元。

### R5. 干净基线重放与最终裁决

- 从干净 checkout 绑定 R4 候选执行完整 Verification Contract。
- 执行本地 live、持久 evidence、临时资源清理和旧主只读状态核对。
- 更新最终 review、本文恢复快照和任务总账。
- 任一门禁失败均记录最早恢复点并保持 No-Go，不放宽测试换取通过。

## 5. Verification Contract

| Gate | 命令或证据 | 通过条件 |
| --- | --- | --- |
| Reliability | `bash tests/scripts/test-release-reliability.sh` | draft、部分失败、owned cleanup、重试、foreign Release 符合契约 |
| H5 lock | `bash tests/scripts/test-h5-release-candidate-window.sh` | 原子 owner lock、信号清理与非 owner 场景通过 |
| Supply chain | `make supply-chain.workflow.test supply-chain.check supply-chain.test` | 发布边界与六端报告完整 |
| Evidence | `make e2ee.evidence.verify e2ee.evidence.test` | 四类 provenance 密码学验签及负例通过 |
| H5 | `make h5-app.check h5-app.release.test` | check、unit、build、candidate security 通过 |
| Android | JDK21 `make android-app.test` | JVM、lint、构建与 signing 边界通过 |
| iOS / API / Core | `make ios-app.test api.test e2ee-core.check e2ee-core.check.targets` | 对应门禁通过 |
| Full / Live | JDK21 `make test.all`、`make test.live` | 自包含全量及真实后端联调通过 |
| GitHub | 新 Release run、attestation、environment policy、tag/Release 差分 | subject 一致、policy 生效、零发布副作用 |
| Environment | run-scoped cleanup 与旧主只读核对 | 临时资源清零；旧主仍为 `persist/plaintext` |

Android 固定使用：

```bash
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home
```

## 6. 提交与回退规则

- 每单元开始和提交前运行 `git status --short`，只 stage 当前单元文件，commit 后立即 push。
- 代码、workflow、依赖或测试门禁变化时，已有候选立即失效并回到 R4。
- 纯 review、evidence 索引和状态文档提交不改变冻结候选身份。
- 不扩展服务端 E2EE API，不修改已有 migration，不覆盖远端 `.env`。

## 7. Definition of Done

- D1. F62-P1-01 至 F62-P1-05 均有实现、测试和持久证据闭环。
- D2. H5、Android、API 双架构 provenance 可从干净 checkout 真正验签。
- D3. production signing 与 Publish 受 `production-release` environment 约束。
- D4. Release 和 H5 candidate window 在失败、重试与非 owner 场景 fail closed。
- D5. 全新 Release workflow 成功，资产绑定同一候选且无发布副作用。
- D6. 第三轮四视角独立复审为 `P0=0/P1=0`。
- D7. 干净基线全量、live、证据验证和临时资源清理全部通过。
- D8. `im-test-1` 旧主始终保持 `persist/plaintext`，未被停止、升级或写入。

## 8. 恢复快照

| Field | Value |
| --- | --- |
| Active unit | R3 |
| Active checkpoint | environment 实现和 live policy 已完成，待全量回归与提交 |
| Last review | F6.2 fail，`P0=0/P1=5/P2=0` |
| Invalid candidate | `1bedf20a8225257f7c01edac2bd02aee920dea16` |
| Last workflow run | `31071229063`，success，Publish skipped |
| Completed | P1-04 Release draft 原子发布；P1-05 H5 原子 owner lock |
| Pending live closure | P1-01、P1-02 新 workflow bundles；P1-03 全量回归 |
| Final verdict | No-Go |
