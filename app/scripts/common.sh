#!/bin/bash

# 通用函数库
# 被其他脚本 source 引用

DEFAULT_FLUTTER_DEVICE_ID="${DEFAULT_FLUTTER_DEVICE_ID:-3A091FDJG001DN}"
DEFAULT_FLUTTER_DEVICE_NAME="${DEFAULT_FLUTTER_DEVICE_NAME:-Pixel 8 Pro}"
FLUTTER_DEVICES_TIMEOUT_SECONDS="${FLUTTER_DEVICES_TIMEOUT_SECONDS:-20}"
SIMCTL_TIMEOUT_SECONDS="${SIMCTL_TIMEOUT_SECONDS:-20}"

kill_process_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    local child

    for child in $(pgrep -P "$pid" 2>/dev/null || true); do
        kill_process_tree "$child" "$signal"
    done

    kill "-$signal" "$pid" 2>/dev/null || true
}

run_with_timeout() {
    local timeout_seconds="$1"
    shift

    local output_file
    local status_file
    local pid
    local elapsed=0
    local status=0

    output_file="$(mktemp "${TMPDIR:-/tmp}/redcode-command-output.XXXXXX")"
    status_file="$(mktemp "${TMPDIR:-/tmp}/redcode-command-status.XXXXXX")"

    (
        "$@" >"$output_file" 2>&1
        echo "$?" >"$status_file"
    ) &
    pid="$!"

    while kill -0 "$pid" 2>/dev/null; do
        if [ "$elapsed" -ge "$timeout_seconds" ]; then
            kill_process_tree "$pid" TERM
            sleep 1
            kill_process_tree "$pid" KILL
            wait "$pid" 2>/dev/null || true
            cat "$output_file"
            rm -f "$output_file" "$status_file"
            return 124
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$pid" 2>/dev/null || true
    if [ -s "$status_file" ]; then
        status="$(cat "$status_file")"
    else
        status=1
    fi

    cat "$output_file"
    rm -f "$output_file" "$status_file"
    return "$status"
}

flutter_devices_output() {
    local output
    local status=0

    if output="$(run_with_timeout "$FLUTTER_DEVICES_TIMEOUT_SECONDS" flutter devices)"; then
        status=0
    else
        status="$?"
        if [ "$status" -eq 124 ]; then
            echo "flutter devices 超过 ${FLUTTER_DEVICES_TIMEOUT_SECONDS}s 未返回，跳过本次设备枚举。" >&2
        fi
    fi

    printf '%s\n' "$output"
    return "$status"
}

simctl_devices_output() {
    local output
    local status=0

    if output="$(run_with_timeout "$SIMCTL_TIMEOUT_SECONDS" xcrun simctl list devices available)"; then
        status=0
    else
        status="$?"
        if [ "$status" -eq 124 ]; then
            echo "xcrun simctl list devices available 超过 ${SIMCTL_TIMEOUT_SECONDS}s 未返回。" >&2
        fi
    fi

    printf '%s\n' "$output"
    return "$status"
}

find_flutter_device_line() {
    local device_id="$1"
    local devices_output
    local devices_status=0

    [ -n "$device_id" ] || return 0

    if devices_output="$(flutter_devices_output)"; then
        devices_status=0
    else
        devices_status="$?"
    fi

    [ "$devices_status" -eq 0 ] || return 0
    printf '%s\n' "$devices_output" | awk -v id="$device_id" '
        index($0, id) && !found {
            line=$0
            found=1
        }
        END {
            if (found) {
                print line
            }
        }
    '
}

find_simctl_device_line() {
    local device_id="$1"
    local devices_output
    local devices_status=0

    [ -n "$device_id" ] || return 0

    if devices_output="$(simctl_devices_output)"; then
        devices_status=0
    else
        devices_status="$?"
    fi

    [ "$devices_status" -eq 0 ] || return 0
    printf '%s\n' "$devices_output" | awk -v id="$device_id" '
        index($0, id) && !/unavailable/ && !found {
            print
            found=1
        }
    '
}

is_flutter_device_available() {
    local device_id="$1"

    [ -n "$(find_flutter_device_line "$device_id")" ]
}

