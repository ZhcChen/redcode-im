# AGENTS

Global memory for Droid CLI.

## 模块概览
- backend：Rust + Axum API（端口 8010，占用 8011 服务静态 API 文档）
- frontend：Flutter 客户端（`frontend/` 空目录待初始化 Flutter 工程）
- admin：Vue 3 + Arco Design Pro 后台（pnpm 管理）

## 基础设施
- Docker Compose：PostgreSQL 17 (5432) + Redis 8（三实例：session 6381 / streams 6382 / cache 6383）
- 后端使用 SQLx、RedisManager、JWT；关键环境变量在 `backend/.env`

## 客户端迁移记忆（2025-10-13）
- 原移动端在 `/Users/chen/code/bear-chat-uniapp`（uni-app/Vue3），现要求仅迁移 UI 至 Flutter 前端，业务逻辑暂不保留
- 迁移时可自建 mock 数据、拷贝所需图片资源；在 `frontend/` 下维护迁移任务文件，持续更新进度
- Flutter 端已完成登录页、底部 Tab 导航与聊天列表（mock 数据 + 滑动操作）基础 UI
