# 任务清单

> 本文件用于记录 **RedCode IM** 当前仍需推进的工作流与优先级。默认执行主线以 `docs/plans/2026-04-09-admin-rbac-architecture-refactor-plan.md` 为准。

**最后更新**: 2026-04-11

---

## 当前主执行线（P0）

1. **Admin 架构重构收尾**
   - 主计划：`docs/plans/2026-04-09-admin-rbac-architecture-refactor-plan.md`
   - 当前优先顺序：
     1. `admin/src/api/*` -> 领域服务收口
     2. 删除 compatibility / mock / template 残留
     3. 清理 legacy 结构与无效说明文件

2. **B2 / bootstrap / SQL 合同闭环**
   - 覆盖对象：
     - `backend/src/storage/b2.rs`
     - `backend/src/handlers/auth.rs`
     - `backend/sql/base.sql`
     - `backend/sql/migrations/`
   - 目标：
     - B2 后台配置、后端校验、文档、测试一致
     - 首管 bootstrap 初始化闭环稳定
     - SQL base 与 migration 逻辑自洽

3. **补齐 admin / backend 合约测试**
   - 当前最缺：
     - bootstrap
     - RBAC
     - storage provider B2
     - message runtime settings
   - 入口：
     - `admin/playwright-tests/`
     - `tests/go/`
     - `tests/run.sh`

---

## 下一层工作（P1）

1. **Message runtime 全链路切换**
   - 当前后台已支持配置面与部分行为约束。
   - 下一步需补齐：
     - relay_only 下客户端降级
     - plaintext / e2ee 模式消费差异
     - 搜索 / 历史 / 引用 / 转发 / 反应 / 已读等链路的一致行为

2. **Dashboard / dev mock 债务清理**
   - `admin/src/mock/`
   - `admin/src/features/dashboard/**/mock.ts`
   - 需要明确哪些仍保留为开发态模拟，哪些应删除或替换成真实接口。

3. **测试入口与命令体系整理**
   - 根目录 `Makefile`
   - `docs/reference/testing/README.md`
   - 各模块 README
   - 目标是把常用 dev / test / verify 命令整理成稳定入口。

---

## 暂挂工作流（P2，不并入当前主线）

1. **移动端 / 桌面端大规模脏改动整理**
   - 当前工作区存在大量 `frontend/`、`desktop/` 变更，后续需要单独分流，不应混入 admin 主线提交。

2. **E2EE 真正落地**
   - 设计文档：`docs/reference/architecture/end-to-end-encryption-design.md`
   - 当前仍属于后续独立工作流，不纳入本轮最小闭环。

3. **跨模块文档清理**
   - 目前有一批 README / docs 删除与迁移，等主线闭环后再统一整理。

---

## 已完成的当前主线里程碑

- ✅ Admin feature-based 路由/页面迁移
- ✅ Admin RBAC 页面落地
- ✅ App providers / layouts / router 收口
- ✅ shared auth runtime / http 服务收口
- ✅ 首个超级管理员改为 bootstrap 初始化
- ✅ Admin 关键 Playwright 回归 18 条通过
- ✅ B2 provider 编辑时显式清空 `bucket_name` 会被后端拒绝，并补齐 Go 合同测试
- ✅ `database_migration_smoke` 环境变量串扰已收口，`cargo test` 可稳定通过
- ✅ SQL baseline / active migration / verify 脚本口径已统一到 bootstrap-first 流程
- ✅ message runtime settings 已补 Go contract，并与 live Playwright 回归对齐
- ✅ bootstrap status / repeat init 拒绝语义已补 Go contract
- ✅ RBAC 已补管理员登录快照 / 权限检查接口的 Go contract
- ✅ 根 Makefile 已整理为模块化入口，frontend 默认真机已切到 Pixel 8 Pro
- ✅ `tests/run.sh` 已拆分为按 mode 执行的 backend contract 入口，并补了 workflow tooling 守护测试
- ✅ admin 已补 live Playwright 快捷脚本，并开始清理 lockfile / 测试产物 / 无用说明文件残留
- ✅ desktop 已对齐 macOS ad-hoc 打包脚本，并开始清理过期示例 / 说明残留
- ✅ 仓库级文档与配置已开始对齐：CE 兼容入口、API 文档路径、website 私有部署文件忽略
- ✅ backend 已开始把默认对象存储从 COS 专属约束泛化到 B2，并补了无默认存储时的举报列表降级处理
- ✅ frontend 已移除未接入业务的发现页与对应静态资源占位
- ✅ frontend 群设置已补群改名、加人/移人能力，并抽出好友选择面板与 room service 测试入口
- ✅ frontend 设置页与通用组件已开始收口：InputDialog 简化、设置项 trailing 固定化、Flutter 新 API 兼容替换
- ✅ frontend 运行脚本已切到 Pixel 8 Pro 默认真机，并在 development 真机启动前自动检测当前局域网 IP 注入 API / WS 地址
- ✅ frontend integration smoke 已统一切到 `IntegrationTestWidgetsFlutterBinding`，便于后续 Patrol / 真机联调复用
- ✅ frontend iOS Patrol harness 已接入 RunnerUITests / TestPlan 链路，并确认需避开默认 `8081 / 8082` 端口冲突
- ✅ frontend 消息转发已放开到富媒体消息，转发失败时保留失败态，并补了 rich message 转发测试
- ✅ frontend 聊天列表 / 搜索 / 群管理若干页已收口 Flutter 新 API 与 mounted 守卫，头像颜色种子改为稳定 roomId / senderId
- ✅ frontend 开发环境默认 API / WS 已切到 localhost，启动页更新弹窗已切 `PopScope`，历史聊天示例页残留已移除
- ✅ backend 剩余模块已完成统一格式收口，并重新验证 `cargo test` 全量通过
- ✅ admin 已移除 dev mock 自动注入链路，HTTP 拦截器已从 `src/api` 收口到 `src/services`
- ✅ admin 已把 dashboard / message 两组高频 `src/api` 调用迁到 `src/services`
- ✅ admin 已把 user / version / audit / log / chat-history / emoji 等小型 `src/api` 文件迁到 `src/services`
- ✅ admin 已完成 `src/api` 业务依赖清零，`settings.ts` 也已迁入 `src/services`
- ✅ admin 已把单体 `services/settings.ts` 拆分为 documents / push / storage / general 四组领域服务
