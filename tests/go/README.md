# tests/go/

本目录承载 **仓库级 tooling 守护测试**（Go），不再承载 api 黑盒契约测试。

## 作用
- `tooling/`：校验根 `Makefile` 暴露的模块化目标、构建脚本约定等仓库级不变量

## 不负责
- api 业务契约（已迁移到 `api/tests/` 的 Rust 集成测试）
- app / admin / desktop / website 模块测试

## 运行
```bash
go test ./tooling/
```
