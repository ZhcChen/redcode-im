# RedCode IM 2.0 页面地图

## 1. 设计源入口层

这些页面属于 `im-ui-html/` 设计源自身，不等于正式 App 的业务 route。

| Route | 作用 | 说明 |
| --- | --- | --- |
| `#/entry` | 总入口 | 分流到规范页、PC 蓝图页与移动端设备预览 |
| `#/spec` | 规范源 | 展示 token、icon、组件、流转 |
| `#/pc-design` | 桌面蓝图 | 展示桌面三栏工作台结构 |
| `#/mobile-design` | 移动端设备预览 | 只显示一个可交互的手机容器，默认进入聊天首页；不显示设计说明或评审侧栏 |

## 2. 独立移动端预览

`#/mobile-design` 是设计源内的完整手机设备画布，不是业务页之外的说明页。

| Route | 说明 |
| --- | --- |
| `#/mobile-design` | 默认显示聊天首页 |
| `#/mobile-design/chats` | 会话列表 |
| `#/mobile-design/chat/:chatId` | 聊天详情 |
| `#/mobile-design/contacts` | 联系人 |
| `#/mobile-design/discover` | 发现 |
| `#/mobile-design/settings` | 设置 |
| `#/mobile-design/<业务路径>` | 将任意已注册的移动业务路径保留在同一手机容器内 |

容器内的一级导航、二级跳转、输入、Toast 和返回操作都不能跳出 `#/mobile-design/...`。

## 3. 移动端业务地图

### 一级导航

| 一级入口 | Route | 说明 |
| --- | --- | --- |
| 聊天 | `#/chats` | 会话列表主入口 |
| 联系人 | `#/contacts` | 联系人与关系链路 |
| 发现 | `#/discover` | 朋友圈、扫一扫、附近的人、游戏入口 |
| 设置 | `#/settings` | 主题、密度、通知、隐私与账号偏好 |

### 聊天链路

| Route | 说明 |
| --- | --- |
| `#/chat/:chatId` | 聊天详情 |
| `#/search` | 消息搜索 |

### 联系人链路

| Route | 说明 |
| --- | --- |
| `#/contacts/requests` | 好友申请 |
| `#/contacts/add` | 添加好友 |
| `#/contacts/profile/:contactId` | 联系人资料页 |

### 群组链路

| Route | 说明 |
| --- | --- |
| `#/groups` | 群组概览 |
| `#/groups/create` | 创建群聊 |
| `#/groups/settings/:groupId` | 群设置 |

### 发现链路

| Route | 说明 |
| --- | --- |
| `#/discover/moments` | 朋友圈 |
| `#/discover/scan` | 扫一扫 |
| `#/discover/nearby` | 附近的人 |
| `#/discover/games` | 游戏入口 |

### 其他

| Route | 说明 |
| --- | --- |
| `#/auth/login` | 登录页 |
| `#/lab` | 扩展总览 |
| `#/lab/:moduleId` | 扩展模块详情 |

## 4. 桌面蓝图地图

`#/pc-design` 当前不是完整桌面产品页，而是桌面形态说明画布。

当前表达的 4 个区块：

1. 全局导航
2. 会话与筛选
3. 主聊天区
4. 资料侧栏

目的：

- 说明桌面端不直接放大手机页
- 先固定桌面信息分区
- 为后续 Flutter desktop shell 提供布局基线

## 5. 推荐评审顺序

### 面向设计评审

1. `#/entry`
2. `#/spec`
3. `#/mobile-design`
4. `#/mobile-design/chat/c_room_launch`
5. `#/mobile-design/contacts`
6. `#/mobile-design/groups/create`
7. `#/mobile-design/discover`
8. `#/mobile-design/settings`
9. `#/pc-design`

### 面向 Flutter 实施

1. 读 `design-tokens.md`
2. 读 `component-inventory.md`
3. 读本文件，确认 route 范围
4. 读 `flutter-handoff.md`
5. 再进入 `app/` 做主线重构

## 6. 正式 Flutter Route 映射建议

| HTML 设计源 Route | Flutter 运行时建议 |
| --- | --- |
| `#/entry` | 不进入正式 runtime；保留在 HTML 设计源 |
| `#/spec` | 不进入正式 runtime；必要时做 debug-only preview |
| `#/pc-design` | 映射为 desktop shell 蓝图，不直接作为正式产品路由 |
| `#/mobile-design` | 仅作为 HTML 设计源内的设备预览壳，不直接作为正式产品路由 |
| `#/auth/login` | `auth/login` |
| `#/chats` | `home/chats` |
| `#/chat/:chatId` | `chat/detail/:chatId` |
| `#/contacts` | `home/contacts` |
| `#/contacts/requests` | `contacts/requests` |
| `#/contacts/add` | `contacts/add` |
| `#/contacts/profile/:contactId` | `contacts/profile/:contactId` |
| `#/discover` | `home/discover` |
| `#/discover/*` | `discover/*` |
| `#/groups/create` | `groups/create` |
| `#/groups/settings/:groupId` | `groups/settings/:groupId` |
| `#/search` | `search/messages` |
| `#/settings` | `home/settings` |

## 7. 页面地图维护规则

- 新增一级入口时，必须同步更新：
  - `#/entry`
  - `#/mobile-design` 及对应 `#/mobile-design/<业务路径>`
  - 本文件
  - `flutter-handoff.md`
- 新增二级链路时，必须同步更新：
  - 本文件的分组表
  - `component-inventory.md` 中受影响组件
  - `README` 推荐评审路径
