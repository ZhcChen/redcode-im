# Go 黑盒契约测试

本目录只承载 **backend 对外 HTTP / WebSocket 契约测试**。

## 作用
- 验证后端公开接口与管理接口的实际契约
- 验证 WebSocket 握手与关键业务链路
- 与 `tests/mocks/external`、`tests/docker-compose.yml` 组合运行

## 不负责
- frontend / admin / desktop / website 的模块测试
- 视觉回归
- 页面级 E2E

## 运行
```bash
./tests/run.sh go
```
