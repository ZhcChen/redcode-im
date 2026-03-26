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
- 更细粒度的消息管理增强项仍未迁移。

**当前进度:**
- [x] 已完成消息删除与 `message_update` 最小同步闭环。
- [x] 已完成引用回复最小闭环：renderer 已能展示 quoted block、在 composer 中设置 / 取消回复目标，并通过 `quoted_message_id` 发送文本、附件或 mixed message。
- [x] 已完成消息转发最小闭环：Go core 新增 `chat.forward` RPC，renderer 已接入目标会话选择弹窗、`forward_message -> forwardInfo` 映射，以及消息卡片“转发自 xxx”来源展示。
- [x] 已完成消息置顶最小闭环：Go core 新增 `chat.pin` / `chat.unpin` RPC，renderer 已接入消息级置顶/取消置顶按钮、消息置顶徽标，以及 `pin_update` 当前会话局部同步。
- [x] 已完成消息 reaction 最小闭环：Go core 新增 `chat.reactions.add/remove/list` RPC，renderer 已接入固定 reaction picker、reaction 标签点击切换，以及 `reaction_update` 当前会话局部同步。
- [x] 已完成消息已读成员列表最小闭环：Go core 新增 `chat.message.readers.list` RPC，renderer 已接入消息卡片“已读成员”入口、按需拉取 readers 的最小弹窗，以及会话切换时的局部收口。
- [x] 已完成 `typing_update` 最小闭环：Go core 新增 `ws.join` / `ws.leave` / `chat.typing.send` RPC，renderer 已在当前会话维护最小房间订阅、按旧端节流策略发送 typing 状态，并在消息区展示“正在输入”提示。
- [x] 已完成文本 / 引用文本消息发送失败态与手动重发最小闭环：renderer 已接入本地 sending/failed 气泡、房间级失败消息保留、失败消息移除与手动重投；当前仍不支持附件重发与自动重试。
- [x] 已完成附件 / mixed message 发送失败态与手动重发最小闭环：renderer 现在会在上传前先落本地 sending 消息，失败后保留附件卡片与 retry payload，并支持手动重新上传发送；当前仍不支持自动重试与本地持久化失败箱。
- [x] 已完成自动重试与本地持久化失败箱最小闭环：失败文本 / 引用文本消息现在会按当前用户持久化到 localStorage，应用启动后恢复到房间本地消息队列，并按 3 秒间隔继续自动重试；附件 / mixed message 当前仍只支持会话内自动重试与手动重发，不做跨重启文件体恢复。
- [x] 已完成消息多选模式最小闭环：renderer 已支持通过消息菜单进入多选、批量选择消息、批量转发到单个目标会话、批量删除本地失败消息或远端自发消息，并支持通过 `Esc` 或显式按钮退出多选。
- [x] 已完成消息拖拽框选最小闭环：renderer 现在可在消息列表中按住左键跨消息拖拽，自动进入多选模式并按消息范围选中；拖拽过程中会清理浏览器文本选中，并跳过按钮、输入框、音视频控件等交互元素。
- [x] 已完成消息编辑与更完整的消息操作菜单最小闭环：Go core 新增 `chat.edit` RPC，renderer 已接入统一“更多”菜单、复制、编辑、引用、转发、置顶、反应、已读成员，以及 `chat.delete -> 撤回` 的用户语义；`message_update(edited)` 现在会对当前会话做局部收敛。
- [ ] 更细粒度的消息管理增强项仍可继续迭代。

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
- 缓存清理策略、连续浏览 / 手势缩放等更完整预览体验仍未迁移。
- 更细的录后编辑（如裁剪 / 精编）与更多媒体细节交互仍未迁移。

