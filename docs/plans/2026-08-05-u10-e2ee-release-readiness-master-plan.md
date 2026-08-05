---
title: "security: U10 E2EE 发布就绪主计划"
date: 2026-08-05
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: superseded
superseded_by: docs/plans/2026-08-05-u10-e2ee-release-readiness-execution-plan.md
current_unit: G1
current_checkpoint: G1.2
verdict: no-go
last_progress_update: 2026-08-05
---

# security: U10 E2EE 发布就绪主计划

> 本计划已由
> `docs/plans/2026-08-05-u10-e2ee-release-readiness-execution-plan.md` 接替。
> 本文仅保留 G1 初始设计与历史恢复信息，不再作为任务派发或进度判断入口。

## 1. 历史执行入口

本文曾是 U10 E2EE 后续工作的 active 计划，现仅保留 G1.2 时点的状态快照。
当前任务派发和会话恢复必须使用 `superseded_by` 指向的新计划。

固定执行顺序：

`G1 备份恢复与灰度演练 -> G2 供应链门禁 -> G3 H5 发布安全检查 -> G4 独立复审与发布裁决`

G1-G4 全部完成且 G4 明确裁决为 Go 前：

- 生产 E2EE 始终为 **No-Go**。
- `content_audit_mode` 保持 `plaintext`。
- 测试环境只允许受控 `prepare`；临时 `active` 必须在演练结束后恢复。
- 不重做 N1-N7、C1-C8 或 R1-R4，不扩展现有 E2EE API 契约。

## 2. 当前进度总账

| 工作域 | 状态 | 已有证据 | 后续动作 |
| --- | --- | --- | --- |
| E2EE core、API、Admin、H5 主链 | 完成 | U1-U7 review、自动化测试 | 仅回归，不重做 |
| Android/iOS 原生接入 N1-N7 | 完成 | `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` | 仅作为 G1/G4 live 验收端 |
| 原生最终验证 R1-R4 | 完成 | `docs/plans/2026-08-05-u10-e2ee-native-clients-final-verification-plan.md` | 不再派发 |
| U7 P0-1 原生三端主链 | 关闭 | Android/iOS/H5 三端 live 与泄漏扫描 | G4 复核证据即可 |
| U7 P0-2 备份恢复/灰度 | 执行中 | G1 候选栈和本机演练基线已建立 | 完成 G1.2-G1.5 |
| U7 P0-3 供应链门禁 | 未开始 | 仅有 SBOM 基线 | G2 |
| U7 P0-4 H5 发布安全 | 未开始 | 实现与测试存在，缺正式发布审计 | G3 |
| 最终独立裁决 | 未开始 | 当前 U7 裁决为 No-Go | G4 |

## 3. G1 当前恢复点

### 3.1 已完成且可复用

- 已确认 `im-test-1` 主环境仍运行旧 API/旧 migration 状态，**禁止直接升级或
  写入旧主库**。
- 已创建独立候选栈 `postgres-drill`、`redis-drill`、`api-drill`，API 仅绑定
  远端 `127.0.0.1:18010`，使用独立 PostgreSQL volume，复用现有 RustFS 网络。
- 已建立本机到候选 API 的 SSH tunnel；本轮结束时必须显式关闭。
- 已新增隔离演练 Compose 与驱动脚本，支持 `preflight`、`backup-restore`、
  `full`，写操作要求显式确认，失败路径负责恢复 runtime 和清理临时资源。
- 本机 dev 的 `preflight` 与 `backup-restore` 已通过：E2EE 表引用完整、源库与
  独立恢复库快照一致、损坏归档被拒绝、runtime 恢复为 `persist/plaintext`。

### 3.2 执行中：修复候选附件预签名

候选 H5 E2EE live 文本链路通过，但附件 PUT 返回 403。已定位为 S3 SigV4 在签名
后改写 `Host`，以及裸内网 endpoint 未应用 `REDCODE_IM_STORAGE_SCHEME`。

当前未提交实现：

- `api/src/storage/s3.rs`：数据面 client 使用内网 endpoint，独立 presign client
  从签名开始使用公网 endpoint，禁止签名后改写 host。
- `api/src/services/storage_config.rs`：裸 endpoint 应用显式 storage scheme。
- 对应定向单测与 `make api.test` 已通过（API unit 187/187，全部 integration
  tests 通过）；尚待独立代码审查与候选镜像 live 验证。

### 3.3 G1 剩余检查点

| 检查点 | 状态 | 完成条件 |
| --- | --- | --- |
| G1.1 隔离候选栈与演练驱动 | 完成 | 不接触主库；失败路径可恢复和清理 |
| G1.2 S3 公网预签名修复 | 执行中 | API 全量测试通过；correctness/security/reliability review 无阻断 |
| G1.3 候选镜像与 E2EE 数据集 | 未开始 | 新镜像部署到候选栈；H5 live 文本和附件通过；含 attachment commit |
| G1.4 完整备份/恢复/灰度/回滚 | 未开始 | 独立恢复一致；损坏备份拒绝；runtime 原子恢复；readiness 通过 |
| G1.5 证据、提交与清理 | 未开始 | review 文档、最小闭环 commits 均 push；临时 token/归档/tunnel/候选 volume 清理 |

