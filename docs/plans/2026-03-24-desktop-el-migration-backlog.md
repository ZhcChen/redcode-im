# Desktop EL Migration Backlog

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each backlog item as an independent plan/task chain. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `desktop-el` 从当前“登录 + 联系人 + 私聊 + 文本消息 + 最小实时同步”阶段，推进到可逐步替代旧 `desktop`（Tauri）模块的 Electron + Go core 实现。

**Architecture:** 持续坚持 Electron 只做宿主壳、Go core 承接全部业务核心、renderer 只通过 stdio RPC 与 Go core 交互，不为桌面端业务额外开放本地 HTTP 服务端口。每一刀都走最小闭环，避免整包搬运旧 `vuex/router/Tauri` 实现。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、Gorilla WebSocket、backend HTTP/WS、现有 `desktop-el` worktree

---

## 当前基线

- [x] 登录、注册、短信验证码、协议文档已通过 Go core 接入。
- [x] 主壳 `HomeShell`、聊天 / 联系人 / 设置三栏骨架已落地。
- [x] 联系人列表、好友申请列表、通过 / 拒绝申请、从联系人详情发起私聊已完成。
- [x] 联系人模块已完成全局搜人、发送好友申请，以及 `self` / `friend` / `pending` 状态识别的最小闭环。
- [x] 联系人模块已完成备注编辑、删除好友，以及 `friend_request_update` / `friend_profile_updated` / `friendship_deleted` 的最小实时刷新。
- [x] 聊天会话列表、私聊房间 ensure、最近 50 条历史消息、文本发送已完成。
- [x] Go core 已打通 websocket 读循环，renderer 已接入 `message` / `message_read` 的最小实时闭环。
- [x] 当前房间已支持 `read_until` 回写。

## P0

### P0-1: 聊天消息深水区

**目标:** 把当前“只支持文本消息”的聊天能力推进到日常可用级别。

**当前缺口:**
- 转发、撤回、重发未迁移。
- `pin_update`、`reaction_update`、`typing_update` 等 websocket 事件未接入。
- 已读成员列表和更细的消息状态展示未接入。

**当前进度:**
- [x] 已完成消息删除与 `message_update` 最小同步闭环。
- [x] 已完成引用回复最小闭环：renderer 已能展示 quoted block、在 composer 中设置 / 取消回复目标，并通过 `quoted_message_id` 发送文本、附件或 mixed message。
- [ ] 转发、撤回、重发与更完整的消息操作菜单仍未迁移。

**建议切口:**
- [ ] 先补 Go core chat RPC 与 WS 事件透传，不在 renderer 直接拼业务请求。
- [ ] 再补 renderer 的消息操作菜单、状态展示与局部刷新。
- [ ] 每次只接一类消息操作，避免把旧 [Chat.vue](/Users/chen/code/redcode-im/desktop/src/views/Chat.vue) 整包复制过来。

**关键参考:**
- [ChatPanel.vue](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/renderer/src/components/ChatPanel.vue)
- [message.ts](/Users/chen/code/redcode-im/desktop/src/api/message.ts)
- [Chat.vue](/Users/chen/code/redcode-im/desktop/src/views/Chat.vue)

### P0-2: 媒体与附件消息闭环

**目标:** 支持图片、视频、语音、文件消息的发送、展示、预览、下载。

**当前缺口:**
- 新端只做了消息类型映射，没有上传、下载、预览流程。
- 文件选择、保存、下载路径等 Electron 宿主能力尚未与业务真正接通。

**当前进度:**
- [x] 已完成附件消息读侧最小闭环：renderer 可识别附件 part，经 Go core `chat.attachment.download_url` 获取 signed URL，再通过 Electron 宿主保存到本地并打开。
- [x] 已完成附件消息写侧最小闭环：`ChatPanel` 已接入文件选择，renderer 通过 Go core 获取 direct upload / multipart upload envelope，浏览器直传 object storage，必要时执行 `chat.attachment.upload.commit`，最后调用 `chat.send(parts)` 发送单附件消息。
- [x] 已完成最近消息的图片放大预览、视频内联播放、语音内联播放最小闭环；预览 URL 仍通过 Go core `chat.attachment.download_url` 获取 signed URL，不增加本地 HTTP 端口。
- [x] 已完成多附件发送与文本 + 附件混发：composer 支持多文件选择、顺序上传、聚合进度展示，并通过一次 `chat.send(parts)` 发出 mixed message。
- [x] 已完成视频消息缩略图优先展示：存在 `thumbnail_key` 时优先拉取缩略图 signed URL，点击后再加载真实视频 URL 进入预览。
- [ ] 本地媒体缓存与更完整的预览体验仍未迁移。