find_first_ios_simulator_device() {
    local simulator_id
    local devices_output
    local devices_status=0

    if devices_output="$(flutter_devices_output)"; then
        devices_status=0
    else
        devices_status="$?"
    fi

    if [ "$devices_status" -eq 0 ]; then
        simulator_id="$(printf '%s\n' "$devices_output" | awk -F '•' '
        /\(simulator\)/ && / ios[[:space:]]*•/ && !found {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            device_id=$2
            found=1
        }
        END {
            if (found) {
                print device_id
            }
        }
        ')"
        if [ -n "$simulator_id" ]; then
            echo "$simulator_id"
            return 0
        fi
    fi

    find_first_ios_simulator_device_from_simctl
}

find_first_ios_simulator_device_from_simctl() {
    local devices_output
    local devices_status=0

    if devices_output="$(simctl_devices_output)"; then
        devices_status=0
    else
        devices_status="$?"
    fi

    [ "$devices_status" -eq 0 ] || return 0
    printf '%s\n' "$devices_output" | awk '
        /^-- / {
            in_ios = ($0 ~ /^-- iOS/)
            next
        }
        in_ios && /iPhone/ && !/unavailable/ {
            split($0, parts, "(")
            for (i = 2; i <= length(parts); i++) {
                candidate = parts[i]
                sub(/\).*/, "", candidate)
                if (candidate ~ /^[0-9A-Fa-f-]{36}$/) {
                    print candidate
                    exit
                }
            }
        }
    '
}

resolve_frontend_acceptance_device() {
    local requested_device_id="${1:-$DEFAULT_FLUTTER_DEVICE_ID}"
    local simulator_id=""

    if is_flutter_device_available "$requested_device_id"; then
        echo "$requested_device_id"
        return 0
    fi

    if [ "$requested_device_id" = "$DEFAULT_FLUTTER_DEVICE_ID" ]; then
        simulator_id="$(find_first_ios_simulator_device)"
        if [ -n "$simulator_id" ]; then
            echo "未检测到默认真机 ${DEFAULT_FLUTTER_DEVICE_NAME} (${DEFAULT_FLUTTER_DEVICE_ID})，切换到本机 iOS Simulator: ${simulator_id}" >&2
            echo "$simulator_id"
            return 0
        fi
    fi

    echo "$requested_device_id"
}

get_current_lan_ip() {
    local iface=""
    local ip=""

    iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    if [ -n "$iface" ]; then
        ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
    fi

    if [ -z "$ip" ]; then
        return 1
    fi

    echo "$ip"
}

is_real_mobile_device() {
    local device_id="$1"

    if is_flutter_simulator_device "$device_id" || is_ios_simulator_device "$device_id"; then
        return 1
    fi

    case "$device_id" in
        emulator-*|ios_simulator|macos|chrome|edge|web-server|linux|windows)
            return 1
            ;;
        *simulator*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

is_flutter_simulator_device() {
    local device_id="$1"
    local device_line

    device_line="$(find_flutter_device_line "$device_id")"
    [[ "$device_line" == *"(simulator)"* ]]
}

is_ios_simulator_device() {
    local device_id="$1"

    [ -n "$(find_simctl_device_line "$device_id")" ]
}

is_android_emulator_device() {
    local device_id="$1"

    [[ "$device_id" == emulator-* ]]
}

build_local_backend_dart_defines() {
    local device_id="$1"
    local lan_ip=""

    if ! is_real_mobile_device "$device_id"; then
        if is_flutter_simulator_device "$device_id"; then
            echo " --dart-define=API_BASE_URL=http://127.0.0.1:8010 --dart-define=WS_URL=ws://127.0.0.1:8010/ws"
            return 0
        fi

        if is_android_emulator_device "$device_id"; then
            echo " --dart-define=API_BASE_URL=http://10.0.2.2:8010 --dart-define=WS_URL=ws://10.0.2.2:8010/ws"
        fi
        return 0
    fi

    lan_ip=$(get_current_lan_ip) || {
        echo "无法检测当前局域网 IP，请检查本机网络。" >&2
        return 1
    }

    echo "📡 检测到当前局域网 IP: ${lan_ip}" >&2
    echo " --dart-define=API_BASE_URL=http://${lan_ip}:8010 --dart-define=WS_URL=ws://${lan_ip}:8010/ws"
}

