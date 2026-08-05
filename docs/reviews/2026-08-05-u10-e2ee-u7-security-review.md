---
title: U10 E2EE U7 独立安全审查与发布裁决
date: 2026-08-05
status: complete
scope: api,e2ee-core,h5-app,admin
verdict: no-go
---

# U10 E2EE U7 独立安全审查与发布裁决

## 结论

**裁决：No-Go。** 原生双端聊天主链接入与 Android/iOS/H5 三端 E2EE live 已
闭环，P0-1 关闭；但生产备份恢复与灰度回滚未演练、CI 漏洞扫描与许可证批量
核验未配置、H5 发布前安全检查未形成正式报告。测试环境保持
`persist/plaintext`，仅允许 `prepare` 预检。

## 威胁模型

| 威胁 | 服务端防御 | 现状 |
| --- | --- | --- |
| 服务端读取消息内容 | MLS 密文存储、内容密钥端侧持有 | U2/U4/U5 覆盖 |
| 服务端在启用后降级明文 | 门禁原子切换、明文发送 fail closed | U6 覆盖 |
| 传输窃听 | TLS + E2EE 密文 | 链路层 TLS；E2EE 密文 |
| 日志/DB/Redis/Push 明文泄漏 | marker 扫描 + 日志 denylist | U7-A/U7-B 覆盖 |
| 附件内容与密钥泄漏 | 每附件 DEK、密文上传、AAD 绑定 | U5 覆盖 |
| 被移除成员/撤销设备继续读取 | 成员修订 + epoch 推进 | U3/U4 覆盖 |
| H5 同源 XSS 攻陷 | 受限威胁模型 + 非导出包装密钥 | R15 限制声明 |
| 供应链（依赖漏洞/许可证） | SBOM 清单 | U7-C：清单在，扫描未配置 |
| 备份泄露 / 恢复后不可读 | 备份恢复手册 | U7-D：手册在，未演练 |
| 测试夹具污染 | Admin 全量清理 + live 定向清理 | U7-E 覆盖并修复缺口 |

## U1-U7 证据映射

| 单元 | 证据 | 状态 |
| --- | --- | --- |
| U1 OpenMLS PoC | `docs/reviews/2026-08-04-u10-e2ee-u1-openmls-poc.md` | 完成 |
| U2 单聊恢复/损坏矩阵 | commit `aa8170b2` + `e2ee_mls_integration.rs` | 完成 |
| U3 多设备/撤销 | `docs/reviews/2026-08-05-u10-e2ee-u3-multi-device.md` | 完成 |
| U4 群聊成员变化 | `docs/reviews/2026-08-05-u10-e2ee-u4-group-chat.md` | 完成 |
| U5 附件边界 | `docs/reviews/2026-08-05-u10-e2ee-u5-attachment-boundary.md` | 完成 |
| U6 Admin 门禁 | `docs/reviews/2026-08-05-u10-e2ee-u6-admin-gate.md` | 完成 |
| U7-A 全链 marker 扫描 | `api/tests/e2ee_marker_scan.rs` | 完成 |
| U7-B 日志 denylist | `scripts/scan-e2ee-log-denylist.sh` | 完成 |
| U7-C SBOM/许可证/漏洞 | `docs/reports/2026-08-05-e2ee-sbom.md` | 完成（扫描未配置） |
| U7-D 备份恢复/灰度回滚 | `docs/reference/security/e2ee-backup-recovery.md` | 完成（未演练） |
| U7-E 夹具清理核对 | `admin.rs cleanup_all_app_data` + `tests/scripts/cleanup-e2ee-live-fixtures.sh` | 完成（修复缺口） |

## U7-A 全链 marker 扫描结论

`api/tests/e2ee_marker_scan.rs` 走真实门禁链路（注册设备 → 覆盖达标 →
`security_review_approved` → prepare/active → commit → application 密文发送），
随后扫描：

- DB `messages`：content 为 `[加密消息]` 占位、密文为 RCML envelope、
  `encryption_metadata` 键白名单，无明文 marker、无敏感字段。
