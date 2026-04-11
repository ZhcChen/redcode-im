#!/bin/bash

# 通用函数库
# 被其他脚本 source 引用

DEFAULT_FLUTTER_DEVICE_ID="${DEFAULT_FLUTTER_DEVICE_ID:-3A091FDJG001DN}"
DEFAULT_FLUTTER_DEVICE_NAME="${DEFAULT_FLUTTER_DEVICE_NAME:-Pixel 8 Pro}"

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

build_local_backend_dart_defines() {
    local device_id="$1"
    local lan_ip=""

    if ! is_real_mobile_device "$device_id"; then
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

    device_label="$(describe_flutter_device "$device_id")"
    devices_output="$(flutter devices)"
    echo "$devices_output"

    if ! printf '%s\n' "$devices_output" | grep -Fq "$device_id"; then
        echo "" >&2
        echo "未找到目标设备: $device_label" >&2
        echo "请连接默认真机，或通过参数传入其他设备 ID。" >&2
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
