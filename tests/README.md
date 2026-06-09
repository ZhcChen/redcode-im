# tests/

`tests/` 目录只负责 **api 集成测试依赖栈** 与 **仓库级 tooling 守护**，不是全项目统一测试中心。

## 包含内容
- `tests/docker-compose.test.yml`：api 集成测试依赖栈（pg / redis / external-mock，映射宿主端口 `5433 / 6380 / 19080`）
- `tests/go/tooling/`：仓库级 Makefile / 脚本守护测试
- `tests/mocks/external/`：第三方依赖 mock（Push / B2/S3 兼容对象存储 / IPInfo）

## 对象存储 mock
api 集成测试涉及对象存储时指向 `external-mock`，禁止访问线上 Backblaze B2，避免消耗真实资源。

## 不包含内容
- api 业务测试本身（在 `api/tests/` 集成测试与 `api/src` 单元测试中）
- app / admin / desktop / website 模块测试（保留在各自模块目录）

## 常用命令
```bash
# api Rust 单元 + 集成（集成自动拉起本目录依赖栈）
make api.test
make api.test.unit
make api.test.integration
make api.test.deps.down

# 仓库级 tooling 守护
cd tests/go && go test ./tooling/
```

说明：api 集成测试用 `axum` `oneshot` 进程内打 Router，对依赖栈的单一临时库运行；详见 `docs/reference/testing/README.md`。
