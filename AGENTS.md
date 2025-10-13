# AGENTS

Global memory for Droid CLI.

## 项目模块
- backend：Rust + Axum API 服务（默认端口 8010，可通过 `PORT` 覆盖；API 文档静态服务端口 8011）
- frontend：Flutter 跨平台客户端（`frontend/`；尚未初始化 Flutter 工程，计划对接认证与消息 API）
- admin：Vue 3 + Arco Design Pro 管理后台（使用 pnpm，核心脚本：`pnpm dev`、`pnpm build`、`pnpm type:check`）

## 基础设施
- Docker Compose 提供 PostgreSQL 17 (`postgres:5432`) 与三实例 Redis 8：session(6381)、streams(6382)、cache(6383)
- 后端使用 SQLx + PostgreSQL、RedisManager 管理多实例连接；JWT/Redis 等环境变量定义在 `backend/.env`

## 近期决策
- 2025-10-13：弃用 uni-app，前端全面迁移至 Flutter，并清理旧前端文件
- 全局记忆统一维护在本文件；其他 context 记忆文件已删除
