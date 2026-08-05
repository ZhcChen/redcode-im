---
title: "security: U10 E2EE 剩余执行主计划"
date: 2026-08-05
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: active
current_unit: G2
current_checkpoint: G2.1
verdict: no-go
last_progress_update: 2026-08-05
---

# security: U10 E2EE 剩余执行主计划

## 1. 执行规则

本文是 U10 E2EE 从当前状态到生产发布裁决的**唯一 active 计划、进度总账和
会话恢复点**。固定顺序为：

`G1 备份恢复与灰度演练 -> G2 供应链门禁 -> G3 H5 发布安全 -> G4 独立复审与裁决`

在 G4 明确裁决为 Go 前：

- 生产 E2EE 始终保持 **No-Go**，`content_audit_mode=plaintext`。
- 测试候选环境只允许受控短时 `active`，每次成功或失败后均回滚
  `persist/plaintext` 并恢复 `security_review_approved=false`。
- 不重做已经完成的 U1-U7、N1-N7、C1-C8、R1-R4，不扩展 E2EE API 契约。
- 不升级、不清空、不写入 `im-test-1` 旧主库；G1 只使用独立候选数据库和
  Redis volume。
- 每个检查点完成验证、最小闭环 commit 并 push 后，才进入下一检查点。

## 2. 已完成基线

| 范围 | 状态 | 证据 |
| --- | --- | --- |
| E2EE core、API、Admin、H5 主链 U1-U7 | 完成 | `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` |
| Android/iOS 原生接入 N1-N7 | 完成 | `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` |
| 原生最终验证 R1-R4 | 完成 | `docs/plans/2026-08-05-u10-e2ee-native-clients-final-verification-plan.md` |
| U7 P0-1 三端 E2EE 主链 | 关闭 | Android/iOS/H5 live、附件、恢复、撤销、泄漏扫描 |
| S3 公网 SigV4 预签名 | 完成并推送 | `ff830a4b fix(api): 修复 S3 公网预签名` |
| live KeyPackage 低水位补充 | 完成并推送 | `adf69ce3 test(e2ee): 补齐 live KeyPackage 库存` |
| G1 隔离候选 live、备份恢复与灰度回滚 | 完成 | `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md` |

生产发布仍有两个 P0 工作域：G2 漏洞与许可证门禁、G3 H5 发布安全报告。
G4 只负责复核和裁决，不替代前两项。

## 3. G1 完成记录

G1 已完成并关闭 U7 P0-2。完整证据见
`docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md`；本节只保留执行恢复
记录，不再派发 G1 任务。

### 3.1 已验证事实

- 候选镜像 `g1-ff830a4b` 已证明公网附件 PUT 不再返回 403，S3 presign Host
  修复有效。
- PUT 后服务端 `head_object` 出现 `dispatch failure`。运行时数据库仍保存旧候选
  镜像物化的 `https://rustfs:9000`，新镜像启动时因已有 default provider 而跳过
  bootstrap，修正后的 env 无法同步到系统托管 provider。
- 管理员自定义 default provider 必须保持不变；只有 default 不存在或名称为
  `system-s3-runtime` 时才允许启动同步。
- `api/src/services/storage_config.rs` 已实现上述判断并新增单测；本轮
  `make api.test` 已通过，unit 188/188，全部 integration tests 通过。
- 初始失败夹具清理后曾保留一台合规 H5 设备与 19 个可用 KeyPackage；随后
  成功 live 已形成附件 commit 与完整三端数据集，并在取证后全部清理。
- 最终候选 API commit 为 `74d1231e`，`linux/amd64` 归档 SHA-256 为
  `c972c20118ce7177ad07bf039d990d75dd28fb0c5ec079e170aad6e00d72ea21`。
- `g1c-9ee1285f` 三端 live 6/6 通过，DB/Push、Redis、API log、RustFS marker
  扫描通过；`g1-full7-9ee1285f` 完整演练通过。
- 演练后候选栈、独立 volume、dump、token、归档和 tunnel 已清理，旧主环境
  health 正常。

### 3.2 G1 交付物

