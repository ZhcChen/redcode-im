---
title: "feat: U10 E2EE U7 安全审查与发布裁决执行计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: active
---

# feat: U10 E2EE U7 安全审查与发布裁决执行计划

## Goal Capsule

- **目标：** 用可重放证据完成 R14/R15 的发布门禁：全链 marker 扫描、密钥/状态
  日志 denylist、SBOM/许可证与漏洞检查入口、备份恢复与灰度回滚演练、测试夹具
  清理机制核对，并由独立安全审查出具 Go/No-Go 裁决。
- **前置状态：** U6 已完成（`docs/reviews/2026-08-05-u10-e2ee-u6-admin-gate.md`）；
  门禁 active/rollback 原子、E2EE 消息与附件链路 fail closed。
- **发布约束：** U7 审查未给出 Go 前，生产 E2EE 保持 No-Go，runtime 保持
  `persist/plaintext`；测试环境仅允许 prepare。

## 关键设计决策

- K1. **marker 扫描自动化。** E2EE 消息链路发送带唯一 marker 的密文后，扫描
  数据库（messages/parts/push）、Redis 广播与 Push 队列，断言明文 marker、
  DEK/RCST/私钥格式都不出现；扫描逻辑固化为集成测试，不做一次性人工检查。
- K2. **日志 denylist 静态扫描。** 脚本扫描 API/H5 输出宏与日志调用，拒绝
  记录根私钥、凭据、KeyPackage、DEK/nonce、密文正文等字段；误报按白名单
  收敛，结果记录到审查报告。
- K3. **备份恢复与灰度回滚以文档+可重放步骤交付。** 原子回滚与历史密文可读
  已有自动化证据（U6）；生产 pg_dump/pg_restore、灰度窗口与滚动部署需要正式
  环境，作为 No-Go 阻断项记录，不伪造自动化通过。
- K4. **SBOM 与漏洞检查暴露现状。** 从 lockfile 生成依赖清单，标注许可证与
  漏洞扫描工具入口；CI 漏洞扫描未配置前不宣称通过。
- K5. **夹具清理复用现有链路。** R15 由 Admin data-cleanup 路由与 H5 live
  cleanup spec 承担，U7 只核对入口、补文档，不新建重复清理工具。

## Implementation Units

### U7-A. 全链 marker 扫描

- `api/tests/e2ee_marker_scan.rs`：注册设备 → gate active → 发送 E2EE 密文
  消息与 Push 触发 → 扫描 messages/message_parts/push_jobs/Redis 键无明文
  marker、无 DEK/RCST/私钥格式。

### U7-B. 日志 denylist 静态扫描

- `scripts/scan-e2ee-log-denylist.sh`：扫描 API/H5 输出宏中的敏感字段名。

### U7-C. SBOM 与许可证报告

- `docs/reports/2026-08-05-e2ee-sbom.md`：Rust/H5/Admin 依赖清单与许可证、
  漏洞检查入口与现状。

### U7-D. 备份恢复与灰度回滚演练

- `docs/reference/security/e2ee-backup-recovery.md`：pg_dump/pg_restore 步骤、
  恢复后密文验证、灰度窗口与故障回滚检查清单。

### U7-E. 测试夹具清理核对

- 核对 Admin data-cleanup 与 H5 live cleanup 入口，补充运行手册说明。

### U7-F. 独立安全审查与裁决

- `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md`：威胁模型、U1-U7
  证据映射、未覆盖项与 P0/P1 判定，结论 No-Go（原生端专项、生产演练与 CI
  漏洞扫描未完成）。

## Definition of Done

- D1. marker 扫描测试通过：DB/Redis/Push 无明文 marker、无 DEK/RCST/私钥格式。
- D2. 日志 denylist 脚本可运行且结果记录在案。
- D3. SBOM/许可证报告生成并标注漏洞扫描现状。
- D4. 备份恢复与灰度回滚演练文档可执行、步骤可重放。
- D5. 夹具清理入口核对完成并记录。
- D6. 独立安全审查给出明确 No-Go 裁决并列出阻断项；U10 保持
  `persist/plaintext`，生产 E2EE 不得启用。
