FROM oven/bun:1.3.1-alpine

WORKDIR /app

# 安装解压工具
RUN apk add --no-cache tar gzip

# 复制并解压构建产物压缩包
# 假设压缩包名为 build.tar.gz，包含 .output、public、nuxt.config.ts、package.json
COPY build.tar.gz /tmp/
RUN tar -xzf /tmp/build.tar.gz -C /app && rm /tmp/build.tar.gz

# 暴露端口
EXPOSE 8015

# 运行构建好的应用
CMD ["bun", ".output/server/index.mjs"]



