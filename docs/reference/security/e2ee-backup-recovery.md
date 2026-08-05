---
title: E2EE 备份恢复与灰度回滚演练手册
date: 2026-08-05
scope: im-test-1,production
status: partial
---

# E2EE 备份恢复与灰度回滚演练手册

## 适用范围

- 覆盖 R14/R15 的备份恢复与灰度回滚维度：PostgreSQL 数据备份/恢复、
  恢复后密文可读性验证、E2EE 灰度窗口与故障回滚。
- 本文档面向 `deploy/im-test-1` 测试环境（单机 PostgreSQL 17 容器）给出
  可重放命令；正式环境演练在 U7 裁决中列为 **No-Go 阻断项**，本文档提供
  检查清单，不伪造已执行结果。

## 1. 数据备份（im-test-1）

在服务器执行（避免密码出现在命令行历史，使用容器内已注入的环境变量）：

```bash
cd deploy/im-test-1
TS=$(date +%Y%m%d-%H%M%S)
docker compose exec -T postgres \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -Z 5' \
  > "backup-e2ee-${TS}.dump"
ls -lh "backup-e2ee-${TS}.dump"
```

校验备份文件完整性：

```bash
docker compose exec -T postgres \
  sh -c 'pg_restore -l /dev/stdin' < "backup-e2ee-${TS}.dump" > /dev/null
echo $?   # 0 表示归档可读
```

关键表与迁移链（恢复后用于抽查）：

- `e2ee_runtime_gate`（门禁状态，单行）
- `e2ee_devices`、`e2ee_key_packages`、`e2ee_control_messages`
- `messages`（`encrypted_content`/`encryption_metadata`）、`message_parts`
- `push_job_queue`（待处理 Push）

## 2. 数据恢复演练

恢复目标推荐先恢复到临时库验证，再决定是否替换主库。主库同库恢复流程：

```bash
cd deploy/im-test-1
# 停止 API 写入（保持 postgres 容器运行）
docker compose stop api

# 丢弃并重建库（仅测试环境；生产需先确认备份成功与维护窗口）
docker compose exec -T postgres \
  sh -c 'psql -U "$POSTGRES_USER" -d postgres \
    -c "DROP DATABASE IF EXISTS $POSTGRES_DB WITH (FORCE)" \
    -c "CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER"'

docker compose exec -T postgres \
  sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges -j 4' \
  < "backup-e2ee-${TS}.dump"

docker compose start api
curl -fsS https://im-test-1.codelib.cc/healthz
```

> 注意：`DROP DATABASE ... WITH (FORCE)` 只用于可丢弃的测试库；正式环境
> 恢复必须使用独立恢复主机或新库名，完成验证后再切换流量。

## 3. 恢复后密文验证清单

恢复完成后按序核对，任一失败即停止放行：

```bash
cd deploy/im-test-1
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
-- 门禁状态回到备份时点（plaintext/prepare/active 与 security_review_approved）
SELECT state, content_audit_mode, security_review_approved FROM e2ee_runtime_gate;
-- 设备与 KeyPackage 库存回滚后仍可服务
SELECT COUNT(*) AS devices FROM e2ee_devices WHERE status = 'active';
SELECT COUNT(*) AS key_packages FROM e2ee_key_packages WHERE consumed_at IS NULL;
-- 历史密文仍是 RCML envelope（前 4 字节），不得出现明文占位之外的正文
SELECT COUNT(*) AS rcml_messages
FROM messages
WHERE encrypted_content IS NOT NULL
  AND convert_from(encrypted_content, 'UTF8') IS NULL;
SQL
```

业务验证：

1. 用支持 E2EE 的客户端登录，进入恢复前有密文消息的房间，消息列表渲染
   为“加密消息”占位，不报密钥/状态损坏。
2. 发送一条新密文消息：`POST /rooms/{id}/messages/encrypted` 成功，且
   `messages.content` 仍为 `[加密消息]` 占位符。
