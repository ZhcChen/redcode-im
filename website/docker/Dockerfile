FROM oven/bun:1.3.1-alpine

WORKDIR /app

# 安装解压工具（支持 7z 和 tar.gz）
RUN apk add --no-cache p7zip tar gzip

# 复制并解压构建产物压缩包
# 支持 7z 格式（优先级）或 tar.gz 格式
# 使用通配符匹配文件名
COPY build.* /tmp/

# 尝试解压 7z，如果失败则尝试 tar.gz
RUN if ls /tmp/build.7z* 1> /dev/null 2>&1; then \
        7z x /tmp/build.7z* -o/app -y && rm -f /tmp/build.*; \
    elif ls /tmp/build.tar.gz* 1> /dev/null 2>&1; then \
        tar -xzf /tmp/build.tar.gz* -C /app && rm -f /tmp/build.*; \
    else \
        echo "错误: 未找到构建产物压缩包 (build.7z 或 build.tar.gz)"; \
        exit 1; \
    fi

# 暴露端口
EXPOSE 8015

# 运行构建好的应用
CMD ["bun", ".output/server/index.mjs"]