describe_flutter_device() {
    local device_id="$1"
    local device_line=""
    local simctl_line=""

    device_line="$(find_flutter_device_line "$device_id")"
    if [ -n "$device_line" ]; then
        echo "$device_line" | awk -F '•' -v id="$device_id" '{
            name=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            print name " (" id ")"
        }'
        return
    fi

    simctl_line="$(find_simctl_device_line "$device_id")"
    if [ -n "$simctl_line" ]; then
        printf '%s\n' "$simctl_line" | sed -E "s/^[[:space:]]*//; s/[[:space:]]*\\(${device_id}\\).*//"
        printf ' (%s)\n' "$device_id"
        return
    fi

    if [ "$device_id" = "$DEFAULT_FLUTTER_DEVICE_ID" ]; then
        echo "${DEFAULT_FLUTTER_DEVICE_NAME} (${device_id})"
        return
    fi

    echo "$device_id"
}

show_and_verify_flutter_devices() {
    local device_id="$1"
    local device_label
    local devices_output
    local devices_status=0

    device_label="$(describe_flutter_device "$device_id")"
    if devices_output="$(flutter_devices_output)"; then
        devices_status=0
    else
        devices_status="$?"
    fi
    echo "$devices_output"

    if ! printf '%s\n' "$devices_output" | grep -Fq "$device_id"; then
        if [ "$devices_status" -ne 0 ] && [ "$device_id" = "macos" ]; then
            echo "" >&2
            echo "flutter devices 未能完成，macOS 本机目标跳过设备枚举验证。" >&2
            return 0
        fi

        if [ "$devices_status" -ne 0 ] && is_ios_simulator_device "$device_id"; then
            echo "" >&2
            echo "flutter devices 未能完成，已通过 simctl 验证本机 iOS Simulator: $device_label" >&2
            return 0
        fi

        echo "" >&2
        echo "未找到目标设备: $device_label" >&2
        echo "请连接目标设备，启动本机 iOS Simulator，或通过参数传入其他设备 ID。" >&2
        return 1
    fi
}

# 读取 .env 文件并生成 dart-define 参数
# 用法: DART_DEFINES=$(load_env_as_dart_defines)
load_env_as_dart_defines() {
    local env_file="$1"
    local dart_defines=""

    # 如果没有指定文件，尝试默认位置
    if [ -z "$env_file" ]; then
        if [ -f ".env.development" ]; then
            env_file=".env.development"
        elif [ -f ".env.production" ]; then
            env_file=".env.production"
        fi
    fi

    # 如果文件存在，读取配置
    if [ -f "$env_file" ]; then
        echo "📄 读取配置文件: $env_file" >&2

        while IFS='=' read -r key value || [ -n "$key" ]; do
            # 跳过空行和注释
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

            # 去除前后空格
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            # 跳过空值
            [ -z "$value" ] && continue

            # 添加到 dart-define 参数
            dart_defines="$dart_defines --dart-define=$key=$value"
        done < "$env_file"
    fi

    echo "$dart_defines"
}

# 从 .env 文件读取单个变量
# 用法: value=$(get_env_value "API_BASE_URL" "default_value")
get_env_value() {
    local key="$1"
    local default="$2"
    local env_file="${3:-.env}"

    if [ -f "$env_file" ]; then
        local value=$(grep "^$key=" "$env_file" 2>/dev/null | cut -d'=' -f2- | xargs)
        if [ -n "$value" ]; then
            echo "$value"
            return
        fi
    fi

    echo "$default"
}

# 显示当前配置信息
show_env_info() {
    local env_file="${1:-.env}"

    echo "╔══════════════════════════════════════════╗"
    echo "║          🌍 当前环境配置                  ║"
    echo "╠══════════════════════════════════════════╣"

    if [ -f "$env_file" ]; then
        local env=$(get_env_value "ENV" "development" "$env_file")
        local api=$(get_env_value "API_BASE_URL" "" "$env_file")
        local ws=$(get_env_value "WS_URL" "" "$env_file")
        local debug=$(get_env_value "ENABLE_DEBUG_LOG" "true" "$env_file")

        echo "║  配置文件: $env_file"
        echo "║  环境: $env"
        [ -n "$api" ] && echo "║  API: $api"
        [ -n "$ws" ] && echo "║  WS:  $ws"
        echo "║  调试: $debug"
    else
        echo "║  未找到 .env 文件，使用默认配置"
    fi

    echo "╚══════════════════════════════════════════╝"
}
