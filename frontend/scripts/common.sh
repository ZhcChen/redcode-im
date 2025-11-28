#!/bin/bash

# 通用函数库
# 被其他脚本 source 引用

# 读取 .env 文件并生成 dart-define 参数
# 用法: DART_DEFINES=$(load_env_as_dart_defines)
load_env_as_dart_defines() {
    local env_file="$1"
    local dart_defines=""

    # 如果没有指定文件，尝试默认位置
    if [ -z "$env_file" ]; then
        if [ -f ".env" ]; then
            env_file=".env"
        elif [ -f ".env.local" ]; then
            env_file=".env.local"
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
