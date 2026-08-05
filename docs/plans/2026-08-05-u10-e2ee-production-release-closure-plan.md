---
title: "security: U10 E2EE 生产发布收口计划"
date: 2026-08-05
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: superseded
superseded_by: docs/plans/2026-08-05-u10-e2ee-release-readiness-master-plan.md
current_unit: G1
last_progress_update: 2026-08-05
---

# security: U10 E2EE 生产发布收口计划

> 本计划已由
> `docs/plans/2026-08-05-u10-e2ee-release-readiness-master-plan.md` 取代。
> 后续只从新主计划恢复和派发；本文保留为 G1-G4 初始范围记录。

## 1. 计划定位

本文记录 U10 E2EE 剩余发布工作的初始 G1-G4 分解，现已归档，不再作为执行入口。
当前状态、检查点和恢复说明统一维护在
`docs/plans/2026-08-05-u10-e2ee-release-readiness-master-plan.md`。原生客户端
N1-N7 与最终验证 R1-R4 已完成，不再重复执行。

固定执行链：

`G1 备份恢复与灰度演练 -> G2 供应链门禁 -> G3 H5 发布安全检查 -> G4 独立复审与发布裁决`

在 G1-G4 全部完成且独立审查明确给出 Go 前，生产 E2EE 始终保持 **No-Go**，
`content_audit_mode` 保持 `plaintext`。

## 2. 当前事实基线

### 2.1 已完成，不再派发

- E2EE core、API、Admin、Android、iOS 与 H5 的协议及主链实现。
- 单聊、多设备、群聊、附件、外围降级和 Admin runtime gate。
- Android/iOS/H5 三端正式路径互解和 DB/Redis/log/S3 泄漏扫描。
- JDK21 `make test.all`、JDK21 `make test.live`、core host/四目标门禁。
- U7 P0-1 已关闭；验收计划和记录均已归档为完成态。

### 2.2 唯一剩余 P0

| 编号 | 阻断项 | 当前状态 | 关闭单元 |
| --- | --- | --- | --- |
| P0-2 | 生产备份恢复、灰度窗口与滚动部署未演练 | 手册存在，缺真实演练证据 | G1 |
| P0-3 | CI 漏洞扫描与许可证批量核验未配置 | SBOM 清单存在，缺自动门禁 | G2 |
| P0-4 | H5 发布前 CSP/依赖锁定/WebCrypto 检查无正式报告 | 实现和测试存在，缺发布审计 | G3 |

## 3. 实施单元

### G1. 备份恢复与灰度回滚演练

**目标：** 在隔离、可恢复的部署环境中证明密文数据、E2EE 状态与 runtime gate
可以备份、恢复、灰度启用并安全回滚。

**工作项：**

1. 以 `docs/reference/security/e2ee-backup-recovery.md` 为基线冻结演练版本、镜像、
   migration、配置和数据集，不使用开发环境临时状态替代部署证据。
2. 生成 PostgreSQL 备份并恢复到独立实例；验证 messages、MLS state、device、
   KeyPackage、control message、attachment grant 与 runtime gate 的数量和关联一致。
3. 使用 Android/iOS/H5 测试账号验证恢复前后历史密文可读、新消息可互解、失权
   设备仍不可读新 epoch。
4. 执行 `plaintext -> prepare -> active` 灰度窗口、滚动部署和 `active -> plaintext`
   回滚；验证旧密文保持可读、回滚只影响新发送策略。
5. 记录恢复时长、数据校验、失败注入、回滚时长、操作人和环境；证据不得包含
   token、私钥、DEK、nonce 或消息明文。

**停止条件：** 任一恢复后密文不可读、成员/设备权限漂移、runtime 无法原子回滚，
或明文/密钥进入备份外泄路径，立即保持 No-Go。

**产物：** `docs/reviews/YYYY-MM-DD-u10-e2ee-backup-rollout-drill.md`。

### G2. 供应链安全门禁

**依赖：** G1 完成并形成可复核证据。

**目标：** 将 Rust、Kotlin/Gradle、SwiftPM、bun/pnpm 依赖的漏洞与许可证检查固化
为可重放、默认 fail closed 的 CI 门禁。

