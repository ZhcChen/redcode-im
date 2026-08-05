---
title: E2EE 备份恢复与灰度回滚演练手册
date: 2026-08-05
scope: im-test-1,production
status: maintained
test_environment_status: verified
production_verdict: no-go
---

# E2EE 备份恢复与灰度回滚演练手册

## 适用范围

- 覆盖 R14/R15 的备份恢复与灰度回滚维度：PostgreSQL 数据备份/恢复、
  恢复后密文可读性验证、E2EE 灰度窗口与故障回滚。
- 本文档面向 `deploy/im-test-1` 测试环境（单机 PostgreSQL 17 容器）给出
  可重放命令。2026-08-05 已完成测试环境独立恢复与灰度回滚演练，证据见
  `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md`；生产 E2EE 仍按
  `docs/plans/2026-08-06-u10-e2ee-g4-remediation-closure-plan.md` 保持 **No-Go**。

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
  sh -ec 'pg_restore -l >/dev/null' < "backup-e2ee-${TS}.dump"
# 命令返回 0 表示归档目录可读；非零必须立即停止恢复。
```

关键表与迁移链（恢复后用于抽查）：

- `e2ee_runtime_gate`（门禁状态，单行）
- `e2ee_devices`、`e2ee_key_packages`、`e2ee_control_messages`
- `messages`（`encrypted_content`/`encryption_metadata`）、`message_parts`
- `push_job_queue`（待处理 Push）

## 2. 数据恢复演练

恢复必须先进入独立 PostgreSQL 实例验证，禁止直接丢弃或覆盖当前主库。以下命令
与自动演练脚本使用相同的 PostgreSQL 17、TCP readiness 和归档恢复方式：

```bash
cd deploy/im-test-1
set -Eeuo pipefail

RESTORE_NAME="redcode-e2ee-restore-${TS}"
RESTORE_VOLUME="${RESTORE_NAME}-data"
RESTORE_DB=redcode_restore
RESTORE_USER=redcode_restore
RESTORE_PASSWORD=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')

cleanup_restore() {
  local exit_code=$?
  local containers volumes
  trap - EXIT INT TERM
  if ! containers=$(docker container ls -a --format '{{.Names}}'); then
    echo "无法查询 Docker 容器状态" >&2
    exit_code=1
  elif grep -Fxq "$RESTORE_NAME" <<<"$containers" &&
       ! docker rm -f "$RESTORE_NAME" >/dev/null; then
    echo "恢复容器删除失败：$RESTORE_NAME" >&2
    exit_code=1
  fi
  if ! volumes=$(docker volume ls -q); then
    echo "无法查询 Docker volume 状态" >&2
    exit_code=1
  elif grep -Fxq "$RESTORE_VOLUME" <<<"$volumes" &&
       ! docker volume rm "$RESTORE_VOLUME" >/dev/null; then
    echo "恢复 volume 删除失败：$RESTORE_VOLUME" >&2
    exit_code=1
  fi
  if ! containers=$(docker container ls -a --format '{{.Names}}') ||
     grep -Fxq "$RESTORE_NAME" <<<"$containers"; then
    echo "恢复容器清理后断言失败：$RESTORE_NAME" >&2
    exit_code=1
  fi
  if ! volumes=$(docker volume ls -q) ||
     grep -Fxq "$RESTORE_VOLUME" <<<"$volumes"; then
    echo "恢复 volume 清理后断言失败：$RESTORE_VOLUME" >&2
    exit_code=1
  fi
  exit "$exit_code"
}
trap cleanup_restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker volume create "$RESTORE_VOLUME" >/dev/null
docker run -d --name "$RESTORE_NAME" --network none \
  -e POSTGRES_DB="$RESTORE_DB" \
  -e POSTGRES_USER="$RESTORE_USER" \
  -e POSTGRES_PASSWORD="$RESTORE_PASSWORD" \
  -v "$RESTORE_VOLUME:/var/lib/postgresql/data" \
  postgres:17-alpine >/dev/null

