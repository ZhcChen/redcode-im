# API Compose 性能基线（2026-07-02 更新）

## 结论

API 性能测试已经纳入 Docker Compose-first 工作流。压测容器、API、PostgreSQL、Redis、external-mock 均在 `tests/docker-compose.test.yml` 内运行，PG/Redis/mock 不映射宿主端口。

本轮核心优化后，标准规格（API `2C/1G`，PG `4C/4G`，Redis `2C/1G`，PG pool `80/8`）下建议使用以下 release 指标作为当前 API 对外性能口径：

- `/healthz` 框架基线：约 `107.6k req/s`，P95 `1.37ms`，0 错误。
- `/readyz` 低频依赖探测：P95 `1.85ms`，0 错误。
- `auth-register-login`（邮箱注册 + 登录，`BCRYPT_COST=8`）：约 `85.4 ops/s`（约 `170.8 HTTP req/s`），P95 `79.9ms`，0 错误。
- WebSocket 连接认证 + ping/pong：约 `6370.8 ops/s`，P95 `1.90ms`，0 错误。
- WebSocket 连接认证 + 房间订阅：约 `6717.4 ops/s`，P95 `1.77ms`，0 错误。
- WebSocket 房间广播（16 个订阅者，20 条消息）：约 `3219.9 delivered events/s`，P95 `10.1ms`，0 错误。

关键变化：

- WebSocket 从“每连接一个 Redis PubSub 订阅连接”改为“节点级共享 Redis PubSub Hub”，解决高并发 join 时 Redis 连接 / 临时端口耗尽问题。
- Redis session/cache/pubsub 命令连接改为启动期建立的 multiplexed connection clone 复用，减少每请求 / 每心跳新建 TCP 连接。
- WS 短连接压测工具默认对连接关闭使用 RST linger，避免压测容器自身 `TIME_WAIT` / 临时端口成为瓶颈。
- 固定硬件档位已经固化为 Makefile 入口：`api.perf.release.small` / `standard` / `large`。

## 固定硬件档位

```text
小规格：
  API 1C / 512M
  PG 4C / 4G
  Redis 2C / 1G
  PG pool 40 max / 4 min

标准规格：
  API 2C / 1G
  PG 4C / 4G
  Redis 2C / 1G
  PG pool 80 max / 8 min

大规格：
  API 4C / 2G
  PG 6C / 6G
  Redis 2C / 1G
  PG pool 160 max / 16 min
```

普通测试 / 生产默认 bcrypt cost 仍为 `12`；性能入口默认 `API_PERF_BCRYPT_COST=8`，用于测注册/登录链路结构性能。

## 三档 release 结果

