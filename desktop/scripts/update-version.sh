#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "用法: $(basename "$0") <version>" >&2
  exit 1
fi

NEW_VERSION="$1"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DESKTOP_DIR/.." && pwd)"

replace_regex() {
  local file="$1"
  local pattern="$2"
  local replacement_template="$3"
  python3 - <<'PY' "$file" "$pattern" "$replacement_template" "$NEW_VERSION"
import re, sys, pathlib
file, pattern, template, version = sys.argv[1:5]
path = pathlib.Path(file)
text = path.read_text()
replacement = template.replace('{version}', version)
new_text, count = re.subn(pattern, replacement, text, count=1)
if count == 0:
    raise SystemExit(f"未在 {file} 中找到可替换的内容")
path.write_text(new_text)
PY
}

replace_regex "$DESKTOP_DIR/package.json" '"version":\s*".*?"' '"version": "{version}"'
replace_regex "$DESKTOP_DIR/src-tauri/tauri.conf.json" '"version":\s*".*?"' '"version": "{version}"'
replace_regex "$DESKTOP_DIR/src-tauri/Cargo.toml" '(?m)^version\s*=\s*".*?"' 'version = "{version}"'
replace_regex "$DESKTOP_DIR/src/api/config.ts" "const DEFAULT_APP_VERSION = '.*?'" "const DEFAULT_APP_VERSION = '{version}'"
replace_regex "$DESKTOP_DIR/scripts/build-macos.sh" 'VERSION=\$\{VITE_APP_VERSION:-\$\{APP_VERSION:-".*?"\}\}' 'VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"{version}"}}'
replace_regex "$DESKTOP_DIR/scripts/build-linux.sh" 'VERSION=\$\{VITE_APP_VERSION:-\$\{APP_VERSION:-".*?"\}\}' 'VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"{version}"}}'
replace_regex "$REPO_ROOT/AGENTS.md" '当前版本为 `.*?`' '当前版本为 `{version}`'

python3 - <<'PY' "$DESKTOP_DIR/src-tauri/Cargo.lock" "$NEW_VERSION"
import pathlib, re, sys
lock_path = pathlib.Path(sys.argv[1])
new_version = sys.argv[2]
text = lock_path.read_text()
pattern = r'(name = "redcode-im-desktop"\nversion = )"[^"]+"'
replacement = r'\1"' + new_version + '"'
new_text, count = re.subn(pattern, replacement, text, count=1)
if count == 0:
    raise SystemExit("未在 Cargo.lock 中找到 redcode-im-desktop 版本字段")
lock_path.write_text(new_text)
PY

echo "已将版本号更新为 ${NEW_VERSION}"