ready=false
for _ in $(seq 1 60); do
  if docker exec "$RESTORE_NAME" pg_isready -h 127.0.0.1 \
    -U "$RESTORE_USER" -d "$RESTORE_DB" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
[[ "$ready" == true ]] || { echo "恢复 PostgreSQL 60 秒内未就绪" >&2; exit 1; }

docker exec -e PGPASSWORD="$RESTORE_PASSWORD" -i "$RESTORE_NAME" pg_restore \
  -h 127.0.0.1 -U "$RESTORE_USER" -d "$RESTORE_DB" \
  --no-owner --no-privileges < "backup-e2ee-${TS}.dump"

docker exec -e PGPASSWORD="$RESTORE_PASSWORD" -i "$RESTORE_NAME" \
  psql -v ON_ERROR_STOP=1 \
  -h 127.0.0.1 -U "$RESTORE_USER" -d "$RESTORE_DB" <<'SQL'
DO $$
DECLARE
  gate_count INTEGER;
  gate_state TEXT;
  audit_count INTEGER;
  audit_mode TEXT;
BEGIN
  SELECT COUNT(*), MIN(state) INTO gate_count, gate_state
  FROM e2ee_runtime_gate WHERE id = 1;
  SELECT COUNT(*), MIN(value) INTO audit_count, audit_mode
  FROM general_settings WHERE key = 'message_content_audit_mode';

  IF gate_count <> 1 OR gate_state NOT IN ('plaintext', 'prepare', 'active') THEN
    RAISE EXCEPTION 'e2ee_runtime_gate 单行配置缺失或非法';
  END IF;
  IF audit_count <> 1 OR audit_mode NOT IN ('plaintext', 'e2ee') THEN
    RAISE EXCEPTION 'message_content_audit_mode 单行配置缺失或非法';
  END IF;
  IF (gate_state = 'active' AND audit_mode <> 'e2ee') OR
     (gate_state IN ('plaintext', 'prepare') AND audit_mode <> 'plaintext') THEN
    RAISE EXCEPTION 'gate state 与 content audit mode 不一致';
  END IF;

  IF EXISTS (
    SELECT 1 FROM messages
    WHERE encrypted_content IS NOT NULL
      AND (
        octet_length(encrypted_content) < 11 OR
        substring(encrypted_content FROM 1 FOR 4) <> decode('52434d4c', 'hex') OR
        (get_byte(encrypted_content, 4) * 256 + get_byte(encrypted_content, 5)) <> 1 OR
        get_byte(encrypted_content, 6) NOT IN (1, 2, 3) OR
        (get_byte(encrypted_content, 7)::BIGINT * 16777216 +
         get_byte(encrypted_content, 8)::BIGINT * 65536 +
         get_byte(encrypted_content, 9)::BIGINT * 256 +
         get_byte(encrypted_content, 10)::BIGINT) > 16777216 OR
        octet_length(encrypted_content) <> 11 +
          (get_byte(encrypted_content, 7)::BIGINT * 16777216 +
           get_byte(encrypted_content, 8)::BIGINT * 65536 +
           get_byte(encrypted_content, 9)::BIGINT * 256 +
           get_byte(encrypted_content, 10)::BIGINT) OR
        encryption_metadata IS NULL OR
        jsonb_typeof(encryption_metadata) <> 'object' OR
        (encryption_metadata - ARRAY[
          'protocol', 'version', 'epoch', 'sender_device_id',
          'content_type', 'control_message_id'
        ]::TEXT[]) <> '{}'::JSONB OR
        NOT (encryption_metadata ? 'protocol') OR
        NOT (encryption_metadata ? 'version') OR
        NOT (encryption_metadata ? 'epoch') OR
        NOT (encryption_metadata ? 'sender_device_id') OR
        NOT (encryption_metadata ? 'content_type') OR
        jsonb_typeof(encryption_metadata->'protocol') <> 'string' OR
        jsonb_typeof(encryption_metadata->'version') <> 'number' OR
        jsonb_typeof(encryption_metadata->'epoch') <> 'number' OR
        jsonb_typeof(encryption_metadata->'sender_device_id') <> 'string' OR
        jsonb_typeof(encryption_metadata->'content_type') <> 'string' OR
        (encryption_metadata ? 'control_message_id' AND
          encryption_metadata->'control_message_id' <> 'null'::JSONB AND
          jsonb_typeof(encryption_metadata->'control_message_id') <> 'string') OR
        encryption_metadata->>'protocol' <> 'mls' OR
        (encryption_metadata->>'version')::INTEGER <> 1 OR
        (encryption_metadata->>'epoch')::BIGINT <= 0 OR
        (encryption_metadata->>'sender_device_id')::UUID =
          '00000000-0000-0000-0000-000000000000'::UUID OR
        (encryption_metadata ? 'control_message_id' AND
          encryption_metadata->'control_message_id' <> 'null'::JSONB AND
          (encryption_metadata->>'control_message_id')::UUID IS NULL) OR
        NOT (
          (get_byte(encrypted_content, 6) = 1 AND
            encryption_metadata->>'content_type' = 'application') OR
          (get_byte(encrypted_content, 6) = 2 AND
            encryption_metadata->>'content_type' = 'commit') OR
          (get_byte(encrypted_content, 6) = 3 AND
            encryption_metadata->>'content_type' = 'welcome')
        )
      )
  ) THEN
    RAISE EXCEPTION '存在结构无效的 RCML encrypted_content';
  END IF;
