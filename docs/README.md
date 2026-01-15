# 文档索引

> 本文档用于索引 `docs/` 目录下的所有文档。快速开始请查看仓库根目录 `README.md`。

## 总览

- [API 概览](api/api-overview.md) - 接口分类与快速查找
- [API 详细参考](api/api-reference.md) - 完整接口文档

---

## API 文档

| 文档 | 说明 |
|------|------|
| [API 概览](api/api-overview.md) | 接口分类与概述 |
| [API 参考](api/api-reference.md) | 详细接口规范 |
| [认证接口](api/auth.md) | 登录、注册、Token |
| [用户资料](api/user-profile.md) | 个人信息管理 |
| [好友接口](api/friends.md) | 好友关系管理 |
| [会话接口](api/chats.md) | 聊天会话管理 |
| [消息接口](api/messages.md) | 消息收发 |
| [WebSocket](api/websocket.md) | 实时通信协议 |
| [文件上传](api/file-upload-hash.md) | 文件上传与哈希校验 |
| [版本管理](api/version-management.md) | 客户端版本控制 |
| [系统接口](api/system.md) | 系统配置与状态 |
| [管理后台存储](api/admin-storage.md) | Admin 存储接口 |
| [数据模型](api/models.md) | 通用数据结构 |

---

## 架构设计

| 文档 | 说明 |
|------|------|
| [版本联动方案](architecture/version-linkage-plan.md) | 整包 + 热更新策略 |
| [推送通知设计](architecture/push-notification-design.md) | FCM/APNs 推送方案 |
| [推送配置需求](architecture/push-provider-config-requirements.md) | Push 凭据后台化 |
| [端到端加密设计](architecture/end-to-end-encryption-design.md) | E2EE 方案（设计完成，待实现） |
| [消息搜索设计](architecture/message-search-design.md) | 搜索实现方案 |
| [COS 集成](architecture/cos-integration.md) | 腾讯云对象存储 |
| [Redis 配置](architecture/redis-setup.md) | Redis 部署指南 |
| [Redis 安全](architecture/redis-security.md) | Redis 安全配置 |
| [桌面端图标规范](architecture/desktop-icon-design-spec.md) | 图标设计标准 |

---

## 开发指南

| 文档 | 说明 |
|------|------|
| [WebSocket 集成](guides/websocket-integration.md) | 客户端 WebSocket 接入 |
| [登录 WebSocket 集成](guides/login-websocket-integration.md) | 登录流程与 WS 结合 |
| [错误处理规范](guides/error-handling.md) | 后端错误处理 |
| [SQL 开发规范](guides/sql-development.md) | 数据库开发指南 |

---

## 测试文档

| 文档 | 说明 |
|------|------|
| [**测试工作流程指南**](testing/README.md) | **测试策略、流程与规范总纲** |
| [测试架构（五模块）](testing/test-architecture.md) | 五模块测试边界与框架选择 |
| [Backend 测试说明](testing/backend-testing.md) | 后端单元/集成/契约测试写法 |
| [Backend 单元测试计划](testing/backend-test-plan.md) | 后端测试现状与补充计划 |
| [E2E 测试指南](testing/e2e-testing-guide.md) | Patrol 框架使用详解 |
| [E2E 测试路径](testing/test-paths.md) | 移动端用户旅程测试 |
| [快速测试指南](testing/quick-test.md) | 5 分钟快速验证 |
| [WebSocket 测试](testing/websocket-test.md) | WS 实时分发测试 |
| [添加好友测试](testing/add-friend.md) | 好友功能测试用例 |
| [桌面端测试架构](testing/desktop-add-member-go-test-architecture.md) | Go 集成测试设计 |

---

## 运维部署

| 文档 | 说明 |
|------|------|
| [部署环境](operations/deployment-env.md) | 环境配置说明 |
| [开发与构建](operations/dev-and-build.md) | 本地开发指南 |
| [Docker 部署](operations/docker-deploy.md) | 容器化部署 |
| [故障排查手册](operations/troubleshooting.md) | 常见问题排查 |
| [备份与恢复](operations/backup-restore.md) | 数据备份策略 |
| [升级与迁移](operations/upgrade-migration.md) | 版本升级指南 |

---

## 安全文档

| 文档 | 说明 |
|------|------|
| [安全概述](security/security-overview.md) | 安全措施详解 |
| [安全检查清单](security/security-checklist.md) | 安全检查项 |

---

## 法律文档

| 文档 | 说明 |
|------|------|
| [隐私政策](legal/privacy-policy.md) | 个人信息保护政策 |
| [用户协议](legal/user-agreement.md) | 用户服务条款 |

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

**文档最后更新**: 2026-01-13
