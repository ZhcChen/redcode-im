#!/bin/bash

# Docker Compose环境启动脚本
# 用于redcode-im项目的完整环境启动

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2:-$GREEN}🚀 $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查Docker和Docker Compose
check_docker() {
    print_info "检查Docker环境..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi

    print_message "Docker环境检查通过"
}

# 创建必要的目录
setup_directories() {
    print_info "创建必要的目录..."

    mkdir -p ./data/postgres
    mkdir -p ./data/redis/main
    mkdir -p ./data/redis/session
    mkdir -p ./data/redis/streams
    mkdir -p ./logs

    print_message "目录创建完成"
}

# 启动服务
start_services() {
    local profile=${1:-default}

    print_message "启动redcode-im服务环境..."
    print_info "Profile: $profile"

    if [ "$profile" = "with-tools" ]; then
        docker-compose --profile tools up -d
    else
        docker-compose up -d
    fi

    print_message "服务启动中..."
}

# 检查服务状态
check_services() {
    print_info "检查服务状态..."

    # 检查PostgreSQL
    if docker-compose exec -T postgres pg_isready -U postgres &> /dev/null; then
        print_message "PostgreSQL: 运行正常"
    else
        print_warning "PostgreSQL: 启动中或未就绪"
    fi

    # 检查Redis实例
    for port in 6381 6382 6383; do
        if docker-compose exec -T redis-session redis-cli -p $port ping &> /dev/null 2>&1; then
            print_message "Redis $port: 运行正常"
        else
            print_warning "Redis $port: 启动中或未就绪"
        fi
    done

    # 检查后端服务
    if curl -f http://localhost:8080/healthz &> /dev/null 2>&1; then
        print_message "Backend: 运行正常"
    else
        print_warning "Backend: 启动中或未就绪"
    fi
}

# 显示服务信息
show_info() {
    print_message "redcode-im环境信息"
    echo "=========================="
    echo "📍 服务地址:"
    echo "   - 后端API: http://localhost:8080"
    echo "   - 健康检查: http://localhost:8080/healthz"
    echo "   - PostgreSQL: localhost:5432"
    echo "   - Redis会话: localhost:6381"
    echo "   - Redis流:   localhost:6382"
    echo "   - Redis缓存: localhost:6383"
    echo ""
    echo "🛠️  管理工具 (with-tools profile):"
    echo "   - PgAdmin: http://localhost:5050"
    echo "   - 用户名: admin@redcode.im"
    echo "   - 密码: admin"
    echo ""
    echo "📋 常用命令:"
    echo "   - 查看日志: docker-compose logs -f [service]"
    echo "   - 停止服务: docker-compose down"
    echo "   - 重启服务: docker-compose restart [service]"
    echo "   - 进入容器: docker-compose exec [service] sh"
    echo ""
    echo "💡 Redis CLI:"
    echo "   docker-compose exec redis-session redis-cli -p 6381"
    echo "   docker-compose exec redis-streams redis-cli -p 6382"
    echo "   docker-compose exec redis-cache redis-cli -p 6383"
}

# 显示日志
show_logs() {
    local service=${1:-}

    if [ -n "$service" ]; then
        docker-compose logs -f "$service"
    else
        docker-compose logs -f
    fi
}

# 停止服务
stop_services() {
    print_message "停止所有服务..."
    docker-compose down
    print_message "服务已停止"
}

# 重启服务
restart_services() {
    print_message "重启服务..."
    docker-compose restart
    print_message "服务重启完成"
}

# 清理环境
cleanup() {
    print_warning "清理Docker环境..."
    docker-compose down -v --remove-orphans
    docker system prune -f
    print_message "环境清理完成"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            check_docker
            setup_directories
            start_services
            sleep 5
            check_services
            show_info
            ;;
        start-with-tools)
            check_docker
            setup_directories
            start_services "with-tools"
            sleep 5
            check_services
            show_info
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            check_services
            ;;
        logs)
            show_logs "$2"
            ;;
        info)
            show_info
            ;;
        cleanup)
            cleanup
            ;;
        help)
            echo "Docker Compose环境管理脚本"
            echo ""
            echo "用法: $0 [命令] [参数]"
            echo ""
            echo "命令:"
            echo "  start           - 启动基础服务 (默认)"
            echo "  start-with-tools - 启动包含管理工具的服务"
            echo "  stop            - 停止所有服务"
            echo "  restart         - 重启所有服务"
            echo "  status          - 检查服务状态"
            echo "  logs [service]  - 查看服务日志"
            echo "  info            - 显示服务信息"
            echo "  cleanup         - 清理Docker环境"
            echo "  help            - 显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 start                    # 启动基础服务"
            echo "  $0 start-with-tools         # 启动包含管理工具的服务"
            echo "  $0 logs backend             # 查看后端日志"
              ;;
        *)
            print_error "未知命令: $1"
            echo "💡 使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"