FROM oven/bun:1.3.1-alpine

WORKDIR /app

# 复制构建产物
COPY .output ./.output
COPY public ./public
COPY nuxt.config.ts ./
COPY package.json ./

# 暴露端口
EXPOSE 8015

# 运行构建好的应用
CMD ["bun", ".output/server/index.mjs"]