**建议切口:**
- [x] 先补图片 / 视频 / 语音 / 文件消息的最小下载与打开闭环。
- [x] 再补文件选择与上传签名 / 分片 / 发送闭环。
- [x] 继续补图片 / 视频预览与语音播放（最小内联版本）。
- [ ] 语音消息播放先于录音迁移，录音可放到后续批次。

**关键参考:**
- [chat.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/renderer/src/api/chat.ts)
- [file.ts](/Users/chen/code/redcode-im/desktop/src/api/file.ts)
- [message.ts](/Users/chen/code/redcode-im/desktop/src/api/message.ts)
- [shell-api.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/electron/main/shell-api.ts)

### P0-3: 群聊最小闭环

**目标:** 让 `desktop-el` 不再只支持私聊，补齐“创建群聊 -> 进入群聊 -> 读取群消息 -> 基础群信息展示”。

**当前进度:**
- [x] 已完成“创建群聊 -> 自动进入新群”最小闭环：Go core 新增 `chat.group.create` RPC，renderer 已接入建群弹窗、好友选择、表单校验、创建成功后刷新会话列表并优先按 `roomId` / `roomName` 自动定位新群。
- [x] 群会话读取与基础信息展示已沿用现有会话列表 / 历史消息面板能力接通，不再局限私聊房间。
- [x] 已完成当前选中群聊的基础详情面板：renderer 通过 Go core `chat.room.get` / `chat.room.members.list` 拉取群资料和成员列表，当前可展示群名、群简介、群主、成员数、创建时间与最小成员列表。
- [x] 已完成 `room_created` / `room_updated` 的群聊最小刷新：会话列表会随房间创建或资料变更刷新，若命中当前群聊则会同步刷新群详情面板。
- [ ] 群头像、群设置与群管理仍未迁移。

**当前缺口:**
- 群头像与群设置入口仍未接回。
- 群成员列表目前只有最小展示，还没有完整成员面板和管理动作。
- 更深的群相关 websocket 事件，例如群成员/群设置/群主转让/解散等，仍未接入统一刷新链路。

**建议切口:**
- [x] 先补建群与基础群房间进入。
- [x] 再补群消息列表与群详情基础展示。
- [ ] 最后再拆出群设置与群管理，不要一刀做完。

**关键参考:**
- [group.ts](/Users/chen/code/redcode-im/desktop/src/api/group.ts)
- [Chat.vue](/Users/chen/code/redcode-im/desktop/src/views/Chat.vue)

### P0-4: 联系人主流程补齐

**目标:** 让联系人模块从“查看和处理申请”升级到完整可操作。

**当前缺口:**
- 联系人模块主流程已打通；后续主要是更细粒度的全局同步和体验增强，不再是 P0 主阻塞。

**当前进度:**
- [x] 已完成搜索用户与发起好友申请：renderer 通过 `user.search` / `friend.request.create` 调用 Go core，联系人页已支持全局搜人、填写申请留言、发送好友申请。
- [x] 已完成搜索结果关系态识别：联系人页会结合当前联系人列表和 outgoing pending 请求，区分 `自己` / `已是好友` / `已发申请` / `可添加`。
- [x] 已完成删除好友、修改好友备注：联系人详情区可直接保存备注，或经宿主确认后删除好友，并刷新联系人列表。
- [x] 已完成 `friend_request_update` / `friend_profile_updated` / `friendship_deleted` 的联系人页最小刷新：联系人视图活跃时会基于 `ws.push` 重新拉取数据并保持当前选择态。

**建议切口:**
- [x] 先补搜索用户与发起好友申请。
- [x] 再补删除好友与好友备注编辑。
- [x] 接入 `friend_profile_updated` 等最小事件刷新。

**关键参考:**
- [ContactPanel.vue](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/renderer/src/components/ContactPanel.vue)
- [friend.ts](/Users/chen/code/redcode-im/desktop/src/api/friend.ts)
- [Contact.vue](/Users/chen/code/redcode-im/desktop/src/views/Contact.vue)

### P0-5: 设置页主流程补齐

**目标:** 让设置页具备替代旧设置页的核心操作能力。

**当前状态:**
- 头像上传已迁移为 renderer 直传对象存储 + backend commit。
- 账号安全基础项（修改密码）与反馈提交已迁移。
- 版本检查、安装包下载与打开安装包已迁移。

**建议切口:**
- [x] 先补头像上传。
- [x] 再补账号安全基础项（修改密码）。
- [x] 再补反馈提交。
- [x] 最后补更新下载 / 安装链路。

**关键参考:**
- [SettingsPanel.vue](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/renderer/src/components/SettingsPanel.vue)
- [version.ts](/Users/chen/code/redcode-im/desktop/src/api/version.ts)
- [rust-user.ts](/Users/chen/code/redcode-im/desktop/src/api/rust-user.ts)

