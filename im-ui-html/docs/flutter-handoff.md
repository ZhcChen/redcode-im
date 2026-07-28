# RedCode IM 2.0 Flutter 交接说明

## 目标

本文件回答两个问题：

1. `im-ui-html/` 当前哪些内容要进入 Flutter 正式实现？
2. 这些内容在 `app/` 里应该怎样落位？

## 1. 设计源与正式产品的边界

### 只属于设计源，不直接进入正式 runtime

- `#/entry`
- `#/spec`
- `#/pc-design`
- `#/mobile-design`

这些页面的作用是：

- 组织评审顺序
- 固定 token / 组件 / 页面地图
- 说明桌面与移动端的设计边界
- 让 `#/mobile-design` 以单一手机容器串联完整移动 IM 交互

它们不是正式 IM 用户会看到的业务页面。

### 会进入正式 runtime 的业务链路

- 登录
- 聊天 / 聊天详情
- 联系人 / 好友申请 / 添加好友 / 资料页
- 发现 / 朋友圈 / 扫一扫 / 附近的人 / 游戏入口
- 建群 / 群设置
- 消息搜索
- 我的 / 设置

## 2. Flutter 目录落位建议

基于当前 2.0 总计划，建议先在 `app/` 内按下面的边界落位：

```text
app/lib/
  bootstrap/
  shell/
    mobile/
    desktop/
  features/
    auth/
    chats/
    contacts/
    discover/
    groups/
    search/
    mine/
    settings/
  core/
    theme/
    routing/
```

## 3. Shell 映射

### Mobile Shell

来源页面：

- `#/mobile-design`
- `#/chats`
- `#/contacts`
- `#/discover`
- `#/mine`
- `#/settings`

必须先固定：

- 稳定底部导航（图标 + 一级标题，不覆盖内容）
- 根页 App Bar 节奏
- 二级页返回结构
- 密度缩放一致性

### Desktop Shell

来源页面：

- `#/pc-design`

必须先固定：

- 导航列
- 会话列
- 主聊天区
- 资料侧栏

注意：

- 桌面端不是把手机页直接拉宽。
- 先建立布局壳层，再把移动端业务组件放进去重组。

## 4. UI Kit 映射

优先进入未来 `im_ui_kit` 的内容：

| HTML 组件 | Flutter 组件方向 |
| --- | --- |
| `App Shell` | `AppScaffold` / `RootShell` |
| `Conversation Cell` | `ConversationListTile` |
| `Message Bubble` | `MessageBubble` |
| `Composer` | `ChatComposer` |
| `Mine Profile` | `ProfileHeader + profile route` |
| `Settings Row` | `SettingsListRow` |
| `Action Card` | `ActionSurfaceCard` |
| `Chip / Badge` | `TagChip` / `StatusBadge` |

暂不建议直接产品化的设计源专用内容：

- 设计源总入口卡片
- Token 展示网格
- Desktop Blueprint 说明块

## 5. Route 映射建议

| HTML Route | Flutter 建议 |
| --- | --- |
| `#/auth/login` | `auth/login` |
| `#/chats` | `home/chats` |
| `#/chat/:chatId` | `chat/detail/:chatId` |
| `#/contacts` | `home/contacts` |
| `#/contacts/requests` | `contacts/requests` |
| `#/contacts/add` | `contacts/add` |
| `#/contacts/profile/:contactId` | `contacts/profile/:contactId` |
| `#/discover` | `home/discover` |
| `#/discover/moments` | `discover/moments` |
| `#/discover/scan` | `discover/scan` |
| `#/discover/nearby` | `discover/nearby` |
| `#/discover/games` | `discover/games` |
| `#/groups/create` | `groups/create` |
| `#/groups/settings/:groupId` | `groups/settings/:groupId` |
| `#/search` | `search/messages` |
| `#/mine` | `home/mine` |
| `#/mine/profile` | `mine/profile` |
| `#/settings` | `mine/settings` |
| `#/settings/:section` | `mine/settings/:section` |

## 6. 实施顺序建议

### Phase 1：先稳定主题和壳层

- 把颜色、字体、间距、圆角、密度 token 收进 Flutter theme
- 建立 mobile shell / desktop shell 边界
- 不急着全量搬业务页

### Phase 2：先做移动端主流程

顺序建议：

1. 聊天
2. 联系人
3. 发现
4. 我的 / 设置
5. 群聊 / 搜索

原因：

- 聊天输入区、会话列表、消息气泡会最先暴露设计系统是否稳定
- 联系人、发现、我的与设置能验证资料、服务入口和列表类组件是否足够统一

### Phase 3：再做桌面壳层重组

- 先让桌面壳层能承载同一套 cell / bubble / composer
- 再补资料侧栏、文件区和桌面特有上下文

## 7. 重点注意项

### 密度

- `2K / 1.5K / 1K` 必须由统一适配层处理
- 不要在单个页面局部修补字号

### 组件复用

- 会话行、联系人行、搜索结果行优先共用一套信息层级
- 单聊 / 群聊消息气泡优先共用一套骨架

### 设计源一致性

- Flutter 落地前，如果 HTML 设计源又改了 token、路由或组件状态，必须先回写这 4 份文档
- 正式实现不能绕开 `im-ui-html/docs/` 自行发明状态约定

## 8. 进入 Flutter 开发前的最小检查

- 已读 `design-tokens.md`
- 已读 `component-inventory.md`
- 已读 `page-map.md`
- 已确认当前 `#/entry`、`#/spec`、`#/pc-design`、`#/mobile-design` 页面结构
- 已确认本轮不会把设计源页面误当成正式业务页面直接搬进 runtime