3. 若备份时点为 `active`，旧客户端明文发送必须继续被 `40902` 拒绝；
   若为 `plaintext`，明文发送恢复。
4. 附件对象存储不在 pg_dump 范围内：恢复后需用 `mc` 或 S3 兼容客户端核对
   RustFS 私有桶对象存在性；对象缺失时 E2EE 附件应明确报“附件不可用”，
   不得退回明文。

## 4. 灰度窗口与回滚检查清单

### 灰度窗口（测试环境 im-test-1）

1. `POST /api/admin/settings/message-runtime/e2ee/prepare`：只做预检，不切换
   发送模式；核对 `readiness` 的设备覆盖、KeyPackage 库存与阻断原因。
2. 分批把客户端升级到支持 E2EE 的最低版本，再次 `prepare`，直到
   `ready=true` 且 `compliant_devices` 覆盖预期客户端。
3. `active`：服务端原子切换 `content_audit_mode=e2ee`；随后抽查新消息为
   密文链路、旧客户端发送被拒。

### 故障回滚（E2EE active 后发现问题）

1. 触发：`POST /api/admin/settings/message-runtime/e2ee/rollback`（原子，单事务）。
2. 验证：
   - `GET .../e2ee/gate` 返回 `state=plaintext`、
     `content_audit_mode=plaintext`。
   - 普通明文发送恢复；历史密文仍在且可被 E2EE 客户端读取。
   - 搜索/转发/Push 行为回到 plaintext 语义。
3. 若 rollback API 不可用（Admin 故障），应急序列：停止 API → 从最近
   备份恢复 `general_settings` 与 `e2ee_runtime_gate` 两表 → 启动 API →
   按第 3 节验证。

### 发布门禁（U7 记录，未执行）

- [ ] 生产环境 pg_dump 定时备份与异地存储（含恢复演练报告）
- [ ] 生产环境灰度窗口与滚动部署步骤在真实集群演练
- [ ] 恢复主机独立于主库，避免同机房故障域
- [ ] CI 漏洞扫描与许可证批量核验（见 `docs/reports/2026-08-05-e2ee-sbom.md`）

上述未勾选项作为 U7 No-Go 阻断项提交审查裁决，不宣称已通过。

## 5. 测试夹具清理（R15）

清理测试产生的账号/设备/密钥夹具有两个互补入口，均已核对：

1. **Admin 全量清理**
   - 入口：Admin 侧“运维/数据清理”页面
     （`admin/src/features/operations/pages/data-cleanup-page.vue`），
     调用 `POST /admin/data/cleanup/all`
     （`api/src/handlers/admin.rs` `cleanup_all_app_data`）。
   - 范围：用户业务数据（消息、房间、好友、E2EE 设备/KeyPackage/控制消息、
     旧 X3DH 预密钥表等）；保留系统配置（`general_settings`、
     `e2ee_runtime_gate`、存储/推送提供商配置、管理员账号）。
   - 适用：本地/测试库需要整体回到空白用户态时使用；因是全量清理，
     执行前必须确认目标环境允许清空用户数据。
2. **H5 live 定向清理脚本**
   - 入口：`tests/scripts/cleanup-e2ee-live-fixtures.sh [PREFIX]`，
     默认只删除 `username LIKE 'e2ee%'` 的账号。
   - 边界：PREFIX 为空或 `%` 时拒绝执行，防止误删非夹具数据；删除顺序
     先处理 `e2ee_control_messages`（RESTRICT 外键），再删房间与账号。
   - 适用：H5 E2EE live 联调（`h5-app/test/e2ee-live-backend.test.ts`）
     结束后清理账号夹具，避免污染后续联调。

回归保障：`api/tests/admin_e2ee_gate_integration.rs`
`admin_data_cleanup_removes_e2ee_user_fixtures_but_keeps_gate` 覆盖全量清理
后的 E2EE 表残留断言与门禁表保留断言。