**当前进度:**
- [x] 已完成附件消息读侧最小闭环：renderer 可识别附件 part，经 Go core `chat.attachment.download_url` 获取 signed URL，再通过 Electron 宿主保存到本地并打开。
- [x] 已完成附件消息写侧最小闭环：`ChatPanel` 已接入文件选择，renderer 通过 Go core 获取 direct upload / multipart upload envelope，浏览器直传 object storage，必要时执行 `chat.attachment.upload.commit`，最后调用 `chat.send(parts)` 发送单附件消息。
- [x] 已完成最近消息的图片放大预览、视频内联播放、语音内联播放最小闭环；预览 URL 仍通过 Go core `chat.attachment.download_url` 获取 signed URL，不增加本地 HTTP 端口。
- [x] 已完成多附件发送与文本 + 附件混发：composer 支持多文件选择、顺序上传、聚合进度展示，并通过一次 `chat.send(parts)` 发出 mixed message。
- [x] 已完成视频消息缩略图优先展示：存在 `thumbnail_key` 时优先拉取缩略图 signed URL，点击后再加载真实视频 URL 进入预览。
- [x] 已完成本地媒体缓存最小闭环：Electron file API 新增内部缓存目录命中 / 下载能力，renderer 已在图片 / 视频 / 音频预览与“打开附件”链路中优先命中本地缓存，cache miss 时才回退 signed URL 下载。
- [x] 已完成语音录音发送最小闭环：renderer 新增基于浏览器 `MediaRecorder` 的录音弹层，录音文件带 `durationMs` 扩展属性并复用现有附件上传、本地 sending/failed 消息、自动重试与手动重发链路；全程不新增 Go core RPC，也不打开本地 HTTP 端口。
- [x] 已完成录音预览波形最小闭环：renderer 新增本地 waveform helper，经 Web Audio 解码录音 Blob 后生成预览 bars；失败时静默降级为占位波形，不阻断试听与发送。
- [x] 已完成录后编辑第一刀：语音录音预览态现在支持修改文件名，再继续复用现有附件发送与失败重试链路；当前仍不做裁剪与片段编辑。
- [ ] 更完整的预览体验与缓存治理仍未迁移。

**建议切口:**
- [x] 先补图片 / 视频 / 语音 / 文件消息的最小下载与打开闭环。
- [x] 再补文件选择与上传签名 / 分片 / 发送闭环。
- [x] 继续补图片 / 视频预览与语音播放（最小内联版本）。
- [x] 再补宿主内部缓存目录与本地缓存命中。
- [x] 再补录音发送最小闭环，继续复用现有附件上传与失败重试链路。

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
- [x] 已完成当前选中群聊的只读群设置面板：renderer 通过 Go core `chat.group.settings.get` 拉取群设置，当前可展示全员禁言、入群审批、成员邀请、最大人数以及当前用户个人禁言状态。
- [x] 已完成 `group_settings_updated` / `group_member_changed` 的群聊最小刷新：会话列表会保持刷新，若命中当前群聊则会同步刷新群详情与群设置；当前用户被禁言 / 解除禁言时会给出最小 notice 提示。
- [x] 已完成全员禁言写侧最小闭环：群设置面板可直接开启 / 解除全员禁言，renderer 通过 Go core `chat.group.settings.global_mute.update` 调 backend，不新增本地 HTTP 端口。
- [x] 群聊输入区已接入群禁言态：当前用户被个人禁言时会禁用 composer；全员禁言开启时，非群主管理员无法继续发送文本或附件。
- [x] 已完成入群审批和成员邀请两个设置开关：群设置面板可直接切换 `join_approval_required` / `member_can_invite`，成功后立即刷新当前群设置。
- [x] 已完成剩余群设置写侧：群设置面板已补齐 `member_can_add_friends`、`require_admin_to_add_friends` 与 `max_members` 的原位更新入口，继续复用 Go core `chat.group.settings.update`，不新增本地 HTTP 端口。
- [x] 已完成群头像上传最小闭环：群主 / 管理员可在群详情面板上传群头像，renderer 通过 backend `direct-upload + commit` 直传对象存储，并在会话列表 / 会话头部优先展示图片头像。
- [x] 已完成群管理主流程的最小闭环：成员管理、管理员管理、入群申请、禁言、群规、操作日志与完整成员面板均已迁移。
- [x] 已完成退出群聊 / 解散群聊最小闭环：renderer 已接入 `chat.group.leave` / `chat.group.dissolve`，普通成员可退出当前群聊，群主可直接解散群聊；成功后会立即收口当前会话并刷新会话列表。
- [x] 已完成 `group_dissolved` 最小事件收敛：Go core 已透传群解散事件，renderer 命中当前群时会自动退出该会话并刷新会话列表。
- [x] 已完成 `group_owner_transferred` 最小事件收敛：renderer 已接入群主转让事件映射与当前群刷新；当前用户成为新群主或失去群主身份时会收到 notice，并同步刷新群详情 / 群设置。

