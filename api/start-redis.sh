#!/bin/bash

# Redis 单实例启动脚本
# 用于 redcode-im 项目的宿主机本地调试环境

echo "🚀 启动 Redis 单实例开发环境..."

# 检查Redis是否已安装
if ! command -v redis-server &> /dev/null; then
    echo "❌ Redis未安装，请先安装Redis"
    echo "macOS: brew install redis"
    echo "Ubuntu: sudo apt-get install redis-server"
    exit 1
fi

REDIS_PORT="${REDIS_PORT:-6381}"
REDIS_NAME="redcode-local"
REDIS_CONFIG="--appendonly yes --save 900 1 --save 300 10 --save 60 10000 --maxmemory 256mb --maxmemory-policy allkeys-lru"

# 函数：本地启动 Redis 实例
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

# 函数：停止本地 Redis 实例
stop_redis_instances() {
    echo "🛑 停止本地 Redis 实例..."

    pkill -f "redis-server.*$REDIS_PORT" || true

    echo "✅ 本地 Redis 实例已停止"
}

# 函数：检查 Redis 实例状态
check_redis_status() {
    echo "📊 检查 Redis 实例状态..."

    if redis-cli -p "$REDIS_PORT" ping >/dev/null 2>&1; then
        echo "✅ Redis $REDIS_PORT: 运行正常"
    else
        echo "❌ Redis $REDIS_PORT: 未运行"
    fi
}

# 处理命令行参数
case "${1:-start}" in
    start)
        start_redis_local "$REDIS_PORT" "$REDIS_CONFIG" "$REDIS_NAME"

        echo ""
        echo "🎉 Redis 单实例启动完成！"
        echo "📝 本地端口: $REDIS_PORT"
        echo "📝 api 三个逻辑入口可统一指向:"
        echo "   REDIS_SESSION_URL=redis://localhost:$REDIS_PORT"
        echo "   REDIS_PUBSUB_URL=redis://localhost:$REDIS_PORT"
        echo "   REDIS_CACHE_URL=redis://localhost:$REDIS_PORT"
        echo ""
        echo "💡 使用 './start-redis.sh status' 检查状态"
        echo "💡 使用 './start-redis.sh stop' 停止实例"
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
        echo "请查看 Redis 日志文件位置: ./redis-data/$REDIS_NAME/redis.log"
        ;;

    help)
        echo "Redis 单实例管理脚本"
        echo ""
        echo "用法: REDIS_PORT=6381 $0 [命令]"
        echo ""
        echo "命令:"
        echo "  start   - 启动 Redis 实例 (默认)"
        echo "  stop    - 停止 Redis 实例"
        echo "  restart - 重启 Redis 实例"
        echo "  status  - 检查 Redis 实例状态"
        echo "  logs    - 查看 Redis 日志"
        echo "  help    - 显示此帮助信息"
        ;;

    *)
        echo "❌ 未知命令: $1"
        echo "💡 使用 '$0 help' 查看帮助"
        exit 1
        ;;
esac
