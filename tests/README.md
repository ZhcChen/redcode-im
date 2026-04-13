# tests/

`tests/` 目录只负责 **backend contract 测试栈**，不是全项目统一测试中心。

## 包含内容
- `tests/run.sh`：backend contract 测试入口
- `tests/docker-compose.yml`：isolated contract test stack
- `tests/go/`：backend HTTP / WS 黑盒契约测试
- `tests/mocks/external/`：第三方依赖 mock（OAuth / Push / B2/S3 兼容对象存储 / IPInfo）

## 不包含内容
- frontend 单元 / widget / integration 测试
- admin 页面测试 / Playwright 规范
- desktop / website 自身模块测试

这些测试应保留在各自模块目录内：
- `frontend/test` / `frontend/integration_test`
- `admin/playwright-tests`
- `desktop/test`
- `website/test`

## 常用命令
```bash
make tests.run
make tests.go
make tests.rust

./tests/run.sh
./tests/run.sh rust
./tests/run.sh go
```

说明：
- `make tests.*` 是仓库根目录的推荐入口。
- `tests/run.sh` 是底层 backend contract 执行脚本，适合排障或独立运行。
