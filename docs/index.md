# 文档索引

> 本文档用于索引 `docs/` 目录下的核心文档。快速开始请查看仓库根目录 `README.md`。

## AI 工作流（Superpowers）

| 文档 | 说明 |
|------|------|
| [Codex 使用说明](README.codex.md) | Superpowers 在 Codex 的安装与使用方式 |
| [规划文档目录](plans/) | brainstorming 与 writing-plans 产出目录 |
| [任务清单](reports/task-list.md) | 当前待办与阻塞项 |

### 工作流骨架

1. `using-superpowers`
2. `brainstorming`
3. `using-git-worktrees`
4. `writing-plans`
5. `subagent-driven-development` 或 `executing-plans`
6. `test-driven-development`
7. `requesting-code-review` / `receiving-code-review`
8. `verification-before-completion` + `finishing-a-development-branch`

### 命令入口

- `../commands/brainstorm.md`
- `../commands/write-plan.md`
- `../commands/execute-plan.md`

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
| [COS 集成](reference/architecture/cos-integration.md) | 腾讯云对象存储 |
| [Redis 配置](reference/architecture/redis-setup.md) | Redis 部署指南 |
| [Redis 安全](reference/architecture/redis-security.md) | Redis 安全配置 |
| [桌面端图标规范](reference/architecture/desktop-icon-design-spec.md) | 图标设计标准 |

### 开发指南

| 文档 | 说明 |
|------|------|
| [WebSocket 集成](reference/guides/websocket-integration.md) | 客户端 WebSocket 接入 |
| [登录 WebSocket 集成](reference/guides/login-websocket-integration.md) | 登录流程与 WS 结合 |
| [错误处理规范](reference/guides/error-handling.md) | 后端错误处理 |
| [SQL 开发规范](reference/guides/sql-development.md) | 数据库开发指南 |

### 测试文档

| 文档 | 说明 |
|------|------|
| [**测试工作流程指南**](reference/testing/README.md) | **测试策略、流程与规范总纲** |
| [测试架构（五模块）](reference/testing/test-architecture.md) | 五模块测试边界与框架选择 |
| [Backend 测试说明](reference/testing/backend-testing.md) | 后端单元/集成/契约测试写法 |
| [Backend 单元测试计划](reference/testing/backend-test-plan.md) | 后端测试现状与补充计划 |
| [Admin E2E（Playwright）](reference/testing/admin-e2e.md) | 管理后台 E2E 测试规范与路径 |
| [E2E 测试指南](reference/testing/e2e-testing-guide.md) | Patrol 框架使用详解 |
| [E2E 测试路径](reference/testing/test-paths.md) | 移动端用户旅程测试 |
| [快速测试指南](reference/testing/quick-test.md) | 5 分钟快速验证 |
| [WebSocket 测试](reference/testing/websocket-test.md) | WS 实时分发测试 |
| [添加好友测试](reference/testing/add-friend.md) | 好友功能测试用例 |
| [桌面端测试架构](reference/testing/desktop-add-member-go-test-architecture.md) | Go 集成测试设计 |

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
| [API 路由测试覆盖数据](reports/api-test-coverage.json) | 路由覆盖统计（Go 黑盒 + Rust in-process，Dashboard 读取） |
| [测试覆盖率汇总](reports/test-coverage.json) | Rust 行覆盖率与测试统计 |
| [任务清单](reports/task-list.md) | 当前待办与阻塞项 |
| [项目评估报告](reports/project-status-assessment-report-2025-11-08.md) | 项目现状与风险 |

---

## 各模块 README

| 模块 | 说明 |
|------|------|
| [backend](../backend/README.md) | 后端服务 (Rust) |
| [frontend](../frontend/README.md) | 移动端 (Flutter) |
| [desktop](../desktop/README.md) | 桌面端 (Vue + Tauri) |
| [admin](../admin/README.md) | 管理后台 (Vue) |
| [website](../website/README.md) | 官网 |

---

**文档最后更新**: 2026-03-01
