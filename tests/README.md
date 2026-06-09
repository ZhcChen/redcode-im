# tests/

`tests/` 目录只负责 **api contract 测试栈**，不是全项目统一测试中心。

## 包含内容
- `tests/run.sh`：api contract 测试入口
- `tests/docker-compose.yml`：isolated contract test stack
- `tests/go/`：api HTTP / WS 黑盒契约测试
- `tests/mocks/external/`：第三方依赖 mock（Push / B2/S3 兼容对象存储 / IPInfo）

## 对象存储 mock
api contract 栈默认把 Backblaze B2 / S3 兼容对象存储指向 `external-mock`：

- B2 authorize：`http://external-mock:19080/b2api/v4/b2_authorize_account`
- S3 endpoint：`http://external-mock:19080`
- bucket：`mock-bucket`

测试过程中不要把 contract 栈改成线上 Backblaze B2 endpoint，避免消耗真实对象存储资源。

## 不包含内容
- app 单元 / widget / integration 测试
- admin 页面测试 / Playwright 规范
- desktop / website 自身模块测试

这些测试应保留在各自模块目录内：
- `app/test` / `app/integration_test`
- `admin/playwright-tests`
- `desktop/test`
- `website/test`

## 常用命令
```bash
make tests.run
make tests.go
make tests.rust
make tests.all

./tests/run.sh
./tests/run.sh rust
./tests/run.sh go
```

说明：
- `make tests.*` 是仓库根目录的推荐入口。
- `tests/run.sh` 是底层 api contract 执行脚本，适合排障或独立运行。
- `make tests.all` 是兼容入口，实际转到仓库全量本地测试 `make test.all`。
