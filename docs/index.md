# 文档索引

> 本文档用于索引 `docs/` 目录下的核心文档。快速开始请查看仓库根目录 `README.md`。

## AI 工作流（agent-light-workflow + CE 兼容）

| 文档 | 说明 |
|------|------|
| [需求/方向讨论](brainstorms/) | `brainstorm` / `ce:brainstorm` 产出目录 |
| [规划文档目录](plans/) | `plan` / `ce:plan` 产出目录 |
| [审查/验证记录](reviews/) | `review` / `ce:review` 产出目录 |
| [任务清单](reports/task-list.md) | 当前 active 剩余任务总入口 |
| [剩余任务完整执行分解](reports/remaining-task-breakdown-2026-07-05.md) | 历史执行总账：2026-07 口径，已被 08-04-005 / task-list 取代 |
| [IM 2.0 正式开发总计划](plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md) | 2.0 的产品合同、U1-U13 总体顺序与发布门禁（已 superseded，客户端主线见 08-04-005） |
| [原生客户端重建执行计划](plans/2026-08-04-005-feat-native-client-rebuild-plan.md) | 当前客户端主线：android-app + ios-app 原生双端重建，弃用 Flutter app/ |
| [E2EE 发布最终收口计划](plans/2026-08-06-u10-e2ee-release-final-closure-plan.md) | 当前 U10 唯一执行入口：关闭 owned draft 恢复 P1、重建候选、独立复审与最终裁决 |
| [E2EE F6.2 整改与最终裁决计划](plans/2026-08-06-u10-e2ee-f62-remediation-final-plan.md) | 历史执行记录：已由发布最终收口计划取代 |
| [E2EE 最终收口执行计划](plans/2026-08-06-u10-e2ee-final-closure-execution-plan.md) | 历史执行记录：已由 F6.2 整改与最终裁决计划取代 |
| [E2EE 剩余收口执行计划](plans/2026-08-06-u10-e2ee-remaining-closure-execution-plan.md) | 历史执行记录：已由最终收口计划取代 |
| [E2EE 原生客户端最终验证](plans/2026-08-05-u10-e2ee-native-clients-final-verification-plan.md) | 已完成：三端场景矩阵、泄漏抽检与 P0-1 关闭证据 |
| [IM 2.0 剩余工作计划](plans/2026-08-03-001-feat-im-2-0-remaining-work-plan.md) | 历史执行总账：已并入 08-02-001 执行状态总账 |
| [IM 2.0 Flutter 多端重构计划](plans/2026-07-26-001-feat-im-2-0-flutter-multiplatform-rebuild-plan.md) | 历史决策记录：已由 08-02-001 承接 |
| [IM 2.0 HTML 设计源计划](plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md) | 历史决策记录：设计源已冻结并由 08-02-001 引用 |
| [IM UI 预览冻结与多端交付计划](plans/2026-08-01-002-refactor-im-ui-preview-stabilization-and-handoff-plan.md) | 已完成/历史：冻结基线与 handoff 已落地 |
| [IM UI 多端交付差异](../im-ui-html/docs/platform-handoff.md) | 设计源、原生双端和 H5 当前覆盖矩阵 |
| [Android 原生迁移计划](plans/2026-07-04-002-feat-android-app-native-migration-plan.md) | 历史参考：原生双端已于 2026-08-04 恢复为主线（见 08-04-005） |
| [H5 Flutter parity 计划](plans/2026-07-02-001-feat-h5-app-flutter-parity-plan.md) | 历史归档：Flutter parity 已由 2026-08-02-001 U9 关闭 |
| [解决方案沉淀](solutions/) | `compound` / `ce:compound` 产出目录 |
| [参考提示词](prompts/) | 可复制或改写给 Codex 的轻工作流提示词 |
| [Code Review Graph 受控使用](reference/tooling/code-review-graph.md) | CE 旁路证据的触发、操作、降级与回滚边界 |

> 当前仓库以 `agent-light-workflow` 的文档结构为主；CE 全局资源仅作为本机 Codex
> 技能兼容入口。

### 工作流骨架

