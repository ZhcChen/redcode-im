#!/bin/bash

# Redis多实例启动脚本
# 用于redcode-im项目的Redis开发环境

echo "🚀 启动Redis多实例开发环境..."

# 检查Redis是否已安装
if ! command -v redis-server &> /dev/null; then
    echo "❌ Redis未安装，请先安装Redis"
    echo "macOS: brew install redis"
    echo "Ubuntu: sudo apt-get install redis-server"
    exit 1
fi

# 检查Docker是否可用（备选方案）
USE_DOCKER=false
if command -v docker-compose &> /dev/null && docker-compose --version &> /dev/null; then
    USE_DOCKER=true
fi

# 函数：启动单个Redis实例
start_redis_instance() {
    local port=$1
    local config=$2
    local name=$3

    echo "📍 启动 $name (端口: $port)"

    if [ "$USE_DOCKER" = true ]; then
        # 使用Docker启动
        docker-compose -f docker-compose-redis.yml up -d redis-$name 2>/dev/null || {
            echo "⚠️  Docker启动失败，尝试本地启动..."
            start_redis_local "$port" "$config" "$name"
        }
    else
        # 本地启动
        start_redis_local "$port" "$config" "$name"
    fi
}

# 函数：本地启动Redis实例
start_redis_local() {
    local port=$1
    local config=$2
    local name=$3

    # 检查端口是否被占用
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo "⚠️  端口 $port 已被占用，跳过 $name"
        return 0
    fi

    # 创建数据目录
    mkdir -p ./redis-data/$name

    # 启动Redis实例
    redis-server --port $port $config --daemonize yes --dir ./redis-data/$name
    if [ $? -eq 0 ]; then
        echo "✅ $name 启动成功"
    else
        echo "❌ $name 启动失败"
        return 1
    fi
}

# 函数：停止所有Redis实例
stop_redis_instances() {
    echo "🛑 停止所有Redis实例..."

    if [ "$USE_DOCKER" = true ]; then
        docker-compose -f docker-compose-redis.yml down
    fi

    # 停止本地Redis实例
    pkill -f "redis-server.*6379"
    pkill -f "redis-server.*6381"
    pkill -f "redis-server.*6383"

    echo "✅ 所有Redis实例已停止"
}

# 函数：检查Redis实例状态
check_redis_status() {
    echo "📊 检查Redis实例状态..."

    for port in 6379 6381 6383; do
        if redis-cli -p $port ping >/dev/null 2>&1; then
            echo "✅ Redis $port: 运行正常"
        else
            echo "❌ Redis $port: 未运行"
        fi
    done
}

# 处理命令行参数
case "${1:-start}" in
    start)
        echo "🔧 启动模式: $([ "$USE_DOCKER" = true ] && echo "Docker" || echo "本地")"

        # 启动主Redis
        start_redis_instance 6379 "--appendonly yes" "main"

        # 启动Session Redis
        start_redis_instance 6381 \
            "--appendonly yes --save 900 1 --save 300 10 --save 60 10000 --maxmemory 128mb --maxmemory-policy volatile-lru" \
            "session"

        # 启动Cache Redis
        start_redis_instance 6383 \
            "--maxmemory 512mb --maxmemory-policy allkeys-lru --save \"\"" \
            "cache"

        echo ""
        echo "🎉 Redis多实例启动完成！"
        echo "📝 端口映射:"
        echo "   - 主Redis:      6379 (标准模式)"
        echo "   - Session Redis: 6381 (持久化模式)"
        echo "   - Cache Redis:   6383 (纯缓存模式)"
        echo ""
        echo "💡 使用 './start-redis.sh status' 检查状态"
        echo "💡 使用 './start-redis.sh stop' 停止所有实例"
        ;;

    stop)
        stop_redis_instances
        ;;

    restart)
        stop_redis_instances
        sleep 2
        exec $0 start
        ;;

    status)
        check_redis_status
        ;;

    logs)
        if [ "$USE_DOCKER" = true ]; then
            docker-compose -f docker-compose-redis.yml logs -f
        else
            echo "请查看Redis日志文件位置: ./redis-data/*/redis.log"
        fi
        ;;

    help)
        echo "Redis多实例管理脚本"
        echo ""
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  start   - 启动所有Redis实例 (默认)"
        echo "  stop    - 停止所有Redis实例"
        echo "  restart - 重启所有Redis实例"
        echo "  status  - 检查Redis实例状态"
        echo "  logs    - 查看Redis日志"
        echo "  help    - 显示此帮助信息"
        ;;

    *)
        echo "❌ 未知命令: $1"
        echo "💡 使用 '$0 help' 查看帮助"
        exit 1
        ;;
esac
