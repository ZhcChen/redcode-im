# Desktop EL Migration Progress Table

## 概览

| Backlog 项 | 当前状态 | 代表计划文档 | 代表提交 | 剩余缺口 |
| --- | --- | --- | --- | --- |
| `P0-1` 聊天消息深水区 | 主要闭环已完成 | `2026-03-25-desktop-el-message-forward-plan.md`、`2026-03-25-desktop-el-message-pin-plan.md`、`2026-03-25-desktop-el-message-edit-menu-plan.md` | `5baa02a7`、`e1304488`、`af9cef94` | 更细粒度消息管理增强项 |
| `P0-2` 媒体与附件消息闭环 | 主要闭环已完成 | `2026-03-24-desktop-el-chat-attachment-download-plan.md`、`2026-03-24-desktop-el-chat-attachment-upload-plan.md`、`2026-03-25-desktop-el-attachment-cache-plan.md`、`2026-03-25-desktop-el-voice-message-plan.md` | `7b847084`、`749cd8af`、`40e007ad`、`d4ace8d2` | 录后编辑、媒体预缓存与更多细节交互 |
| `P0-3` 群聊最小闭环 | 已完成 | `2026-03-25-desktop-el-group-create-plan.md`、`2026-03-25-desktop-el-group-detail-plan.md`、`2026-03-25-desktop-el-group-settings-plan.md` | `3a2b346b`、`dd2df023`、`f0e4aad9` | 更深群事件联动可继续细化 |
| `P0-4` 联系人主流程补齐 | 已完成 | `2026-03-26-desktop-el-contact-main-flow-plan.md` | `ea0cc417`、`c32d07ab`、`677cb9b6`、`4685e1cc` | 体验增强类优化 |
| `P0-5` 设置页主流程补齐 | 已完成 | `2026-03-26-desktop-el-settings-main-flow-plan.md` | `675587dd`、`5a12f210`、`cd8800d8` | 非主阻塞体验优化 |
| `P1-1` 群管理深水区 | 主要闭环已完成 | `2026-03-25-desktop-el-group-admin-plan.md`、`2026-03-25-desktop-el-group-join-requests-plan.md`、`2026-03-25-desktop-el-group-member-panel-plan.md` | `8594a5b3`、`76703113`、`5c8d1c4a` | 审批流联动、富文本群规等深水区增强 |
| `P1-2` 本地消息搜索 | 已完成 | `2026-03-25-desktop-el-local-message-search-plan.md` | `b9e784f5` | 仅当前会话本地搜索，未做全局搜索 |
| `P1-3` Electron 宿主能力与业务接通 | 已完成 | `2026-03-25-desktop-el-tray-window-plan.md`、`2026-03-25-desktop-el-message-notification-plan.md`、`2026-03-26-desktop-el-electron-main-test-plan.md` | `a7896aa1`、`4492188e`、`5e568d1c` | 继续扩大自动化覆盖 |
| `P1-4` 更完整的 websocket 事件面 | 已完成当前主范围 | `2026-03-25-desktop-el-typing-update-plan.md`、`2026-03-25-desktop-el-group-deep-events-plan.md`、`2026-03-25-desktop-el-group-owner-transferred-realtime-plan.md` | `49c715fd`、`21200ec0`、`76cd5afa` | 可继续补更细事件收敛 |
| `P2-1` 多账号状态保持 | 已完成 | `2026-03-25-desktop-el-multi-account-plan.md`、`2026-03-25-desktop-el-account-route-state-plan.md`、`2026-03-26-desktop-el-account-panel-state-plan.md` | `7d2e30ca`、`8e9fc284`、`b966094b` | 无 |
| `P2-2` 媒体与输入体验收尾 | 部分完成 | `2026-03-26-desktop-el-voice-waveform-plan.md`、`2026-03-26-desktop-el-voice-post-edit-plan.md`、`2026-03-26-desktop-el-media-precache-plan.md`、`2026-03-26-desktop-el-image-preview-zoom-plan.md`、`2026-03-26-desktop-el-image-preview-rotation-plan.md`、`2026-03-26-desktop-el-image-preview-gallery-plan.md`、`2026-03-26-desktop-el-media-preview-keyboard-plan.md` | `5533c672`、`615389de`、`c45f8e45`、`cc423e1e`、`db9d9ddb`、`2595b4ea` | 语音录制增强、视频预览增强 / 更细缓存治理 |
| `P2-3` 专属测试体系 | 部分完成 | `2026-03-26-desktop-el-electron-main-test-plan.md`、`2026-03-26-desktop-el-verification-entrypoint-plan.md`、`2026-03-26-desktop-el-app-ws-status-events-plan.md` | `5e568d1c`、`e4c90eee`、`02228a85` | 更深 Go core 集成测试继续扩充、renderer smoke / e2e |
| `P2-4` 文档收口 | 已完成 | `2026-03-26-desktop-el-docs-closeout-plan.md` | `docs(desktop-el): close out migration planning docs` | 无 |

## 当前剩余优先项

1. `P2-2` 语音录制增强、视频预览增强与更细缓存治理。
2. `P0-1` 更细粒度消息管理增强项。
3. `P2-3` 更深 Go core 集成测试继续扩充。