**当前缺口:**
- 更深的群相关 websocket 事件，例如管理员调整、入群审批流等，仍未接入统一刷新链路。

**建议切口:**
- [x] 先补建群与基础群房间进入。
- [x] 再补群消息列表与群详情基础展示。
- [x] 再补群设置读侧与最小群事件刷新。
- [x] 再补全员禁言写侧和输入区禁用态。
- [x] 再补入群审批和成员邀请两个设置开关。
- [x] 再补剩余群设置写侧。
- [x] 再补群头像上传。
- [ ] 最后再拆出群管理，不要一刀做完。

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

**当前进度:**
- [x] 群头像上传
- [x] 已完成现有群聊添加成员：群主 / 管理员可从好友列表选择成员并加入当前群，成功后刷新群详情、群设置与会话列表。
- [x] 已完成现有群聊删除成员：群主 / 管理员可选择并移除非群主成员，成功后刷新群详情、群设置与会话列表。
- [x] 已完成群主转让最小闭环：群主可在当前群成员中选择新的群主并完成转让，成功后刷新群详情、群设置与会话列表。
- [x] 已完成群管理员管理最小闭环：群主可查看当前管理员列表、任命管理员、撤销管理员，成功后刷新群详情、群设置与会话列表。
- [x] 已完成入群申请管理最小闭环：群主 / 管理员可查看入群申请、通过或拒绝申请，成功后刷新群详情、群设置与会话列表。
- [x] 已完成成员禁言管理最小闭环：群主 / 管理员可查看当前禁言列表、按预设时长或永久禁言普通成员，并解除禁言；成功后刷新群详情、群设置、会话列表与禁言列表。
- [x] 已完成群规管理最小闭环：群成员可查看当前群规，群主 / 管理员可新增、编辑和删除群规；操作后即时刷新群规列表。
- [x] 已完成群操作日志最小闭环：群主 / 管理员可查看最近操作日志并继续分页加载，当前可展示操作时间、操作人、操作内容与目标成员。
- [x] 已完成群管理权限拆细第一轮：`ChatPanel` 现已区分 owner-only（管理员 / 操作日志 / 转让群主）、owner-admin（成员管理 / 入群审核 / 禁言 / 群设置写侧 / 群头像）和 member-readonly（群规只读）。
- [x] 已完成完整成员面板最小闭环：群详情支持打开“全部成员”面板，查看全量成员、搜索成员、查看角色统计，并从面板进入添加成员 / 删除成员 / 管理员设置 / 转让群主等现有管理动作。

**范围:**
- [x] 群设置（已完成全员禁言、入群审批、成员邀请、群内加好友与人数上限等主流程）
- [x] 群成员管理（已完成添加成员、删除成员、群主转让、更细权限控制与完整成员面板）
- [x] 群管理员管理（已完成列表、任命、撤销最小闭环，并已拆出 owner-only 权限入口）
- [x] 入群申请管理（已完成列表和单条审核最小闭环，更深审批流联动仍未迁移）
- [x] 禁言管理（已完成列表、创建禁言、解除禁言最小闭环，更细权限策略与联动仍未迁移）
- [x] 群规管理（已完成列表、新增、编辑、删除最小闭环，拖拽排序与富文本编辑仍未迁移）
- [x] 群操作日志（已完成列表与加载更多最小闭环，筛选、搜索与导出仍未迁移）
- [x] 解散群聊 / 退出群聊

