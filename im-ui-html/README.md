# im-ui-html

纯 `HTML + CSS + JS` 的 RedCode IM 2.0 设计源模块。

> 冻结基线：`2026-08-01`。业务页面以 `tests/routes.ts` 的 43 条路由为机器可读清单，后续正式实现以本目录文档和通过回归的运行态为准。

## 目标

- 先收敛统一的视觉规范、组件契约与页面地图，再进入 Flutter 正式实现。
- 不依赖真实 API，只用 mock 数据演示流程。
- 提供可点击、可跳转、可操作的高保真设计源，作为后续正式重构基线。

## 设计方向

- **视觉主张**：Precision Pocket IM，基于真实手机画布、轻表面层级和单一主强调色。
- **信息架构**：移动端一级导航固定为聊天 / 联系人 / 发现 / 我的；资料、设置、申请、群设置、搜索全部走二级页。
- **密度策略**：支持 2K / 1.5K / 1K 三档预览，对齐 Flutter 端的手机密度分档逻辑。
- **交互动效**：
  - 导航切换：轻位移 + 淡入
  - 消息进入：自下而上出现
  - 输入面板展开：输入区上移，表情或更多面板承接在其下方，以短时展开/收缩过渡进入底部安全区
  - 纯表情消息：无气泡大表情在发送时播放一次；设计源当前使用 registry fallback glyph，正式客户端应改由自有静态与动画资源解析

## 技术选型

- 单页 hash router
- 本地静态资源
- 统一 mock store
- 生产预览无 bundler / framework 依赖；Playwright 回归使用 Bun 管理开发依赖

## 设计源入口

- `#/entry`：设计源总入口
- `#/spec`：设计系统页
- `#/pc-design`：PC 端蓝图页
- `#/mobile-design`：独立移动端设备预览，默认进入聊天首页；宽屏默认使用 `iPhone 12 Pro` 外壳，可切换到 `iPhone 16 Pro Max` 或 `Pixel 8 Pro`，并支持演示数据与空数据场景
- `#/mobile-design/empty`：空数据手机壳，默认进入空会话首页；二级跳转保持 `#/mobile-design/empty/<业务路径>`

## 业务原型路由

- `#/auth/login`：登录页
- `#/chats`：会话列表
- `#/chat/:chatId`：聊天详情
- `#/chat/:chatId/message/:messageId/reads`：消息已读与未读成员
- `#/chat/:chatId/forward/:messageId`：消息转发与部分失败结果
- `#/contacts`：联系人
- `#/discover`：发现首页
- `#/discover/moments`：朋友圈
- `#/discover/scan`：扫一扫
- `#/discover/nearby`：附近的人
- `#/discover/games`：游戏入口
- `#/contacts/requests`：好友申请
- `#/contacts/add`：添加好友
- `#/contacts/profile/:contactId`：联系人详情
- `#/contacts/profile/:contactId/report`：联系人举报
- `#/groups`：群会话目录（所有仍在其中的群）；收藏群优先显示，清空或归档会话不影响该目录
- `#/groups/create`：创建群聊
- `#/groups/settings/:groupId`：群设置
- `#/groups/:groupId/members`、`admins`、`join-requests`、`invite`：群成员与角色治理
- `#/groups/:groupId/rules`、`mutes`、`operation-logs`：群规则、禁言和日志
- `#/stickers`、`#/stickers/store`、`#/stickers/packs/:packId`：贴纸管理
- `#/search`：消息搜索
- `#/mine`：我的
- `#/mine/profile`：个人资料
- `#/settings`：设置（从“我的”进入）
- `#/settings/account`：账号与安全
- `#/settings/chat`：聊天偏好与存储
- `#/settings/privacy`：隐私协议与数据使用
- `#/settings/about`：关于与版本信息
- `#/settings/profile/edit`：头像与昵称编辑
- `#/settings/feedback`：体验反馈
- `#/settings/password`：修改密码
- `#/settings/deactivate`：注销账号
- `#/settings/version`：版本与热更新状态

## 设计源内部工具

- `#/lab`：实验模块总览，仅用于概念与状态评审
- `#/lab/:moduleId`：实验模块详情，不进入正式 App 导航或 Flutter route

## 附属文档

- `docs/design-tokens.md`
- `docs/component-inventory.md`
- `docs/page-map.md`
- `docs/moments-media-layout.md`
- `docs/flutter-handoff.md`
- `docs/platform-handoff.md`

## 启动方式

### 方式 1：直接打开

直接打开 `im-ui-html/index.html` 即可。

### 方式 2：本地静态服务

```bash
cd im-ui-html
python3 -m http.server 8020
```

然后访问：

```text
http://127.0.0.1:8020/#/entry
```

## 自动化回归

```bash
make im-ui.install
make im-ui.test
make im-ui.test.visual
```

- Bun 固定为 `1.3.11`，浏览器使用 Chrome for Testing。
- 三个项目通过预览工具栏切换 `iPhone 12 Pro`、`iPhone 16 Pro Max` 与 `Pixel 8 Pro` 外壳。
- `make im-ui.test` 覆盖 43 条正式路由、Console、横向溢出和关键交互；截图命令按 8 条高风险路由生成 24 张人工评审图，不做像素断言。
- Chrome 设备模拟不替代系统软键盘、真实安全区、触觉反馈、相机和麦克风验收。

