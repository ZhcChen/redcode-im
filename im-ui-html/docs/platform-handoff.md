# RedCode IM 2.0 多端交付差异

> 冻结版本：`2026-08-01`；运行证据更新至 `2026-08-03`。本表依据当前仓库路由、功能文件和验收记录核对，只描述可见实现面，不把设计源 mock 或文件名视为端到端完成证明。

## 主线边界

- `app/`：Flutter 多平台 2.0 正式主线，移动端与后续桌面壳层均从冻结设计源映射。
- `h5-app/`：H5 正式映射对象，同时承担 Web parity 与 API 联调；不要求一次覆盖全部 Flutter 平台能力。
- `ios-app/`、`android-app/`：历史原生实现参考，不是 2.0 主线输入，不以其页面结构反向覆盖冻结设计。

## 能力矩阵

| 设计源能力 | Flutter `app/` 当前证据 | `h5-app/` 当前证据 | 后续优先级 |
| --- | --- | --- | --- |
| 登录与启动 | 2.0 普通账号登录、协议门禁、integration auth 和 Patrol 登录已通过；短信流程不在本轮 | 已有 `/login` | U8：补冷启动、系统键盘和离线恢复 |
| 一级 App Shell | 2.0 聊天/联系人/发现/我的四 Tab 与二级路由 Patrol 已通过 | `/home` 承载现有首页 | U9：H5 对齐四入口语义和状态 |
| 会话列表与聊天详情 | 已有列表、详情、气泡、语音、引用和 reaction；双 iOS 真实私聊 A/B 实时互发已通过 | 已有 `/chats/:roomId` | U8：补群聊、已读、附件、前后台和离线恢复 |
| 消息搜索 | 已有 `message_search_page.dart` | 已有 `/messages/search` | P0：统一结果信息层级与跳转定位 |
| 联系人与资料 | 已有联系人、添加好友和详情页；真实 API 好友合同与双端联系人进入私聊已通过 | 无独立路由 | U9：H5 补正式路由与状态闭环 |
| 群目录、建群与治理 | 已有建群、设置、管理员、申请、禁言、规则和日志页面 | 仅 `/groups/:roomId/settings` | P0：Flutter 核对状态；H5 分阶段补齐 |
| 朋友圈、扫一扫、附近、游戏 | 未发现对应 `features/discover/` 页面 | 无对应路由 | P1：按设计源拆独立实施计划 |
| 贴纸与表情 | 已有表情模型/缓存和贴纸设置页 | 无对应路由 | P1：统一 pack 状态与聊天面板 |
| 我的、资料与设置 | 2.0 我的、设置、账号安全和反馈等页面已落地并有 widget/API contract 证据 | 已有资料、安全、隐私、协议、关于、反馈路由 | U8/U9：先完成 Flutter 设备巡检，再审计 H5 差异 |
| 密码、注销、版本状态 | Flutter 存在密码重置入口，未发现完整设计源三条链路证据 | 无对应路由 | P1：按 API 契约逐项落地，不引入 SMS |
| 语音与视频通话 | 有语音服务、语音消息和视频预览文件；不能证明完整通话链路 | 无对应路由 | P1：另立音视频端到端计划与设备验收 |
| 桌面四栏壳层 | 已有 `desktop_app_shell_test.dart` 基础边界，尚无完整 Windows/macOS/Linux 正式体验证据 | 不适用 | U12：H5 P0 后实施桌面 P0 |

## 页面、状态与测试追踪

- 设计源正式业务页面：`im-ui-html/tests/routes.ts`，43 条。
- 高风险视觉样本：`im-ui-html/tests/visual-routes.ts`，8 条路由乘 3 个设备外壳，共 24 张人工评审图。
- 公共组件与状态：`component-inventory.md`。
- Flutter 目标 route 与组件映射：`flutter-handoff.md`。
- H5 当前真实路由：`h5-app/src/router/index.ts`；U9 将以运行时重新统计为准，不沿用历史固定条数。
- Flutter U8 验收事实：`docs/reviews/2026-08-02-im-2-0-u8-device-acceptance-review.md`。
- 当前剩余执行顺序：`docs/plans/2026-08-03-001-feat-im-2-0-remaining-work-plan.md`。

## 平台验收边界

Chrome 设备外壳只验证设计画布、内容裁切、预览安全区、输入聚焦和 viewport 变化。以下项目必须转到正式端设备验收：

- 系统软键盘遮挡、输入法切换和键盘动画。
- iOS/Android 真实安全区、系统导航栏和横竖屏切换。
- 触觉反馈、原生返回手势、系统分享和权限恢复。
- 相机、麦克风、音视频通话、后台通知和前后台切换。

## 变更准入

新增路由、token、组件或状态时，在同一业务闭环中同步更新 `page-map.md`、`component-inventory.md`、`flutter-handoff.md`、本文件、`tests/routes.ts` 和适用测试。高风险视觉链路同步维护 `tests/visual-routes.ts`；多端实现状态只能依据当前代码与验证记录更新。
