# 文档索引

> 本文档用于索引 `docs/` 目录下的核心文档。快速开始请查看仓库根目录 `README.md`。

## AI 工作流（Compound Engineering, CE）

| 文档 | 说明 |
|------|------|
| [需求/方向讨论](brainstorms/) | `ce:brainstorm` 产出目录 |
| [规划文档目录](plans/) | `ce:plan` 产出目录 |
| [Admin 架构重构主计划](plans/2026-04-09-admin-rbac-architecture-refactor-plan.md) | 当前 active 执行文档（admin / B2 / SQL / 测试闭环） |
| [解决方案沉淀](solutions/) | `ce:compound` 产出目录 |
| [任务清单](reports/task-list.md) | 当前待办与阻塞项 |

> CE 采用全局安装：`~/.codex/prompts/ce-*.md`、`~/.codex/skills/ce-*`、`~/.codex/scripts/ce-init`。

### 工作流骨架

1. `ce:brainstorm`
2. `ce:plan`
3. `ce:work`
4. `ce:review`
5. `ce:compound`

---

## 项目参考文档

### API 文档

| 文档 | 说明 |
|------|------|
| [API 概览](reference/api/api-overview.md) | 接口分类与概述 |
| [API 参考](reference/api/api-reference.md) | 详细接口规范 |
| [认证接口](reference/api/auth.md) | 登录、注册、Token |
| [用户资料](reference/api/user-profile.md) | 个人信息管理 |
| [好友接口](reference/api/friends.md) | 好友关系管理 |
| [会话接口](reference/api/chats.md) | 聊天会话管理 |
| [消息接口](reference/api/messages.md) | 消息收发 |
| [WebSocket](reference/api/websocket.md) | 实时通信协议 |
| [文件上传](reference/api/file-upload-hash.md) | 文件上传与哈希校验 |
| [版本管理](reference/api/version-management.md) | 客户端版本控制 |
| [系统接口](reference/api/system.md) | 系统配置与状态 |
| [管理后台存储](reference/api/admin-storage.md) | Admin 存储接口 |
| [数据模型](reference/api/models.md) | 通用数据结构 |

### 架构设计

| 文档 | 说明 |
|------|------|
| [版本联动方案](reference/architecture/version-linkage-plan.md) | 整包 + 热更新策略 |
| [推送通知设计](reference/architecture/push-notification-design.md) | FCM/APNs 推送方案 |
| [推送配置需求](reference/architecture/push-provider-config-requirements.md) | Push 凭据后台化 |
| [端到端加密设计](reference/architecture/end-to-end-encryption-design.md) | E2EE 方案（设计完成，待实现） |
| [消息搜索设计](reference/architecture/message-search-design.md) | 搜索实现方案 |
| [Redis 配置](reference/architecture/redis-setup.md) | Redis 部署指南 |
| [Redis 安全](reference/architecture/redis-security.md) | Redis 安全配置 |
| [桌面端图标规范](reference/architecture/desktop-icon-design-spec.md) | 图标设计标准 |

### 开发指南

| 文档 | 说明 |
|------|------|
| [Git 工作流规范](standards/git-workflow.md) | 提交边界、暂存、检查与推送规则 |
| [WebSocket 集成](reference/guides/websocket-integration.md) | 客户端 WebSocket 接入 |
| [登录 WebSocket 集成](reference/guides/login-websocket-integration.md) | 登录流程与 WS 结合 |
| [错误处理规范](reference/guides/error-handling.md) | 后端错误处理 |
| [SQL 开发规范](reference/guides/sql-development.md) | 数据库开发指南 |

### 测试文档

| 文档 | 说明 |
|------|------|
| [**测试工作流**](reference/testing/README.md) | **模块自测优先，`tests/` 仅负责 api contract 栈** |

### 运维部署

| 文档 | 说明 |
|------|------|
| [部署环境](reference/operations/deployment-env.md) | 环境配置说明 |
| [开发与构建](reference/operations/dev-and-build.md) | 本地开发指南 |
| [Docker 部署](reference/operations/docker-deploy.md) | 容器化部署 |
| [故障排查手册](reference/operations/troubleshooting.md) | 常见问题排查 |
| [备份与恢复](reference/operations/backup-restore.md) | 数据备份策略 |
| [升级与迁移](reference/operations/upgrade-migration.md) | 版本升级指南 |

### 安全文档

| 文档 | 说明 |
|------|------|
| [安全概述](reference/security/security-overview.md) | 安全措施详解 |
| [安全检查清单](reference/security/security-checklist.md) | 安全检查项 |

### 法律文档

| 文档 | 说明 |
|------|------|
| [隐私政策](reference/legal/privacy-policy.md) | 个人信息保护政策 |
| [用户协议](reference/legal/user-agreement.md) | 用户服务条款 |

---

## 数据与报告

| 文档 | 说明 |
|------|------|
| [任务清单](reports/task-list.md) | 当前待办与阻塞项 |
| [项目评估报告](reports/project-status-assessment-report-2025-11-08.md) | 项目现状与风险 |
| [模块功能清单（2026-03-01）](reports/module-function-inventory-2026-03-01.md) | 五大模块功能基线 |
| [批次A验收报告（2026-03-01）](reports/2026-03-01-batch-a-acceptance.md) | 外部模拟与测试栈接入验收 |
| [批次B-1验收报告（2026-03-01）](reports/2026-03-01-batch-b1-auth-users-friends-acceptance.md) | API auth/users/friends 测试重建验收 |
| [批次B-2验收报告（2026-03-01）](reports/2026-03-01-batch-b2-rooms-messages-uploads-acceptance.md) | API rooms/messages/uploads 测试重建验收 |
| [批次B-3验收报告（2026-03-01）](reports/2026-03-01-batch-b3-versions-admin-ws-acceptance.md) | API versions/admin/ws 测试重建验收 |
| [批次C验收报告（2026-03-01）](reports/2026-03-01-batch-c-admin-acceptance.md) | Admin 测试重建验收 |
| [批次D验收报告（2026-03-01）](reports/2026-03-01-batch-d-app-acceptance.md) | App Flutter 测试重建验收 |
| [批次E验收报告（2026-03-01）](reports/2026-03-01-batch-e-desktop-website-acceptance.md) | Desktop + Website 测试重建验收 |
| [全模块回归验收报告（2026-03-04）](reports/2026-03-04-full-module-regression-acceptance.md) | 全模块回归执行结果与问题处理记录 |

---

## 各模块 README

| 模块 | 说明 |
|------|------|
| [api](../api/README.md) | 后端服务 (Rust) |
| [app](../app/README.md) | 移动端 (Flutter) |
| [desktop](../desktop/README.md) | 桌面端 (Vue + Tauri) |
| [admin](../admin/README.md) | 管理后台 (Vue) |
| [website](../website/README.md) | 官网 |

---

**文档最后更新**: 2026-04-10