## 预览模式

- **独立手机预览**：`#/mobile-design` 始终只显示一个可操作的手机容器，默认载入聊天首页；宽屏以 `iPhone 12 Pro` 为默认外壳，并提供 `iPhone 16 Pro Max`、`Pixel 8 Pro`、演示数据与空数据切换。空数据模式从 `#/mobile-design/empty` 进入，会清空会话、联系人、群聊、关系申请、搜索用户和发现内容，同时保留账号、设置和静态服务入口；所有二级跳转保持 `#/mobile-design/empty/...`。iPhone 16 Pro Max 预览包含 Dynamic Island、底部白色 Home Indicator 与对应安全区，聊天、联系人、发现、我的及设置二级页都在独立屏幕裁切层内跳转，不能露出到设备底部。
- **预览内深链**：使用 `#/mobile-design/chat/c_room_launch`、`#/mobile-design/contacts` 等地址可直接打开对应页面；二级页返回优先回到实际来源，深链兜底也会留在设备容器内。
- **桌面评审**：桌面宽度下访问普通业务路由时，默认保留工具条、主题/密度控制和手机机框；也可显式使用 `?mode=review`。
- **手机运行态**：`640px` 以下的普通业务路由会直接显示应用界面，不再嵌套评审工具条或手机机框。
- **强制手机运行态**：在桌面浏览器中使用 `index.html?mode=app#/chats`，会显示居中的移动应用画布，便于单页检查。

常用入口：

```text
#/mobile-design
#/mobile-design/empty
#/mobile-design/chat/c_room_launch
#/mobile-design/contacts
#/mobile-design/mine
#/auth/login
#/discover
#/settings
#/stickers/store
#/settings/feedback
#/settings/version
```

## 推荐评审路径

1. 先看 `#/entry`，确认 3 个总入口是否清楚。
2. 再看 `#/spec`，确认 tokens、icon、组件预览、页面地图和密度策略。
3. 再看 `#/mobile-design`，确认单一手机容器内的聊天首页、底栏和二级页面跳转。
4. 再看 `#/mobile-design/chat/c_room_launch`、`#/mobile-design/contacts`、`#/mobile-design/groups`、`#/mobile-design/discover`、`#/mobile-design/mine`、`#/mobile-design/mine/profile` 及 `#/mobile-design/settings`，确认完整 IM 流程始终留在设备容器内。
5. 再看 `#/mobile-design/contacts/requests`、`#/mobile-design/contacts/add`、`#/mobile-design/contacts/profile/u_alice`，确认联系人二级页仍留在设备容器内。
6. 再看 `#/mobile-design/discover/moments`、`#/mobile-design/discover/scan`、`#/mobile-design/discover/nearby`、`#/mobile-design/discover/games`，确认发现链路的内容、工具、人员列表和游戏入口使用同一运行时语言。
7. 再看 `#/mobile-design/groups/create`、`#/mobile-design/groups/settings/g_launch`，确认建群与群设置不跳出预览壳。
8. 再看 `#/mobile-design/stickers/store`、`#/mobile-design/settings/feedback`、`#/mobile-design/settings/profile/edit`、`#/mobile-design/settings/password`、`#/mobile-design/settings/deactivate` 与 `#/mobile-design/settings/version`，确认内容、账号和版本能力具备完整状态。
9. 最后看 `#/pc-design`，确认桌面工作台不是手机页拉伸。

## 当前范围

- 已覆盖设计源入口、规范页、移动端主流程和桌面蓝图页。
- 已覆盖 IM 核心流程及 API 已有的消息管理、会话归档撤销、联系人危险操作、群治理、举报反馈、贴纸、资料账号和版本状态。
- 已预留扩展位：通话、AI、文件协作、自动化。
- `#/lab` 仅保留为设计源内部实验工具，不属于正式移动端业务地图。
- 当前全部数据为 mock，不接真实后端。
- 联系人目录、会话列表和消息线程使用确定性的密集 mock 数据，默认覆盖长列表、长摘要、未读、静音、引用、反应与连续滚动审查；会话头像统一为 `48px`，群头像使用对应尺寸的 2 × 2 复合网格。
- 主题、密度、设备外壳选择、设置开关与群聊收藏会写入 `localStorage`，当前设计源 key 为 `redcode-im-ui-prototype/design-source-v2`。
- 举报、反馈、密码与注销确认只保留在当前页面内存中，离开流程即清理，不写入 `localStorage`、URL 或 mock 数据。
- SMS 登录、短信重置密码、更换手机号、归档中心、邀请列表、独立群公告和整套贴纸批量移除不在本设计源能力对齐范围内。

## 冻结后变更准入

新增或修改业务路由、token、组件状态时，必须在同一提交同步更新 `docs/page-map.md`、`docs/component-inventory.md`、对应 handoff 文档、`tests/routes.ts` 及适用测试；高风险代表页面同时更新 `tests/visual-routes.ts`。未完成上述同步的改动不得视为设计基线已交付。