**关键参考:**
- [group.ts](/Users/chen/code/redcode-im/desktop/src/api/group.ts)
- 旧端群管理相关弹窗组件集合

### P1-2: 本地消息搜索

**目标:** 支持当前聊天上下文内的本地消息搜索、结果展示与消息定位。

**当前进度:**
- [x] 已完成当前聊天上下文内的本地消息搜索最小闭环：renderer 新增本地搜索 helper、搜索弹层、结果高亮与点击定位，当前仅搜索当前会话已加载的本地消息，不依赖 Go core 搜索 RPC。

**范围:**
- [x] renderer 本地搜索 helper 与结果高亮
- [x] renderer 搜索 UI 与结果列表
- [x] 从当前聊天上下文进入搜索

**关键参考:**
- [MessageSearch.vue](/Users/chen/code/redcode-im/desktop/src/components/MessageSearch.vue)
- [SearchDialog.vue](/Users/chen/code/redcode-im/desktop/src/components/SearchDialog.vue)

### P1-3: Electron 宿主能力与业务接通

**目标:** 把已经存在的 Electron 壳能力真正接入业务闭环。

**当前已具备的壳能力:**
- [x] 托盘
- [x] 通知
- [x] 对话框
- [x] 窗口控制

**尚未完成的业务接通:**
- [x] 消息到达通知
- [x] 文件选择 / 保存与下载链路
- [x] 媒体预览与打开本地文件
- [x] 业务侧对 tray / window 的显式控制

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
- [x] `typing_update`
- [x] `group_settings_updated`
- [x] `group_member_changed`
- [x] `group_dissolved`
- [x] `group_owner_transferred`
- [x] 管理员调整 / 入群审批等更深群事件

**原则:**
- 先由 Go core 统一转成 stdio 事件。
- renderer 只接当前切口需要的最小事件，不把旧 WS 管理器完整复刻。

## P2

### P2-1: 多账号架构

**目标:** 迁移旧桌面端的多账号能力。

**当前进度:**
- [x] 已完成多账号登录态并存：renderer session store 与 Go core session 均已支持多账号列表与当前激活账号。
- [x] 已完成账号切换最小闭环：renderer 通过 `auth.account.switch` 切换 Go core 当前账号，并按目标账号 token 重连单一活动 websocket。
- [x] 已完成账号页签与基础恢复逻辑：主壳侧边栏已增加最小账号切换器，renderer 会持久化账号列表、当前账号与每账号 `activeView`，启动后通过 `auth.accounts.restore` 恢复 Go core 当前账号。
- [x] 已完成每账号独立基础会话状态：当前已区分每账号 token / currentUser / `activeView` / ws 重连链路。
- [x] 已完成每账号最小 `routeState` / 聊天上下文恢复：当前会持久化每账号 `routeState` 与 `pageState.currentChatGroupId`，切账号或重启后可回到各自上次选中的聊天会话。
- [x] 已完成联系人 / 设置页更深页面子状态恢复：联系人页现会按账号持久化模式、关键词、选中项与搜人上下文；设置页现会按账号持久化昵称编辑草稿与反馈草稿，同时显式排除密码草稿等敏感输入。

**范围:**
- [x] 多账号登录态并存
- [x] 账号切换
- [x] 每账号独立基础 ws / routeState / 会话状态
- [x] 账号页签与基础恢复逻辑
- [x] 聊天上下文恢复
- [x] 联系人 / 设置等更深页面子状态恢复