**工作项：**

1. 为 `api/`、`e2ee-core/`、`android-app/`、`ios-app/`、`h5-app/`、`admin/`
   建立锁文件驱动的 SBOM、漏洞扫描和许可证清单。
2. 明确严重度阈值、允许许可证、拒绝许可证、临时豁免字段、到期时间与责任人；
   禁止无期限或无依据忽略。
3. 将扫描接入 CI；工具不可用、数据库更新失败或解析失败时不得静默通过。
4. 固化本地复跑入口，CI 上传机器可读报告和摘要，不上传凭据。
5. 清零阻断级漏洞/许可证冲突，或以有时限、经审查的例外记录处置。

**产物：** CI 配置、扫描脚本、更新后的 SBOM 报告和
`docs/reviews/YYYY-MM-DD-u10-e2ee-supply-chain-review.md`。

### G3. H5 发布安全检查

**依赖：** G2 全绿。

**目标：** 对 H5 的部署响应头、依赖锁定和 WebCrypto 包装密钥边界形成正式、
可复跑的发布报告。

**工作项：**

1. 在候选发布环境验证严格 CSP、HTTPS/HSTS、frame、MIME、referrer 与 permissions
   policy；CSP 不允许为通过验收而放宽到不受控 inline/eval。
2. 验证构建只使用已提交 lockfile，产物可追溯到 commit，依赖扫描结果与 G2 对齐。
3. 验证包装密钥不可导出，状态损坏、身份变化、未知 epoch 和解密失败均 fail closed，
   不回退 plaintext。
4. 抽检 browser storage、Network、Console、source map 和日志，确认无私钥、DEK、
   nonce、RCST 或正文 marker 泄漏。
5. 明确 H5 威胁模型边界：不宣称抵抗已攻陷 Origin、恶意扩展或运行时 XSS。

**产物：** `docs/reviews/YYYY-MM-DD-u10-e2ee-h5-release-security-review.md`。

### G4. 独立复审与最终裁决

**依赖：** G1-G3 分别完成、验证、提交并 push。

**工作项：**

1. 对 G1-G3 的代码、CI、运维证据和报告做 correctness、security、reliability、
   testing 独立复审。
2. 重跑 core、API、Android、iOS、H5、全量与 live 门禁；Android 固定 JDK21。
3. 抽检生产候选环境保持预期 runtime；未经审批不得因测试遗留 `active`。
4. 更新 `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` 和本总账。
5. 仅当全部 P0 关闭、无未解决 P0/P1 且证据可复现时给出 Go；否则列出阻断项并
   保持 No-Go，不以“主要功能通过”替代安全裁决。

## 4. 验证矩阵

```bash
make e2ee-core.check
make e2ee-core.check.targets
make api.test
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  make test.all
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  make test.live
git diff --check
git diff --cached --check
```

G1-G3 还必须运行各自产生的演练或扫描入口，不能只用上述代码测试代替运维和安全
证据。每个单元按最小可解释闭环提交，commit 后立即 push，再进入下一单元。

## 5. Definition of Done

- D1. 隔离环境完成备份、恢复、灰度、滚动部署与回滚演练，密文和授权语义不变。
- D2. 全技术栈漏洞与许可证检查进入 CI，失败策略和限时豁免规则可审计。
- D3. H5 CSP、依赖锁定、WebCrypto 与泄漏边界形成正式发布报告。
- D4. G1-G3 独立复审无未解决 P0/P1，所有最终门禁通过。
- D5. U7 剩余三个 P0 逐项有可复现证据，不合并、不降级判定。
- D6. U7 发布裁决、任务总账和文档入口同步，工作区无未解释改动。
- D7. 只有满足 D1-D6 才允许把生产裁决从 No-Go 改为 Go。

## 6. 恢复点

下一步从 **G1** 开始：先核对现有备份恢复手册、`im-test-1` 部署配置和可用隔离
环境，形成演练前检查表。不要重做客户端 N1-N7 或最终验证 R1-R4，也不要提前把
生产 runtime 切到 `active`。
