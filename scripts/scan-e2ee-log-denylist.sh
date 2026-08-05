#!/usr/bin/env bash
#
# U7-B: E2EE 日志敏感字段 denylist 静态扫描。
#
# 扫描 API/H5/Admin 的日志输出调用（Rust tracing/println 宏与前端
# console.*），拒绝在日志中记录根私钥、凭据、KeyPackage、DEK/nonce、
# 密文正文等字段名。误报可通过脚本内 ALLOW_PATTERNS 白名单收敛。
#
# 退出码：0 未命中（通过）；1 存在命中（阻断）。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_MACRO_RUST='(println!|eprintln!|print!|info!|warn!|error!|debug!|trace!)'
LOG_CALL_TS='console\.(log|info|warn|error|debug)'

# 敏感字段名：任何日志调用行中出现即视为潜在泄漏。
SENSITIVE_PATTERN='(root_private_key|private_key|root_secret|key_package|dek|nonce|encrypted_content|credential|root_fingerprint)'

# 白名单：整行匹配命中时跳过（收敛误报；命中记录会写入报告）。
ALLOW_PATTERNS=(
  # 示例：'#\[allow\].*encrypted_content'
)

RUST_FILES=()
while IFS= read -r file; do
  RUST_FILES+=("$file")
done < <(find "$ROOT/api/src" -name '*.rs' -type f 2>/dev/null | sort)

TS_FILES=()
while IFS= read -r file; do
  TS_FILES+=("$file")
done < <(find "$ROOT/h5-app/src" "$ROOT/admin/src" \( -name '*.ts' -o -name '*.vue' \) -type f 2>/dev/null | sort)

declare -a HITS=()
declare -a ALLOWED=()
log_line_count=0

scan_file() {
  local file="$1" mode="$2"
  local pattern
  if [[ "$mode" == "rust" ]]; then
    pattern="$LOG_MACRO_RUST"
  else
    pattern="$LOG_CALL_TS"
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log_line_count=$((log_line_count + 1))
    if ! grep -qiE "$SENSITIVE_PATTERN" <<<"$line"; then
      continue
    fi
    local allowed=0
    for allow in "${ALLOW_PATTERNS[@]}"; do
      if grep -qE "$allow" <<<"$line"; then
        allowed=1
        break
      fi
    done
    if [[ "$allowed" == "1" ]]; then
      ALLOWED+=("$line")
    else
      HITS+=("$line")
    fi
  done < <(rg -n "$pattern" "$file" || true)
}

for file in "${RUST_FILES[@]}"; do
  scan_file "$file" rust
done
for file in "${TS_FILES[@]}"; do
  scan_file "$file" ts
done

echo "== E2EE 日志 denylist 静态扫描 =="
echo "扫描文件: Rust ${#RUST_FILES[@]} 个，TS/Vue ${#TS_FILES[@]} 个"
echo "日志调用行: $log_line_count"
echo "白名单命中: ${#ALLOWED[@]}"
echo "敏感字段命中: ${#HITS[@]}"
if [[ ${#HITS[@]} -gt 0 ]]; then
  echo
  echo "!! 以下日志调用行可能泄漏敏感字段，请人工审查："
  printf '%s\n' "${HITS[@]}"
  exit 1
fi
echo
echo "结论: 通过（日志调用中未出现 denylist 敏感字段名）"
