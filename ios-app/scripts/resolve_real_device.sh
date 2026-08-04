#!/usr/bin/env bash
set -euo pipefail

fail() {
  local code="$1"
  shift
  printf '[ios-app] %s\n' "$*" >&2
  exit "$code"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail 127 "缺少命令: $1"
}

require_cmd xcrun
require_cmd ruby

json_file="$(mktemp)"
log_file="$(mktemp)"
cleanup() {
  rm -f "$json_file" "$log_file"
}
trap cleanup EXIT

timeout_seconds="${IOS_APP_DEVICE_TIMEOUT_SECONDS:-10}"
if ! xcrun devicectl list devices \
  --timeout "$timeout_seconds" \
  --json-output "$json_file" >"$log_file" 2>&1; then
  cat "$log_file" >&2
  fail 65 "devicectl 列出设备失败。"
fi

set +e
resolved="$(
  ruby -rjson -e '
    data = JSON.parse(File.read(ARGV.fetch(0)))
    preferred = ENV.fetch("IOS_APP_DEVICE_ID", "").strip
    devices = data.dig("result", "devices") || []

    def string_values(value)
      case value
      when Hash
        value.flat_map { |_key, item| string_values(item) }
      when Array
        value.flat_map { |item| string_values(item) }
      when String
        [value]
      when Numeric, TrueClass, FalseClass
        [value.to_s]
      else
        []
      end
    end

    def find_by_key(value, keys)
      case value
      when Hash
        keys.each do |key|
          candidate = value[key]
          return candidate if candidate.is_a?(String) && !candidate.empty?
        end
        value.each_value do |item|
          candidate = find_by_key(item, keys)
          return candidate if candidate
        end
      when Array
        value.each do |item|
          candidate = find_by_key(item, keys)
          return candidate if candidate
        end
      end
      nil
    end

    if devices.empty?
      abort "__NO_DEVICES__"
    end

    selected = if preferred.empty?
      devices.find { |device| string_values(device).any? { |item| item.match?(/iphone/i) } }
    else
      devices.find { |device| string_values(device).include?(preferred) }
    end

    unless selected
      abort(preferred.empty? ? "__NO_IPHONE__" : "__MISSING_PREFERRED__")
    end

    puts(preferred.empty? ? (find_by_key(selected, %w[identifier udid serialNumber serial_number name]) || string_values(selected).first) : preferred)
  ' "$json_file" 2>&1
)"
resolve_status="$?"
set -e

if [[ "$resolve_status" -ne 0 ]]; then
  case "$resolved" in
  __NO_DEVICES__)
    cat "$log_file" >&2
    fail 65 "未检测到 iPhone 真机；APNs token 获取和系统离线通知无法在 Simulator 上完成。"
    ;;
  __NO_IPHONE__)
    cat "$log_file" >&2
    fail 65 "devicectl 未列出 iPhone 真机。"
    ;;
  __MISSING_PREFERRED__)
    cat "$log_file" >&2
    fail 65 "指定的 IOS_APP_DEVICE_ID 未连接: ${IOS_APP_DEVICE_ID:-}"
    ;;
  *)
    printf '%s\n' "$resolved" >&2
    fail 65 "解析 iPhone 真机失败。"
    ;;
  esac
fi

printf '%s\n' "$resolved"
