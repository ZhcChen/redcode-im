# 任务清单

> 本文件用于记录 **RedCode IM** 当前仍需推进的工作流与优先级。默认执行主线以 `docs/plans/2026-04-09-admin-rbac-architecture-refactor-plan.md` 为准。

**最后更新**: 2026-04-12

---

## 当前主执行线（P0）

1. **Message runtime 全链路切换**
   - 当前后台已支持配置面与部分行为约束。
   - frontend / desktop 已完成第一轮 relay_only 降级闭环：
     - 客户端已消费并缓存 `message_runtime`
     - 聊天页动作菜单与多选栏已隐藏 relay_only 不支持动作
     - 发送 / 引用 / 转发 / pin / 删除 / reaction / 服务端已读同步已做 guard
     - 搜索页已切为“仅本地缓存搜索”并跳过服务端搜索
   - frontend / desktop 已补 plaintext / e2ee 展示层提示闭环：
     - 聊天输入区会展示当前审计模式与服务器存储策略提示
     - `e2ee` 提示文案明确为“按当前配置目标”，避免误导为协议已完整落地
   - frontend / desktop 已补 relay_only 历史链路一致性：
     - 进入会话优先使用本地缓存，不再额外请求服务端历史消息
     - desktop 已避免“本地有缓存但被空历史响应覆盖”的错位
   - frontend / desktop 已补 relay_only 历史定位提示：
     - 引用消息或置顶消息若不在本地缓存，会提示“当前模式不保存聊天记录，只能定位本地缓存中的消息”
   - frontend 已补 relay_only 离线补拉 guard：
     - WebSocket 重连认证后不会再触发服务端历史补拉
   - frontend / desktop 已补 relay_only 缓存摘要清洗：
     - 启动时若本地 chat cache 留有旧 `lastMessage / unreadCount / lastMessageId`，会先按 relay_only 规则清空，避免闪出旧摘要
   - frontend / desktop 已补 runtime 切换时的即时清洗：
     - 当 `persist -> relay_only` 在运行中生效时，会立刻清空当前会话列表残留摘要，并同步刷新当前聊天页 / 未读汇总
   - frontend / desktop 已补 relay_only 本地摘要回填：
     - 清洗旧摘要后，会基于本机消息缓存回填最近一条消息、最后消息 ID 与本地未读数，避免聊天列表长时间空白
   - frontend 已补 relay_only 本地已读收口：
     - 进入当前会话后会在本地立即清空未读数，不再依赖服务端已读接口
   - frontend 已补搜索页 runtime 响应式切换：
     - 若搜索页打开期间 runtime 从 persist 切到 relay_only，会自动切回“仅本地缓存搜索”
   - frontend 已补消息编辑/删除后的本地摘要即时刷新：
     - 最新一条消息在本地被编辑或删除后，会同步刷新 relay_only 聊天列表摘要，且不再受启动阶段 chat cache 初始化竞态影响
   - frontend 已补 live 消息摘要预览统一：
     - 实时收到图片/语音/文件等消息时，聊天列表会立即使用统一 preview 规则刷新摘要，并同步写入 `last_message_id`
   - frontend 已补本地主动编辑/删除摘要刷新：
     - 编辑或删除最新一条消息时，API 返回替换本地消息后会立即同步 chat summary，不再依赖后续 websocket 回推
   - desktop 已补消息更新缓存收口：
     - 编辑/删除事件会同步写回本地消息缓存，删除不再直接丢记录，relay_only 重启后仍能稳定重建 `[消息已删除]` 等摘要
   - 下一步需补齐：
     - 更多边缘交互的一致行为（如局部提示口径、剩余边缘按钮/跳转一致性）

2. **测试入口与命令体系整理**
   - 根目录 `Makefile`
   - `docs/reference/testing/README.md`
   - 各模块 README
   - 目标是把常用 dev / test / verify 命令整理成稳定入口。

3. **跨模块文档清理**
   - 聚焦当前已完成主线的 README / plan / report 口径同步。
   - 清理已失效的 legacy 目录引用与过期说明。

---

## 下一层工作（P1）

1. **Dashboard / dev mock 债务清理**
   - `admin/src/mock/`
   - `admin/src/features/dashboard/**/mock.ts`
   - 需要明确哪些仍保留为开发态模拟，哪些应删除或替换成真实接口。