**说明:** 这是高复杂度任务，依赖聊天、联系人、设置的单账号主流程先稳定。

**关键参考:**
- [accounts.ts](/Users/chen/code/redcode-im/desktop/src/store/modules/accounts.ts)

### P2-2: 桌面体验增强

**范围:**
- [ ] 语音录制增强（已完成波形预览，录后编辑等仍待迁移）
- [x] 快捷键
- [x] 拖拽上传
- [x] 上下文菜单
- [x] 媒体预缓存（第一刀：图片 / 视频缩略图浏览器级预加载）
- [x] 更多细节交互第一刀（图片预览缩放）
- [x] 更多细节交互第二刀（图片预览旋转）
- [x] 更多细节交互第三刀（图片连续浏览，当前已加载消息范围）
- [ ] 更多细节交互（连续浏览、视频预览增强、更细缓存治理等仍待迁移）

### P2-3: `desktop-el` 专属测试体系

**目标:** 让 `desktop-el` 自身具备可持续回归的测试矩阵。

**当前进度:**
- [x] 已统一 Electron `main/preload` 测试使用的 `electron` superset mock，`desktop-el` 根目录 `bun test` 已恢复全绿。
- [x] 已补齐 Electron main 的 `dialog` / `notification` service 自动化测试，并扩展 `electron` superset mock 覆盖 `dialog` 与 `Notification` 行为。
- [x] 已固化 `desktop-el` 模块验收入口：根 `Makefile` 新增 `desktop-el-test` / `desktop-el-core-test` / `desktop-el-build` / `desktop-el-verify`，模块内新增 `bun run verify` 固定串联 Go core 测试、Bun 测试与构建。
- [x] 已补齐 Go core `user` / `friend` / `settings` service 测试，并修复 `user.UpdateMe` 在 `success=true` 且 `data=null` 时污染当前用户快照的边界问题。
- [x] 已补齐 Go core `chat` service 的群设置与附件上传/下载契约测试，覆盖路径、query、multipart session 与可选字段裁剪行为。
- [x] 已补齐 renderer 级 smoke 最小闭环：新增 Playwright + `vite preview` 独立 smoke 入口，在页面加载前注入 `window.desktopEl` mock，覆盖“登录页启动 -> 登录成功 -> 进入 HomeShell”浏览器级主链路，不并入默认 `desktop-el-verify`。
- [x] 已补齐 Go core websocket 掉线状态透传的 app-level 集成测试，并修复 `startWSPump()` 在远端主动断连时未向 renderer 发出 `ws.status.updated(disconnected)` 的缺口。
- [x] 已补齐账号恢复 / 切换 / 登出三条主链路的 websocket 断开态 app-level 集成测试，锁定 `auth.accounts.restore` / `auth.account.switch` / `auth.logout` 都会向 renderer 发出 `ws.status.updated(disconnected)`。

**范围:**
- [ ] Go core 集成测试继续扩充
- [x] Electron main / preload 测试扩充（已覆盖 `go-core` / `rpc` / `shell` / `file` / `dialog` / `notification` 与 preload API bridge）
- [x] renderer 级 smoke / e2e 方案（当前先落 Playwright smoke，后续如需更深交互再在此基础上扩展）
- [x] 关键迁移闭环形成固定验收脚本

### P2-4: 文档收口

**当前进度:**
- [x] 已补齐 `P0-4` 联系人主流程与 `P0-5` 设置页主流程的独立计划文档。
- [x] 已回填旧聊天计划文档中未勾选但已完成的步骤，计划状态与提交历史重新对齐。
- [x] 已形成 `desktop-el` 迁移进度总表，当前可直接按 backlog 项查看完成度、代表计划与代表提交。

**范围:**
- [x] 给每个 P0 / P1 切口补独立计划文档
- [x] 回填旧聊天计划文档中未勾选但已完成的提交步骤
- [x] 形成 `desktop-el` 迁移进度总表

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