## P1

### P1-1: 群管理深水区

**目标:** 补齐旧桌面端的群管理能力。

**范围:**
- [ ] 群设置
- [ ] 群管理员管理
- [ ] 入群申请管理
- [ ] 禁言管理
- [ ] 群规管理
- [ ] 群操作日志
- [ ] 群头像上传

**关键参考:**
- [group.ts](/Users/chen/code/redcode-im/desktop/src/api/group.ts)
- 旧端群管理相关弹窗组件集合

### P1-2: 消息搜索

**目标:** 支持聊天消息搜索、本地结果展示与服务端补全。

**范围:**
- [ ] Go core 补搜索 RPC
- [ ] renderer 搜索 UI 与结果列表
- [ ] 从当前聊天上下文进入搜索

**关键参考:**
- [message-search.ts](/Users/chen/code/redcode-im/desktop/src/api/message-search.ts)
- `MessageSearch.vue`

### P1-3: Electron 宿主能力与业务接通

**目标:** 把已经存在的 Electron 壳能力真正接入业务闭环。

**当前已具备的壳能力:**
- [x] 托盘
- [x] 通知
- [x] 对话框
- [x] 窗口控制

**尚未完成的业务接通:**
- [ ] 消息到达通知
- [ ] 文件选择 / 保存与下载链路
- [ ] 媒体预览与打开本地文件
- [ ] 业务侧对 tray / window 的显式控制

**关键参考:**
- [tray.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/electron/main/tray.ts)
- [notification.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/electron/main/notification.ts)
- [dialog.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/electron/main/dialog.ts)
- [shell-api.ts](/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/electron/main/shell-api.ts)

### P1-4: 更完整的 websocket 事件面

**目标:** 把旧桌面端依赖的关键业务推送逐步接回 `desktop-el`。

**范围:**
- [x] `room_created`
- [x] `room_updated`
- [x] `friend_request_update`
- [x] `friend_profile_updated`
- [ ] 群成员 / 群状态相关事件

**原则:**
- 先由 Go core 统一转成 stdio 事件。
- renderer 只接当前切口需要的最小事件，不把旧 WS 管理器完整复刻。

## P2

### P2-1: 多账号架构

**目标:** 迁移旧桌面端的多账号能力。

**范围:**
- [ ] 多账号登录态并存
- [ ] 账号切换
- [ ] 每账号独立 ws / routeState / 会话状态
- [ ] 账号页签与恢复逻辑

**说明:** 这是高复杂度任务，依赖聊天、联系人、设置的单账号主流程先稳定。

**关键参考:**
- [accounts.ts](/Users/chen/code/redcode-im/desktop/src/store/modules/accounts.ts)

### P2-2: 桌面体验增强

**范围:**
- [ ] 语音录制
- [ ] 快捷键
- [ ] 拖拽上传
- [ ] 上下文菜单
- [ ] 媒体预缓存 / 更多细节交互

### P2-3: `desktop-el` 专属测试体系

**目标:** 让 `desktop-el` 自身具备可持续回归的测试矩阵。

**范围:**
- [ ] Go core 集成测试继续扩充
- [ ] Electron main / preload 测试扩充
- [ ] renderer 级 smoke / e2e 方案
- [ ] 关键迁移闭环形成固定验收脚本

### P2-4: 文档收口

**范围:**
- [ ] 给每个 P0 / P1 切口补独立计划文档
- [ ] 回填旧聊天计划文档中未勾选但已完成的提交步骤
- [ ] 形成 `desktop-el` 迁移进度总表

## 推荐执行顺序

1. `P0-1` 聊天消息深水区
2. `P0-2` 媒体与附件消息闭环
3. `P0-3` 群聊最小闭环
4. `P0-4` 联系人主流程补齐
5. `P0-5` 设置页主流程补齐
6. `P1-1` 群管理深水区
7. `P1-2` 消息搜索
8. `P1-3` Electron 宿主能力与业务接通
9. `P1-4` 更完整的 websocket 事件面
10. `P2-1` 多账号架构
11. `P2-2` / `P2-3` / `P2-4` 作为收口阶段并行推进

## 执行规则

- [ ] 始终坚持 Electron 只是宿主壳。
- [ ] 全部业务核心尽量下沉 Go core。
- [ ] Electron / renderer 与 Go core 一律通过 stdio RPC 交互。
- [ ] 不为 `desktop-el` 业务额外开放本地 HTTP 端口。
- [ ] 每次启动前先清旧实例，避免 Electron 客户端堆积。
- [ ] 每一刀都按“最小闭环 + 可验证 + 可提交”的方式推进。
