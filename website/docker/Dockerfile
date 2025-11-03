FROM oven/bun:1.3.1-alpine

WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git wget

# 复制依赖文件
COPY package.json bun.lock ./

# 安装依赖
RUN bun install --frozen-lockfile

# 复制源代码
COPY . .

# 暴露端口
EXPOSE 8015

# 启动应用（开发模式使用 dev，生产模式会先构建）
CMD ["bun", "run", "dev"]


