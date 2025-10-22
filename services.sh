#!/bin/bash

# 服务管理脚本
# 用于管理RedCode IM的所有Docker服务

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${GREEN}RedCode IM 服务管理脚本${NC}"
    echo ""
    echo "用法: ./services.sh [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  start [服务]    启动服务"
    echo "  stop [服务]     停止服务"
    echo "  restart [服务]  重启服务"
    echo "  status          查看服务状态"
    echo "  logs [服务]     查看服务日志"
    echo "  clean           清理所有数据"
    echo "  backup          备份数据"
    echo ""
    echo "服务:"
    echo "  all             所有服务"
    echo "  db              PostgreSQL数据库"
    echo "  redis           所有Redis实例"
    echo "  minio           MinIO对象存储"
    echo "  backend         后端服务"
    echo ""
    echo "示例:"
    echo "  ./services.sh start all      # 启动所有服务"
    echo "  ./services.sh stop minio     # 停止MinIO"
    echo "  ./services.sh logs backend   # 查看后端日志"
    echo "  ./services.sh status         # 查看所有服务状态"
}

# 启动服务
start_services() {
    local service=$1
    
    case $service in
        all)
            echo -e "${YELLOW}启动所有服务...${NC}"
            docker-compose -f docker-compose-all.yml up -d
            echo -e "${GREEN}✓ 所有服务已启动${NC}"
            show_status
            ;;
        db)
            echo -e "${YELLOW}启动PostgreSQL...${NC}"
            docker-compose -f docker-compose.yml up -d postgres
            echo -e "${GREEN}✓ PostgreSQL已启动${NC}"
            ;;
        redis)
            echo -e "${YELLOW}启动Redis服务...${NC}"
            docker-compose -f docker-compose.yml up -d redis-session redis-stream redis-cache
            echo -e "${GREEN}✓ Redis服务已启动${NC}"
            ;;
        minio)
            echo -e "${YELLOW}启动MinIO...${NC}"
            docker-compose -f docker-compose-minio.yaml up -d
            echo -e "${GREEN}✓ MinIO已启动${NC}"
            echo -e "${BLUE}MinIO Console: http://localhost:9001${NC}"
            echo -e "${BLUE}默认账号: admin / admin123456${NC}"
            ;;
        backend)
            echo -e "${YELLOW}启动后端服务...${NC}"
            cd backend && cargo run &
            echo -e "${GREEN}✓ 后端服务已启动${NC}"
            ;;
        *)
            echo -e "${RED}未知服务: $service${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 停止服务
stop_services() {
    local service=$1
    
    case $service in
        all)
            echo -e "${YELLOW}停止所有服务...${NC}"
            docker-compose -f docker-compose-all.yml down
            pkill -f "cargo run" 2>/dev/null || true
            echo -e "${GREEN}✓ 所有服务已停止${NC}"
            ;;
        db)
            echo -e "${YELLOW}停止PostgreSQL...${NC}"
            docker-compose -f docker-compose.yml stop postgres
            echo -e "${GREEN}✓ PostgreSQL已停止${NC}"
            ;;
        redis)
            echo -e "${YELLOW}停止Redis服务...${NC}"
            docker-compose -f docker-compose.yml stop redis-session redis-stream redis-cache
            echo -e "${GREEN}✓ Redis服务已停止${NC}"
            ;;
        minio)
            echo -e "${YELLOW}停止MinIO...${NC}"
            docker-compose -f docker-compose-minio.yaml down
            echo -e "${GREEN}✓ MinIO已停止${NC}"
            ;;
        backend)
            echo -e "${YELLOW}停止后端服务...${NC}"
            pkill -f "cargo run" 2>/dev/null || true
            echo -e "${GREEN}✓ 后端服务已停止${NC}"
            ;;
        *)
            echo -e "${RED}未知服务: $service${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 重启服务
restart_services() {
    local service=$1
    stop_services $service
    sleep 2
    start_services $service
}