1. `brainstorm`（需求清晰时可跳过）
2. `plan`
3. `execute`（Codex 中映射为 `ce:work`）
4. `review`
5. `compound`

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
| [群目录接口](reference/api/group-directory.md) | 联系人群目录与群聊收藏 |
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
| [消息运行模式](reference/architecture/message-runtime-modes.md) | 消息服务端持久化与 relay-only 模式 |
| [会话与历史数据生命周期](reference/architecture/conversation-state-lifecycle.md) | 群目录、会话归档、本机缓存与房间级历史边界 |
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
| [IM UI 预览一致性审查](reviews/2026-08-01-im-ui-preview-consistency-review.md) | 43 条正式路由的问题基线与关闭结果 |
| [IM UI 三设备回归](reviews/2026-08-01-im-ui-preview-device-regression.md) | 三设备自动化与人工截图验收记录 |

### 运维部署

| 文档 | 说明 |
|------|------|
| [部署环境](reference/operations/deployment-env.md) | 环境配置说明 |
| [开发与构建](reference/operations/dev-and-build.md) | 本地开发指南 |
| [Docker 部署](reference/operations/docker-deploy.md) | 容器化部署 |
| [GitHub Actions 构建发布](reference/operations/github-actions-build.md) | android-app / desktop / api 发布产物构建流程 |
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
| [剩余任务完整执行分解](reports/remaining-task-breakdown-2026-07-05.md) | 历史执行总账：2026-07 口径，已被 08-04-005 / task-list 取代 |
| [iOS 原生 parity 收口报告](reports/2026-07-04-ios-app-parity-cutover-readiness.md) | 历史归档：原生模块已于 2026-08-04 移除 |
| [API Compose 性能基线](reports/performance/api-compose-baseline-2026-07-01.md) | API Compose-first 性能指标与后续优化方向 |
| [项目评估报告](reports/project-status-assessment-report-2025-11-08.md) | 项目现状与风险 |
| [模块功能清单（2026-03-01）](reports/module-function-inventory-2026-03-01.md) | 五大模块功能基线 |
| [批次A验收报告（2026-03-01）](reports/2026-03-01-batch-a-acceptance.md) | 外部模拟与测试栈接入验收 |
| [批次B-1验收报告（2026-03-01）](reports/2026-03-01-batch-b1-auth-users-friends-acceptance.md) | API auth/users/friends 测试重建验收 |
| [批次B-2验收报告（2026-03-01）](reports/2026-03-01-batch-b2-rooms-messages-uploads-acceptance.md) | API rooms/messages/uploads 测试重建验收 |
| [批次B-3验收报告（2026-03-01）](reports/2026-03-01-batch-b3-versions-admin-ws-acceptance.md) | API versions/admin/ws 测试重建验收 |
| [批次C验收报告（2026-03-01）](reports/2026-03-01-batch-c-admin-acceptance.md) | Admin 测试重建验收 |
| [批次D验收报告（2026-03-01）](reports/2026-03-01-batch-d-app-acceptance.md) | App Flutter 测试重建验收（历史基线，Flutter 已废弃） |
| [批次E验收报告（2026-03-01）](reports/2026-03-01-batch-e-desktop-website-acceptance.md) | Desktop + Website 测试重建验收 |
| [全模块回归验收报告（2026-03-04）](reports/2026-03-04-full-module-regression-acceptance.md) | 全模块回归执行结果与问题处理记录 |

---

## 各模块 README

| 模块 | 说明 |
|------|------|
| [api](../api/README.md) | 后端服务 (Rust) |
| [android-app](../android-app/README.md) | 移动端 Android (Kotlin + Jetpack Compose) |
| [ios-app](../ios-app/README.md) | 移动端 iOS (Swift + SwiftUI) |
| [h5-app](../h5-app/README.md) | H5 App (Vue 3 + Vite 8) |
| [desktop](../desktop/README.md) | 桌面端 (Vue + Tauri) |
| [admin](../admin/README.md) | 管理后台 (Vue) |
| [website](../website/README.md) | 官网 |

---

**文档最后更新**: 2026-08-04