G1 产物：`docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md`。

## 4. 剩余实施单元

### G2. 供应链安全门禁

**依赖：** G1 完成、提交并 push。

**范围：** `api/`、`e2ee-core/`、`android-app/`、`ios-app/`、`h5-app/`、
`admin/` 的锁文件驱动 SBOM、漏洞扫描和许可证核验。

**关键决策：**

- CI 和本地使用同一可复跑入口；扫描器不可用、漏洞数据库更新失败或报告解析
  失败均 fail closed。
- 明确严重度阈值、允许/拒绝许可证，以及带责任人和到期时间的临时豁免；禁止
  永久静默忽略。
- 报告可机器读取并作为 CI artifact 保存，不包含凭据或内部 token。

**测试场景：** 正常锁文件全绿、已知阻断漏洞失败、拒绝许可证失败、过期豁免
失败、扫描器/数据库不可用失败、报告中无凭据。

**产物：** CI 配置、扫描入口、SBOM/许可证报告与
`docs/reviews/2026-08-05-u10-e2ee-supply-chain-review.md`。

### G3. H5 发布安全检查

**依赖：** G2 完成、提交并 push。

**范围：** 候选发布环境的 CSP/安全响应头、lockfile 可追溯性、WebCrypto 包装
密钥边界，以及 browser storage、Network、Console、source map 和日志泄漏检查。

**关键决策：**

- CSP 不为通过验收放宽到不受控 `inline`/`eval`。
- 包装密钥保持不可导出；状态损坏、身份变化、未知 epoch 和解密失败均 fail
  closed，不回退 plaintext。
- 报告明确 H5 不抵抗已攻陷 Origin、恶意扩展或运行时 XSS，避免扩大安全声明。

**测试场景：** 严格响应头、构建与 commit/lockfile 一致、密钥不可导出、损坏状态
阻断、RCST/DEK/nonce/正文 marker 泄漏扫描为零、source map 暴露检查。

**产物：** `docs/reviews/2026-08-05-u10-e2ee-h5-release-security-review.md`。

### G4. 独立复审与最终裁决

**依赖：** G1-G3 各自完成验证、review、最小闭环 commit 和 push。

**工作项：**

1. 对 G1-G3 的实现、CI、部署证据和报告执行独立 correctness、security、
   reliability、testing 复审。
2. 重跑 core、API、Android、iOS、H5、全量和 live 门禁；Android/JVM 固定 JDK21。
3. 确认候选环境和所有演练环境均已恢复 `persist/plaintext`，不存在遗留 token、
   tunnel、临时归档或候选 volume。
4. 更新 `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` 与任务总账。
5. 仅当 P0 全部关闭、无未解决 P0/P1 且证据可复现时裁决为 Go；否则列出阻断
   并保持 No-Go。

## 5. 验证与提交门

基础验证入口：

```bash
make e2ee-core.check
make e2ee-core.check.targets
make api.test
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.all
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.live
git diff --check
git diff --cached --check
```

- G1-G3 还必须执行各自演练/扫描入口，基础测试不能替代运维和安全证据。
- 每单元按最小可解释闭环拆分 commit，提交前只 stage 本单元文件，commit 后立即
  push，再进入下一单元。
- 当前 G1 建议至少拆分为 `fix(api): 修复 S3 公网预签名` 与
  `test(e2ee): 固化备份恢复与灰度演练` 两个闭环。
- 不批量格式化全仓既有差异，只检查和格式化本轮涉及文件。

## 6. Definition of Done

- D1. G1 在隔离候选环境完成真实备份、独立恢复、灰度、滚动部署、失败注入与
  回滚；密文、授权、附件和 runtime 语义一致。
- D2. G2 全技术栈漏洞与许可证检查进入 CI，失败策略和限时豁免可审计。
- D3. G3 形成可重跑的 H5 CSP、依赖、WebCrypto 与泄漏边界发布报告。
- D4. G1-G3 分别完成 review、验证、提交和 push，无未解释工作区改动。
- D5. G4 独立复审无未解决 P0/P1，最终全量与 live 门禁通过。
- D6. U7 审查、任务总账和文档入口同步，所有临时敏感文件和演练资源已清理。
- D7. 只有 D1-D6 全部满足，最终裁决才允许从 No-Go 改为 Go。

## 7. 下一步

从 **G1.2** 继续：对 S3 修复执行 correctness/security/reliability review；无阻断
后构建新的候选 release 镜像并进入 G1.3。不得触碰 `im-test-1` 旧主库，也不得
提前进入 G2。