- DB `message_parts`：text part 仅为占位符。
- DB `push_job_queue`：message job 存在，snapshot content/preview 为
  占位符，无明文 marker、无敏感字段。
- Redis Pub/Sub 广播（protobuf wire）：无明文 marker。
- Redis 全量 string 键值：无明文 marker。

结论：R14 数据面扫描固化通过；扫描覆盖 DB、Redis、Push 三态，日志维度由
U7-B 静态扫描补齐。

## U7-B 日志 denylist 结论

`scripts/scan-e2ee-log-denylist.sh` 扫描 API Rust 与 H5/Admin TS/Vue 的日志
输出调用（420 条），当前敏感字段命中 0，退出码 0。脚本支持白名单收敛，
结果可重放；建议后续把“扫描到命中即阻断”接入 pre-commit/CI。

## U7-C SBOM 结论

- Rust：`api/Cargo.lock` 445 包、`e2ee-core/Cargo.lock` 193 包；OpenMLS 0.8.1
  精确锁定（MIT）。
- 前端：`h5-app/bun.lock`、`admin/pnpm-lock.yaml` 锁定传递依赖。
- **未完成（P0 阻断）**：许可证批量核验、CI 漏洞扫描
  （`cargo audit` / `bun audit` / `pnpm audit` / `osv-scanner`）。

## U7-D 备份恢复/灰度回滚结论

手册提供 im-test-1 可重放命令（pg_dump/pg_restore、恢复后密文与门禁验证、
灰度窗口、rollback 应急序列）。
**未完成（P0 阻断）**：生产环境真实演练与恢复主机验证。

## U7-E 夹具清理结论

核对发现并修复缺口：Admin `cleanup_all_app_data` 未显式清理 E2EE 表，旧
X3DH 表（`e2ee_identity_keys` / `e2ee_signed_pre_keys` /
`e2ee_one_time_pre_keys`）无外键会残留。已补充 9 张 E2EE 表并按 RESTRICT
外键排序；`e2ee_runtime_gate` 作为部署配置保留。新增集成测试
`admin_data_cleanup_removes_e2ee_user_fixtures_but_keeps_gate` 断言清理
后无残留且门禁单行保留。H5 live 定向清理脚本边界核对通过。

## 未覆盖项与 P0/P1 判定

### 已关闭 P0

1. 原生双端聊天主链与三端 E2EE live：Android/iOS/H5 正式路径已覆盖双向文本、
   附件、恢复、离线补拉、重复帧、损坏密文、设备撤销和 epoch 推进；验收 run
   `r21785933828` 与最终门禁 run `r41785934114` 的 DB/Redis/log/S3 扫描通过，runtime 已恢复
   `persist/plaintext`。证据见
   `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`。

### P0（阻断生产启用）

1. 生产 pg_dump/pg_restore、灰度窗口与滚动部署未在正式环境演练。
2. CI 漏洞扫描（Rust/npm 生态）与依赖许可证批量核验未配置。
3. H5 严格 CSP、依赖锁定、WebCrypto 包装密钥的发布前检查未形成正式报告
   （KTD7 要求，当前依赖 R15 端侧实现与测试证据）。

### P1（发布后 30 天内跟进）

1. 日志 denylist 接入 pre-commit/CI，并沉淀白名单基线。
2. SBOM 生成命令固化进 CI 产物（`cargo metadata` / lockfile 归档）。
3. 备份恢复演练自动化（恢复后密文校验 SQL 转脚本）。
4. 设备能力字段对存量客户端的兼容期清理策略。

## 发布约束（裁决生效后）

- 生产：E2EE **No-Go**；`content_audit_mode` 保持 `plaintext`。
- 测试环境：允许 `prepare` 预检；`active` 需要安全审查显式批准且仅限演练
  窗口，演练后回滚 `plaintext`。
- 后续 Gate 重开条件：剩余 P0 三项全部关闭并出具复核报告。
- 后续唯一执行入口：
  `docs/plans/2026-08-05-u10-e2ee-production-release-closure-plan.md`。
