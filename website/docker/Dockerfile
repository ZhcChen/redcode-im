# 构建阶段
FROM oven/bun:1.3.1-alpine AS builder

WORKDIR /app

# 复制依赖文件
COPY package.json bun.lock ./

# 安装依赖
RUN bun install --frozen-lockfile

# 复制源代码
COPY . .

# 构建应用
RUN bun run build

# 生产阶段
FROM oven/bun:1.3.1-alpine AS runner

WORKDIR /app

# 安装健康检查工具
RUN apk add --no-cache wget

# 创建非 root 用户
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app

# 复制构建产物和必要文件
COPY --from=builder /app/.output ./.output
COPY --from=builder /app/public ./public
COPY --from=builder /app/nuxt.config.ts ./
COPY --from=builder /app/package.json ./

# 更改所有者
RUN chown -R app:app /app

# 切换到非 root 用户
USER app

# 暴露端口
EXPOSE 8015

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8015 || exit 1

# 启动应用（Nuxt 4 可以使用 Bun 运行 server）
CMD ["bun", ".output/server/index.mjs"]