# 查看服务状态
show_status() {
    echo -e "\n${GREEN}========== 服务状态 ==========${NC}"
    
    # Docker服务状态
    echo -e "\n${YELLOW}Docker服务:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "redcode|NAMES" || echo "没有运行的Docker服务"
    
    # 后端服务状态
    echo -e "\n${YELLOW}后端服务:${NC}"
    if pgrep -f "cargo run" > /dev/null; then
        echo -e "${GREEN}✓ 后端服务运行中 (端口 8010)${NC}"
    else
        echo -e "${RED}✗ 后端服务未运行${NC}"
    fi
    
    # 服务访问地址
    echo -e "\n${YELLOW}服务访问地址:${NC}"
    echo "• PostgreSQL: localhost:5432"
    echo "• Redis Session: localhost:6381"
    echo "• Redis Stream: localhost:6382"
    echo "• Redis Cache: localhost:6383"
    echo "• MinIO API: http://localhost:9000"
    echo "• MinIO Console: http://localhost:9001"
    echo "• Backend API: http://localhost:8010"
    echo "• Adminer: http://localhost:8080"
}

# 查看日志
show_logs() {
    local service=$1
    
    case $service in
        all)
            docker-compose -f docker-compose-all.yml logs -f
            ;;
        db)
            docker logs -f redcode-postgres
            ;;
        redis)
            echo "选择Redis实例:"
            echo "1) Session"
            echo "2) Stream"
            echo "3) Cache"
            read -p "选择 (1-3): " choice
            case $choice in
                1) docker logs -f redcode-redis-session ;;
                2) docker logs -f redcode-redis-stream ;;
                3) docker logs -f redcode-redis-cache ;;
                *) echo "无效选择" ;;
            esac
            ;;
        minio)
            docker logs -f redcode-minio
            ;;
        backend)
            echo -e "${YELLOW}查看后端日志请运行:${NC}"
            echo "cd backend && RUST_LOG=debug cargo run"
            ;;
        *)
            echo -e "${RED}未知服务: $service${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 清理数据
clean_data() {
    echo -e "${RED}警告：这将删除所有数据！${NC}"
    read -p "确定要继续吗？(y/N): " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        echo -e "${YELLOW}停止所有服务...${NC}"
        docker-compose -f docker-compose-all.yml down -v
        
        echo -e "${YELLOW}删除数据目录...${NC}"
        rm -rf data/
        
        echo -e "${GREEN}✓ 数据已清理${NC}"
    else
        echo "操作已取消"
    fi
}

# 备份数据
backup_data() {
    local backup_dir="backup/$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${YELLOW}创建备份目录: $backup_dir${NC}"
    mkdir -p $backup_dir
    
    # 备份数据库
    echo -e "${YELLOW}备份PostgreSQL...${NC}"
    docker exec redcode-postgres pg_dump -U postgres redcode_im > $backup_dir/postgres_backup.sql
    
    # 备份MinIO
    if docker ps | grep -q redcode-minio; then
        echo -e "${YELLOW}备份MinIO...${NC}"
        docker run --rm \
            --network redcode-network \
            -v $(pwd)/$backup_dir:/backup \
            minio/mc:latest \
            sh -c "
                mc alias set backup http://minio:9000 admin admin123456 &&
                mc mirror backup/ /backup/minio/
            "
    fi
    
    # 压缩备份
    echo -e "${YELLOW}压缩备份文件...${NC}"
    tar -czf $backup_dir.tar.gz $backup_dir
    rm -rf $backup_dir
    
    echo -e "${GREEN}✓ 备份完成: $backup_dir.tar.gz${NC}"
}

# 主程序
case $1 in
    start)
        start_services ${2:-all}
        ;;
    stop)
        stop_services ${2:-all}
        ;;
    restart)
        restart_services ${2:-all}
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs ${2:-all}
        ;;
    clean)
        clean_data
        ;;
    backup)
        backup_data
        ;;
    *)
        show_help
        ;;
esac
