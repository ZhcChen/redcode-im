# RedCode IM 2.0 页面地图

## 1. 设计源入口层

这些页面属于 `im-ui-html/` 设计源自身，不等于正式 App 的业务 route。

| Route | 作用 | 说明 |
| --- | --- | --- |
| `#/entry` | 总入口 | 分流到规范页、PC 蓝图页、移动端入口页 |
| `#/spec` | 规范源 | 展示 token、icon、组件、流转 |
| `#/pc-design` | 桌面蓝图 | 展示桌面三栏工作台结构 |
| `#/mobile-design` | 移动总览 | 展示手机一级入口与关键二级链路 |

## 2. 移动端业务地图

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

## 3. 桌面蓝图地图

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

## 4. 推荐评审顺序

### 面向设计评审

1. `#/entry`
2. `#/spec`
3. `#/mobile-design`
4. `#/chats`
5. `#/chat/c_room_launch`
6. `#/contacts`
7. `#/groups/create`
8. `#/discover`
9. `#/pc-design`

### 面向 Flutter 实施

1. 读 `design-tokens.md`
2. 读 `component-inventory.md`
3. 读本文件，确认 route 范围
4. 读 `flutter-handoff.md`
5. 再进入 `app/` 做主线重构

## 5. 正式 Flutter Route 映射建议

| HTML 设计源 Route | Flutter 运行时建议 |
| --- | --- |
| `#/entry` | 不进入正式 runtime；保留在 HTML 设计源 |
| `#/spec` | 不进入正式 runtime；必要时做 debug-only preview |
| `#/pc-design` | 映射为 desktop shell 蓝图，不直接作为正式产品路由 |
| `#/mobile-design` | 作为设计说明页，不直接进入正式 runtime |
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

## 6. 页面地图维护规则

- 新增一级入口时，必须同步更新：
  - `#/entry`
  - `#/mobile-design`
  - 本文件
  - `flutter-handoff.md`
- 新增二级链路时，必须同步更新：
  - 本文件的分组表
  - `component-inventory.md` 中受影响组件
  - `README` 推荐评审路径