| 文件 | 归属闭环 | 当前状态 |
| --- | --- | --- |
| `api/src/services/storage_config.rs` | G1.3a 系统托管 provider 同步修复 | `9ee1285f` 已推送 |
| `api/src/storage/s3.rs` | G1.5 typed S3 NotFound 兼容 | `74d1231e` 已推送 |
| `.gitignore` | G1.5 演练临时产物隔离 | `b0681588` 已推送 |
| `deploy/im-test-1/README.md` | G1.4/G1.5 运维说明 | `b0681588` 已推送 |
| `deploy/im-test-1/docker-compose.e2ee-drill.yml` | G1.4 隔离候选栈 | `b0681588` 已推送 |
| `deploy/im-test-1/e2ee-backup-rollout-drill.sh` | G1.4 演练驱动 | `full7`/TERM 通过，`b0681588` 已推送 |
| `tests/scripts/cleanup-e2ee-live-fixtures.sh` | G1.5 live 夹具一致性清理 | 候选库真实清理通过，`abaf7a5d` 已推送 |

### 3.3 G1 检查点（全部完成）

#### G1.3a 提交系统托管 provider 同步修复（完成）

1. 对 `storage_config.rs` 执行 `rustfmt --check`、`git diff --check` 并复核 diff。
2. 只 stage 该文件，提交 `fix(api): 同步系统托管存储配置`，立即 push。

完成条件：API 全量测试绿色；inactive/active 的管理员自定义 default 均不会被
覆盖；系统托管 provider 可幂等同步。

#### G1.3b 重建和部署候选镜像（完成）

1. 从 G1.3a 新 commit 构建 `linux/amd64` release 镜像，标签必须绑定 commit。
2. 导出、上传并加载镜像，只重建 `api-drill`，不触碰旧主栈。
3. 验证 `system-s3-runtime.endpoint=http://rustfs:9000`、health/readiness 通过。

完成条件：镜像架构、commit、digest 可追溯；服务端 S3 I/O 与公网 presign
分别使用正确 endpoint。

#### G1.3c 候选三端 live 数据集（完成）

1. 临时批准安全门禁，执行 `prepare -> active`。
2. 固定 JDK21 运行完整 `make h5-app.test.e2ee.live`，覆盖 Android、iOS、H5
   文本、附件、恢复、撤销和 epoch 场景。
3. 验证附件 PUT、`head_object`、commit 和对端解密完整闭环。
4. 检查 attachment commit 大于 0、每台 active device 可用 KeyPackage 不低于
   10、pending device 为 0，并完成 DB/Redis/log/Push/S3 marker 抽检。
5. 无论成功失败立即 rollback，恢复审批值与 `persist/plaintext`。

完成条件：全部 live 通过、无明文/密钥泄漏、失败路径无 plaintext 降级、候选
runtime 已恢复。

#### G1.4 完整备份恢复、灰度和回滚演练（完成）

1. 对候选数据执行 `preflight`、custom-format backup、独立 PostgreSQL 17 恢复。
2. 比较源库与恢复库计数、密文摘要、门禁、附件授权和引用完整性。
3. 注入损坏归档并证明恢复 fail closed。
4. 演练 `prepare -> active -> API recreate -> rollback`，验证 readiness 与客户端
   行为；中断和失败信号也必须触发恢复。
5. 生成不含 token、密码、私钥、DEK、nonce 和正文的机器可读报告。

完成条件：备份恢复一致、损坏备份被拒绝、runtime 原子恢复、候选环境无遗留
临时恢复容器或 volume。

#### G1.5 证据、提交和清理（完成）

1. 定向验证 live 夹具清理脚本，再验证 shell/Compose 配置和文档命令。
2. 新增 `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md`，记录镜像
   commit/digest、演练 run、恢复摘要、故障注入与最终 runtime。
3. 将演练脚本、Compose、README、`.gitignore`、清理脚本按运维/测试边界拆分
   最小 commits，逐个 push。
4. 删除临时管理员 token、归档、SSH tunnel、候选容器和候选 volumes，确认旧
   主环境未变化。

完成条件：G1 review 可复跑、工作区无 G1 未解释改动、U7 P0-2 关闭。

## 4. 后续 Gate

### G2 供应链安全门禁

**依赖：** G1 完成、提交并 push。

