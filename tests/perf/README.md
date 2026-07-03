# API 性能测试

本目录提供 API 的 Docker Compose-first 压测工具。压测容器与 api、PostgreSQL、Redis、external-mock 位于同一 Compose 网络，PG/Redis/mock 不映射宿主端口。

## 默认资源基线

默认由 `tests/docker-compose.test.yml` 限制资源，`make api.perf.*` 会用环境变量覆盖为性能基线资源：

- API：`2 CPU / 1g`
- PostgreSQL：`4 CPU / 4g`
- Redis：`2 CPU / 1g`
- external-mock：`0.25 CPU / 128m`
- PG pool：`80 max / 8 min`

可在命令前覆盖变量，例如：

```bash
API_SERVICE_CPUS=1.0 API_SERVICE_MEMORY=512m make api.perf.healthz
```

## 固定硬件档位

建议对外报告优先使用 release 二进制和固定档位，避免每次手工覆盖变量导致口径漂移：

- 小规格：`make api.perf.release.small`，API `1 CPU / 512m`，PG pool `40 max / 4 min`
- 标准规格：`make api.perf.release.standard`，API `2 CPU / 1g`，PG pool `80 max / 8 min`
- 大规格：`make api.perf.release.large`，API `4 CPU / 2g`，PG pool `160 max / 16 min`

三档都通过 Compose 限制 API 运行时资源，并让 PostgreSQL / Redis 给足资源，尽量把指标口径聚焦在 API 自身。`make api.perf.release` 等同于当前标准规格的默认资源口径。

压测容器在 Compose 网络内访问目标 API；debug 基线访问 `http://api:8010`，release 基线访问 `http://api-release-local:8010`。PG/Redis/external-mock 不映射宿主端口。

## 常用命令

```bash
# 轻量验证压测工具是否可运行
make api.perf.smoke

# 基线场景
make api.perf.healthz
make api.perf.readyz
make api.perf.auth
make api.perf.ws.connect
make api.perf.ws.join
make api.perf.ws.broadcast

# 顺序执行默认基线
make api.perf

# release 二进制基线
make api.perf.release
make api.perf.release.small
make api.perf.release.standard
make api.perf.release.large
make api.perf.release.ws.connect
make api.perf.release.ws.join
make api.perf.release.ws.broadcast

# 清理性能测试栈，保留 cargo cache 卷
make api.perf.down
```

## 场景

- `healthz`：纯 HTTP liveness 基线，用于观察 API 网络与框架开销。
- `readyz`：readiness 基线，会触达数据库 / Redis。
- `auth-register-login`：账号密码注册 + 登录业务链路，每个操作包含 2 个 HTTP 请求。
- `ws-connect-ping`：预创建账号后，正式窗口只测 WebSocket 连接、认证、ping/pong。
- `ws-connect-join`：预创建账号和房间后，正式窗口只测 WebSocket 连接、认证、订阅房间。
- `ws-room-broadcast`：预创建账号、房间和订阅连接后，正式窗口测 REST 发消息 → Redis PubSub → WebSocket 推送到房间订阅者。

WS 场景的账号/房间准备开销会写入 JSON 的 `setup_seconds`、`setup_http_requests`、`setup_bytes_read`；核心吞吐和延迟只统计正式窗口。

原始 JSON 报告输出到 `tests/perf/reports/`，该目录默认不纳入版本控制。需要沉淀结论时，把关键结果整理到 `docs/reports/performance/`。
