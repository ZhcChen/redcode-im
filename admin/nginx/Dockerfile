# 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app

ARG VITE_API_BASE_URL
ARG VITE_ENABLE_DATA_CLEANUP=false
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_ENABLE_DATA_CLEANUP=${VITE_ENABLE_DATA_CLEANUP}

# 复制 package 文件
COPY package*.json ./
COPY pnpm-lock.yaml ./

# 安装 pnpm 并安装依赖
RUN npm install -g pnpm && pnpm install

# 复制源代码
COPY . .

# 明确要求按环境传入 API 地址，避免误连到错误环境。
RUN test -n "$VITE_API_BASE_URL"

# 构建项目
RUN pnpm run build

# 生产阶段
FROM nginx:alpine

# 复制 nginx 配置
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# 复制构建产物到 nginx 目录
COPY --from=builder /app/dist /usr/share/nginx/html

# 暴露端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]