- 为 `api/`、`e2ee-core/`、`android-app/`、`ios-app/`、`h5-app/`、`admin/`
  建立 lockfile 驱动的 SBOM、漏洞扫描和许可证核验。
- 本地与 CI 复用同一入口；扫描器、漏洞数据库或报告解析不可用时 fail closed。
- 明确严重度阈值、许可证 allow/deny 策略和带责任人、到期时间的临时豁免。
- 验证已知漏洞、拒绝许可证、过期豁免和工具不可用均能阻断。

产物：CI/扫描入口和
`docs/reviews/2026-08-05-u10-e2ee-supply-chain-review.md`。完成后关闭 U7 P0-3。

### G3 H5 发布安全检查

**依赖：** G2 完成、提交并 push。

- 在候选发布环境核验 CSP/安全响应头、commit 与 lockfile 可追溯性、source map
  暴露、browser storage、Network、Console 和日志泄漏。
- 证明 WebCrypto 包装密钥不可导出；状态损坏、身份变化、未知 epoch 和解密
  失败均 fail closed，不回退 plaintext。
- 不为验收放宽 CSP 到不受控 `inline`/`eval`；报告明确 H5 威胁模型边界。

产物：`docs/reviews/2026-08-05-u10-e2ee-h5-release-security-review.md`。完成后关闭
U7 P0-4。

### G4 独立复审与最终裁决

**依赖：** G1-G3 全部完成、review、commit 并 push。

1. 独立执行 correctness、security、reliability、testing 复审。
2. 重跑 core、API、Android、iOS、H5、全量与 live 门禁，Android/JVM 固定
   JDK21。
3. 确认所有环境为 `persist/plaintext`，不存在 token、tunnel、归档、临时容器
   或 volume。
4. 更新 U7 审查与任务总账。只有 P0 全部关闭、无未解决 P0/P1 且证据可复现时
   才允许裁决 Go，否则继续 No-Go。

## 5. 验证与提交门

```bash
make e2ee-core.check
make e2ee-core.check.targets
make api.test
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.all
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.live
git diff --check
git diff --cached --check
```

- 上述基础测试不能替代 G1 运维演练、G2 供应链扫描或 G3 浏览器发布审计。
- 提交前执行 `git status --short`，只 stage 当前闭环文件并查看 staged diff。
- commit 后立即 push；不提交 token、密码、私钥、dump、脱敏前日志或临时报告。

## 6. Definition of Done

- D1. G1 在隔离候选环境完成 live、备份、独立恢复、故障注入、灰度、重建和
  回滚，U7 P0-2 关闭。
- D2. G2 全技术栈漏洞与许可证门禁进入 CI，U7 P0-3 关闭。
- D3. G3 形成可复跑的 H5 发布安全报告，U7 P0-4 关闭。
- D4. G1-G3 均完成 review、验证、最小闭环 commit 和 push，无未解释改动。
- D5. G4 独立复审无未解决 P0/P1，全量与 live 门禁通过。
- D6. U7 审查、任务总账和入口文档同步；临时敏感文件与演练资源全部清理。
- D7. 只有 D1-D6 全部满足，生产 E2EE 才允许从 No-Go 改为 Go。

## 7. 历史计划索引

| 计划族 | 状态 | 用途 |
| --- | --- | --- |
| `2026-08-04-001/002` U10 总计划 | superseded | 产品契约与早期分解 |
| `2026-08-05-u10-e2ee-u4/u5/u6/u7-*` | superseded | 各能力实现设计 |
| `2026-08-05-u10-e2ee-native-clients-plan.md` | superseded | N1-N7 原生接入设计 |
| `native-clients-closure/final-closure/acceptance-closure` | superseded | 历史收口过程 |
| `native-clients-final-verification-plan.md` | complete | 已完成验收证据，不派发任务 |
| `production-release-closure-plan.md` | superseded | G1-G4 早期分解 |
| `release-readiness-master-plan.md` | superseded | G1.2 时点的旧恢复入口 |
| 本文 | active | 唯一任务派发与恢复入口 |

## 8. 下一步

执行 **G2.1**：盘点现有 CI、lockfile、SBOM 和扫描入口，冻结漏洞严重度、
许可证 allow/deny、限时豁免与 fail-closed 契约；不得提前进入 G3。