2. **更细粒度的服务层拆分与共享类型整理**
   - 当前 `admin/src/services/` 已收口完成。
   - 后续可按业务域继续合并重复类型、抽共享 helper，减少横向重复。

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
- ✅ frontend 已补 `message_runtime` 本地缓存与 relay_only 第一轮降级：聊天页动作/多选栏裁剪、provider guard、本地缓存搜索提示与服务端搜索跳过
- ✅ frontend 已补 plaintext / e2ee 模式展示层消费：聊天输入区展示审计模式提示，并补充 runtime 文案测试
- ✅ frontend 已补 relay_only 历史加载 guard：进入会话与本地定位不再额外请求服务端历史
- ✅ frontend 已补 relay_only 引用定位提示：目标消息不在本地缓存时给出明确提示，并清理跳转加载提示队列
- ✅ frontend 已补 relay_only 离线补拉 guard：断线重连后跳过 `syncOfflineMessages` 的服务端历史请求
- ✅ frontend 已补 relay_only 会话缓存清洗：启动从 chat cache 恢复时先清空旧摘要与未读数
- ✅ frontend 已补 runtime 切换即时收口：`persist -> relay_only` 时会清空当前内存会话摘要，并刷新聊天页 runtime 提示
- ✅ frontend 已补 relay_only 本地摘要回填：会基于 SQLite 本地消息缓存重建最近消息预览、最后消息 ID 与本地未读数
- ✅ frontend 已补 relay_only 本地已读清零：进入会话后会立刻清空本地未读数，不再残留红点
- ✅ frontend 已补搜索页 runtime 响应式切换：搜索页打开期间若切到 relay_only，会立即隐藏服务端搜索并重跑本地搜索
- ✅ frontend 已补消息编辑/删除后的 relay_only 摘要即时刷新：`handleMessageUpdate` 会等待 chat cache 初始化完成，再刷新最新消息摘要与 `last_message_id`
- ✅ frontend 已补 live 消息摘要预览统一：实时收到图片/语音/文件等消息时，聊天列表摘要不再直接取 `message.content`，而是统一走 preview 规则并写入 `last_message_id`
- ✅ frontend 已补本地主动编辑/删除摘要刷新：`editMessage` / `markMessageDeleted` 通过 `_replaceMessage` 回写最新摘要，且相关 API helper 已统一走可注入 `_client`
- ✅ desktop 已补 `message_runtime` 公开设置消费与本地缓存，并完成 relay_only 第一轮降级：消息菜单裁剪、引用/转发/pin/删除/reaction/read sync guard、本地缓存搜索提示与服务端搜索跳过
- ✅ desktop 已补 plaintext / e2ee 模式展示层消费：聊天输入区展示审计模式提示，并补充 runtime 文案测试
- ✅ desktop 已补 relay_only 历史链路收口：优先保留本地缓存消息，不再被服务端空历史覆盖
- ✅ desktop 已补历史定位失败提示：目标消息不在当前缓存时不再静默无反馈
- ✅ desktop 已补 relay_only 会话缓存清洗：缓存聊天列表恢复时先清空旧摘要与未读数
- ✅ desktop 已补 runtime 切换即时收口：`persist -> relay_only` 时会同步清空当前 store/chat page 残留摘要，并刷新账号未读汇总
- ✅ desktop 已补 relay_only 本地摘要回填：会基于本地消息缓存重建最近消息预览、最后消息 ID 与本地未读数
- ✅ desktop 已补消息更新缓存收口：编辑/删除事件会同步写回本地消息缓存，删除消息保留 tombstone 以保证 relay_only 重启后摘要与未读统计一致
- ✅ backend 剩余模块已完成统一格式收口，并重新验证 `cargo test` 全量通过
- ✅ admin 已移除 dev mock 自动注入链路，HTTP 拦截器已从 `src/api` 收口到 `src/services`
- ✅ admin 已把 dashboard / message 两组高频 `src/api` 调用迁到 `src/services`
- ✅ admin 已把 user / version / audit / log / chat-history / emoji 等小型 `src/api` 文件迁到 `src/services`
- ✅ admin 已完成 `src/api` 业务依赖清零，`settings.ts` 也已迁入 `src/services`
- ✅ admin 已把单体 `services/settings.ts` 拆分为 documents / push / storage / general 四组领域服务
- ✅ `backend/scripts/verify-base-sql.sh` 已通过，SQL baseline / active migration / legacy 归档口径一致
- ✅ `./tests/run.sh go` 已完整通过，admin/bootstrap/RBAC/B2/message runtime 等后端合约链路稳定
