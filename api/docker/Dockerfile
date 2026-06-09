# syntax=docker/dockerfile:1.7
# 构建镜像前请确认当前目录放置了 release 版本的 `redcode-im-backend` 二进制和对应的 `.env`。
# 建议执行：
#   cargo build --release
#   cp target/release/redcode-im-backend docker/
#   cp .env docker/
FROM alpine:3.20
WORKDIR /app
RUN apk add --no-cache ca-certificates openssl libpq tzdata curl
COPY redcode-im-backend /app/redcode-im-backend
COPY .env /app/.env
RUN chmod +x /app/redcode-im-backend
EXPOSE 8010
CMD ["./redcode-im-backend"]