```text
小规格 API 1C/512M：
  /healthz c=32:
    112,857 req/s, p95 0.54ms, p99 0.97ms, error 0
    report tests/perf/reports/release-small-healthz-20260702-081041.json
  /readyz probe:
    p95 2.01ms, p99 2.03ms, error 0
    report tests/perf/reports/release-small-readyz-20260702-081142.json
  auth-register-login c=2:
    41.84 ops/s, 83.67 HTTP req/s, p95 76.39ms, p99 82.28ms, error 0
    report tests/perf/reports/release-small-auth-register-login-20260702-081243.json
  ws-connect-ping c=4:
    5,023.18 ops/s, p95 1.22ms, p99 1.70ms, error 0
    report tests/perf/reports/release-small-ws-connect-ping-20260702-081349.json
  ws-connect-join c=4:
    5,040.71 ops/s, p95 1.16ms, p99 1.65ms, error 0
    report tests/perf/reports/release-small-ws-connect-join-20260702-081451.json
  ws-room-broadcast subscribers=8, messages=20:
    1,830.94 delivered events/s, p95 9.19ms, p99 20.39ms, error 0
    report tests/perf/reports/release-small-ws-room-broadcast-20260702-081554.json

标准规格 API 2C/1G：
  /healthz c=64:
    107,578.88 req/s, p95 1.37ms, p99 2.21ms, error 0
    report tests/perf/reports/release-standard-healthz-20260702-080248.json
  /readyz probe:
    p95 1.85ms, p99 2.20ms, error 0
    report tests/perf/reports/release-standard-readyz-20260702-080354.json
  auth-register-login c=4:
    85.41 ops/s, 170.82 HTTP req/s, p95 79.87ms, p99 83.55ms, error 0
    report tests/perf/reports/release-standard-auth-register-login-20260702-080500.json
  ws-connect-ping c=8:
    6,370.77 ops/s, p95 1.90ms, p99 2.50ms, error 0
    report tests/perf/reports/release-standard-ws-connect-ping-20260702-080601.json
  ws-connect-join c=8:
    6,717.45 ops/s, p95 1.77ms, p99 2.55ms, error 0
    report tests/perf/reports/release-standard-ws-connect-join-20260702-080659.json
  ws-room-broadcast subscribers=16, messages=20:
    3,219.88 delivered events/s, p95 10.12ms, p99 25.53ms, error 0
    report tests/perf/reports/release-standard-ws-room-broadcast-20260702-080757.json

大规格 API 4C/2G：
  /healthz c=128:
    52,755.78 req/s, p95 5.71ms, p99 7.45ms, error 0
    report tests/perf/reports/release-large-healthz-20260702-081641.json
  /readyz probe:
    p95 1.72ms, p99 1.88ms, error 0
    report tests/perf/reports/release-large-readyz-20260702-081742.json
  auth-register-login c=8:
    170.39 ops/s, 340.77 HTTP req/s, p95 79.99ms, p99 83.22ms, error 0
    report tests/perf/reports/release-large-auth-register-login-20260702-081847.json
  ws-connect-ping c=16:
    6,284.73 ops/s, p95 3.86ms, p99 4.74ms, error 0
    report tests/perf/reports/release-large-ws-connect-ping-20260702-081952.json
  ws-connect-join c=16:
    6,477.40 ops/s, p95 3.44ms, p99 4.32ms, error 0.0005%（1 次 timeout / 194,330 ops）
    report tests/perf/reports/release-large-ws-connect-join-20260702-082051.json
  ws-room-broadcast subscribers=32, messages=20:
    5,217.69 delivered events/s, p95 11.65ms, p99 22.77ms, error 0
    report tests/perf/reports/release-large-ws-room-broadcast-20260702-082151.json
```

## 本轮发现与处理

- API smoke/perf 不能用 `cargo run` 直接作为受限 API 容器命令，否则 Rust 编译开销会被计入 API 运行时资源限制；已改为先编译，再运行 `/app/target/{debug,release}/redcode-im-api`。
- release 性能基线使用 Compose 内 `cargo build --release` 产物，避免 Docker 镜像构建和 Docker Hub metadata 限流混入指标。
- `api-perf` 使用 `docker compose run --no-deps`，避免 debug / release API 同时运行污染固定硬件基线。
- 每份 JSON 报告都会记录 `resource_limits`，后续横向对比必须先确认 API/PG/Redis CPU、内存、PG pool、bcrypt cost、metrics 参数和 WS 队列大小一致。
- `readyz` 只保留低频 probe 口径，不作为高并发吞吐接口。
- 大规格 `/healthz` 在 128 并发下低于标准规格，说明当前 Docker Desktop / 单机网络调度下该场景不是 CPU 线性扩展口径；后续需要按场景单独寻找最佳并发。

## 后续优化方向

1. auth 链路继续优化：
   - account limit settings 缓存；
   - 邮箱/用户名存在性检查合并或改为依赖唯一索引冲突处理；
   - 生产成本 `BCRYPT_COST=12` 单独建一组指标。
2. WebSocket 广播矩阵继续扩展：
   - 100 / 500 / 1000 订阅者；
   - 多房间并发广播；
   - 慢客户端和 `WS_OUTBOUND_QUEUE_SIZE` 满队列行为。
3. 继续做前后端联调验收后，再把最终性能结果作为全项目最终报告输出。
