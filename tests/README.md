# tests/

`tests/` 目录只负责 **api Compose 测试栈** 与 **仓库级 tooling 守护**，不是全项目统一测试中心。

## 包含内容
- `tests/docker-compose.test.yml`：api Compose 测试栈（pg / redis / external-mock / rust-tests / api-smoke；PG/Redis/external-mock 不映射宿主端口）
- `tests/go/tooling/`：仓库级 Makefile / 脚本守护测试
- `tests/mocks/external/`：第三方依赖 mock（Push / S3 兼容对象存储 / IPInfo）
- `tests/perf/`：API Compose 网络内压测工具与本地 JSON 报告目录

## 对象存储 mock
api 集成测试涉及对象存储时指向 `external-mock`，禁止访问线上 S3 兼容对象存储，避免消耗真实资源。

## 不包含内容
- api 业务测试本身（在 `api/tests/` 集成测试与 `api/src` 单元测试中）
- app / admin / desktop / website 模块测试（保留在各自模块目录）

## 常用命令
```bash
# api Rust 单元 + 集成（集成自动拉起本目录依赖栈）
make api.test
make api.test.unit
make api.test.integration
make api.test.smoke
make api.test.build
make api.test.images
make api.test.deps.down

# api 性能基线（Compose 内 api + pg + redis + mock + api-perf）
make api.perf.smoke
make api.perf.healthz
make api.perf.readyz
make api.perf.auth
make api.perf.ws.connect
make api.perf.ws.join
make api.perf.ws.broadcast
make api.perf.release
make api.perf.release.small
make api.perf.release.standard
make api.perf.release.large

# 仓库级 tooling 守护
make tests.compose.config
make tests.tooling
make tests.perf.check
```

说明：api 单元、集成与 smoke 默认都通过 Docker Compose 执行；集成测试用 `axum` `oneshot` 进程内打 Router，对依赖栈的临时库运行；详见 `docs/reference/testing/README.md`。
性能测试报告默认写入 `tests/perf/reports/`；需要沉淀结论时整理到 `docs/reports/performance/`。
