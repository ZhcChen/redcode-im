#!/usr/bin/env bash
#
# 清理 E2EE live 测试产生的账号夹具（R15 / KTD7）。
# 只删除可识别前缀（默认 e2ee%）的测试账号，禁止无前缀清理。
#
# 用法：
#   DATABASE_URL=postgres://... ./tests/scripts/cleanup-e2ee-live-fixtures.sh [PREFIX]
#
set -euo pipefail

prefix="${1:-e2ee%}"
if [[ "$prefix" == "%" || "$prefix" == "" ]]; then
  echo "拒绝执行无界清理：PREFIX 不能为空或 %" >&2
  exit 1
fi
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "缺少 DATABASE_URL" >&2
  exit 1
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
-- 先清理可能引用目标用户设备的控制消息，避免 e2ee_control_messages
-- sender_device_id ON DELETE RESTRICT 阻断用户删除。
DELETE FROM e2ee_control_messages
WHERE sender_device_id IN (
  SELECT device.id
  FROM e2ee_devices AS device
  JOIN users AS account ON account.id = device.user_id
  WHERE account.username LIKE '$prefix'
);

-- 清理目标用户拥有的房间（级联 epoch / 控制消息 / 成员关系）。
DELETE FROM rooms
WHERE owner_id IN (
  SELECT id FROM users WHERE username LIKE '$prefix'
);

-- 删除账号本体（级联设备、KeyPackage、身份、好友、消息等）。
DELETE FROM users
WHERE username LIKE '$prefix';
SQL

echo "已清理 username LIKE '$prefix' 的 E2EE live 夹具"
