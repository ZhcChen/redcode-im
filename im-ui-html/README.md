# im-ui-html

纯 `HTML + CSS + JS` 的 RedCode IM 2.0 设计源模块。

## 目标

- 先收敛统一的视觉规范、组件契约与页面地图，再进入 Flutter 正式实现。
- 不依赖真实 API，只用 mock 数据演示流程。
- 提供可点击、可跳转、可操作的高保真设计源，作为后续正式重构基线。

## 设计方向

- **视觉主张**：Precision Pocket IM，基于真实手机画布、轻表面层级和单一主强调色。
- **信息架构**：移动端一级导航固定为聊天 / 联系人 / 发现 / 设置；详情、申请、群设置、搜索全部走二级页。
- **密度策略**：支持 2K / 1.5K / 1K 三档预览，对齐 Flutter 端的手机密度分档逻辑。
- **交互动效**：
  - 导航切换：轻位移 + 淡入
  - 消息进入：自下而上出现
  - 输入面板展开：短距离上浮

## 技术选型

- 单页 hash router
- 本地静态资源
- 统一 mock store
- 无 npm / bundler / framework 依赖

## 设计源入口

- `#/entry`：设计源总入口
- `#/spec`：设计系统页
- `#/pc-design`：PC 端蓝图页
- `#/mobile-design`：独立移动端设备预览，默认进入聊天首页；宽屏默认使用 `iPhone 12 Pro` 外壳，可切换到 `Pixel 8 Pro`

## 业务原型路由

- `#/auth/login`：登录页
- `#/chats`：会话列表
- `#/chat/:chatId`：聊天详情
- `#/contacts`：联系人
- `#/discover`：发现首页
- `#/discover/moments`：朋友圈
- `#/discover/scan`：扫一扫
- `#/discover/nearby`：附近的人
- `#/discover/games`：游戏入口
- `#/contacts/requests`：好友申请
- `#/contacts/add`：添加好友
- `#/contacts/profile/:contactId`：联系人详情
- `#/groups`：群组概览
- `#/groups/create`：创建群聊
- `#/groups/settings/:groupId`：群设置
- `#/search`：消息搜索
- `#/lab`：扩展总览
- `#/lab/:moduleId`：扩展详情
- `#/settings`：设置
- `#/settings/profile`：个人资料
- `#/settings/account`：账号与安全
- `#/settings/chat`：聊天偏好与存储
- `#/settings/privacy`：隐私协议与数据使用
- `#/settings/about`：关于与版本信息

## 附属文档

- `docs/design-tokens.md`
- `docs/component-inventory.md`
- `docs/page-map.md`
- `docs/flutter-handoff.md`

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

## 预览模式

- **独立手机预览**：`#/mobile-design` 始终只显示一个可操作的手机容器，默认载入聊天首页；宽屏以 `iPhone 12 Pro` 为默认外壳，并提供 `Pixel 8 Pro` 切换。聊天、联系人、发现、设置及其二级页面都在独立屏幕裁切层内跳转，不能露出到设备底部。
- **预览内深链**：使用 `#/mobile-design/chat/c_room_launch`、`#/mobile-design/contacts` 等地址可直接打开对应页面；二级页返回优先回到实际来源，深链兜底也会留在设备容器内。
- **桌面评审**：桌面宽度下访问普通业务路由时，默认保留工具条、主题/密度控制和手机机框；也可显式使用 `?mode=review`。
- **手机运行态**：`640px` 以下的普通业务路由会直接显示应用界面，不再嵌套评审工具条或手机机框。
- **强制手机运行态**：在桌面浏览器中使用 `index.html?mode=app#/chats`，会显示居中的移动应用画布，便于单页检查。

常用入口：

```text
#/mobile-design
#/mobile-design/chat/c_room_launch
#/mobile-design/contacts
#/auth/login
#/discover
#/settings
```

## 推荐评审路径

1. 先看 `#/entry`，确认 3 个总入口是否清楚。
2. 再看 `#/spec`，确认 tokens、icon、组件预览、页面地图和密度策略。
3. 再看 `#/mobile-design`，确认单一手机容器内的聊天首页、底栏和二级页面跳转。
4. 再看 `#/mobile-design/chat/c_room_launch`、`#/mobile-design/contacts`、`#/mobile-design/discover`、`#/mobile-design/settings` 及 `#/mobile-design/settings/profile`，确认完整 IM 流程始终留在设备容器内。
5. 再看 `#/mobile-design/contacts/requests`、`#/mobile-design/contacts/add`、`#/mobile-design/contacts/profile/u_alice`，确认联系人二级页仍留在设备容器内。
6. 再看 `#/mobile-design/discover/moments`、`#/mobile-design/discover/scan`，确认发现链路仍是同一容器内的一级流程。
7. 再看 `#/mobile-design/groups/create`、`#/mobile-design/groups/settings/g_launch`，确认建群与群设置不跳出预览壳。
8. 最后看 `#/pc-design`，确认桌面工作台不是手机页拉伸。

## 当前范围

- 已覆盖设计源入口、规范页、移动端主流程和桌面蓝图页。
- 已覆盖 IM 核心流程：设计系统、聊天、联系人、发现、好友申请、建群、群设置、搜索、设置。
- 已预留扩展位：通话、AI、文件协作、自动化。
- 当前全部数据为 mock，不接真实后端。
- 主题、密度、设备外壳选择与设置开关会写入 `localStorage`，当前设计源 key 为 `redcode-im-ui-prototype/design-source-v2`。