END
$$;

SELECT state, required_coverage_percent, key_package_low_watermark,
       security_review_approved
FROM e2ee_runtime_gate WHERE id = 1;
SELECT value AS content_audit_mode
FROM general_settings WHERE key = 'message_content_audit_mode';
SELECT COUNT(*) AS active_devices FROM e2ee_devices WHERE status = 'active';
SELECT COUNT(*) AS available_key_packages FROM e2ee_key_packages
WHERE consumed_at IS NULL AND expires_at > NOW();
SELECT COUNT(*) AS structurally_valid_rcml_messages FROM messages
WHERE encrypted_content IS NOT NULL;
SQL
```

上述 shell 单元无论成功、失败或收到 `INT`/`TERM` 都会删除恢复容器和 volume，
并在退出前断言资源不存在。测试环境完整自动演练入口为
`deploy/im-test-1/e2ee-backup-rollout-drill.sh full`；执行前必须按脚本 preflight
设置管理员 token 和显式停机授权。该脚本的外部状态探测与信号边界加固由 active
计划 U3 管理，本节不将其标记为已关闭。

## 3. 恢复后密文验证清单

SQL 结构验证只能证明归档内 envelope 与 metadata 结构合法，不能替代隔离恢复 API
和真实客户端解密。恢复 API 建立后按序核对，任一失败即停止放行：

业务验证：

1. 用支持 E2EE 的客户端登录，进入恢复前有密文消息的房间，客户端必须解密并
   显示恢复前正文；只显示“加密消息”占位不能证明恢复成功。
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

### 当前发布门禁

- [x] `im-test-1` custom-format 备份、损坏归档拒绝和独立 PostgreSQL 17 恢复。
- [x] `im-test-1` `prepare -> active -> rollback` 与 API recreate 演练。
- [x] 六端 SBOM、漏洞和许可证扫描门禁。
- [ ] 在独立恢复 API 上完成 Android、iOS、H5 历史解密、新消息、撤销设备和
  附件授权 live 验收，并形成可持久复核的脱敏证据。
- [ ] G4 整改后四视角复审、真实 release workflow、全量与 live 门禁通过。

未勾选项由 active G4 计划管理；全部关闭前不得启用生产 E2EE。

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
