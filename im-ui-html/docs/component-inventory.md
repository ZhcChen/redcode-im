# RedCode IM 2.0 组件清单

## 目的

本文件记录当前 `im-ui-html/` 已经收敛出来的组件原语、状态和 Flutter 映射，避免后续实现阶段只看页面截图自行拆组件。

## 共享组件

| 组件 | 用途 | 状态 | Flutter 映射 |
| --- | --- | --- | --- |
| `App Shell` | 状态栏、App Bar、根滚动区、页面容器 | `Root / Subpage / Overlay` | `Scaffold + SafeArea + custom shell` |
| `Conversation Cell` | 会话、联系人、搜索结果等列表基础行 | `Default / Pinned / Unread / Muted` | `Reusable list tile + leading avatar + trailing meta` |
| `Message Bubble` | 单聊/群聊消息体 | `Incoming / Outgoing / Quote / Recent / Highlighted` | `Message bubble + reaction row` |
| `Composer` | 输入框、表情、更多面板、发送动作 | `Idle / Typing / Emoji Panel / Attachment Panel` | `Bottom composer + panel controller` |
| `Action Card` | 设计入口、发现入口、快速评审卡片 | `Default / Hover / Active / Disabled` | `Pressable surface card` |
| `Settings Row` | 设置、群规则、资料字段等通用行 | `Plain / Clickable / Switch / Danger` | `Row + optional trailing control` |

## 页面复合组件

这些组件不是最底层原语，但已经形成明确复合结构，建议在 Flutter 里保留对应 Widget：

### 1. 入口卡片 `Entry Card`

使用位置：

- `#/entry`

结构：

- eyebrow
- icon 区
- title
- summary
- bullets
- primary CTA

备注：

- 这是设计源入口专用组件，不属于正式业务页面。
- 视觉语言可复用到后续引导卡片，但不应直接照搬为 IM 业务主卡片。

### 2. 移动入口卡片 `Mobile Hub Card`

使用位置：

- `#/mobile-design`

结构：

- index
- title
- note

备注：

- 这是移动端链路总览组件，用于设计评审。
- 正式 App 可以不保留该页面，但其层级关系必须映射到实际导航结构。

### 3. 发现入口卡片 `Discover Entry Card`

使用位置：

- `#/discover`

结构：

- icon
- title
- badge
- summary

备注：

- 发现页和总入口页都在使用“轻表面卡片 + 明确 CTA”的模式。
- Flutter 实现可以抽成同源容器，但保留不同的内容槽位。

### 4. 规范展示卡片 `Spec Surface`

使用位置：

- `#/spec`
- `#/pc-design`
- `#/entry`

结构：

- section title
- header badge
- token/list/grid/flow content

备注：

- 这是设计源内部说明容器，不直接映射到正式业务页面。
- 可以作为 Flutter 的开发预览或调试页容器参考，但不是产品组件。

## 高优先级组件实现顺序

建议 Flutter 落地顺序：

1. `App Shell`
2. `Conversation Cell`
3. `Message Bubble`
4. `Composer`
5. `Settings Row`
6. `Action Card`

原因：

- 前 5 项直接决定聊天、联系人、设置、群聊等主流程一致性。
- `Action Card` 更多服务于设计入口、发现入口和次级导航，可在主流程稳定后补强。

## 复杂组件拆分建议

### Composer

建议拆成：

- 输入容器
- 文本输入区
- 左右动作位
- 表情面板
- 更多面板
- 发送按钮状态

不要把表情、更多、发送逻辑全部糊在一个 Widget 里。

### Conversation Cell

建议拆成：

- Avatar
- Title / Summary
- Tags / Status
- Trailing Meta / Badge

会话、联系人、搜索结果都应优先共用这一结构，而不是分别手写新行组件。

### Message Bubble

建议拆成：

- Sender / Meta
- Bubble Body
- Quote Block
- Reactions
- Delivery Status

群聊和单聊的差异应通过配置扩展，而不是复制两套消息组件。

## 页面专用，不建议过早抽成通用组件的部分

- `#/entry` 顶层总览布局
- `#/pc-design` 的桌面蓝图演示画布
- `#/spec` 内的 token / flow 展示网格

这些内容属于设计源说明层，不是正式 IM 业务原语。

## 交接原则

- 正式 Flutter 工程只抽“会进入产品运行时”的组件
- 设计源专用组件保留在 HTML 设计模块，不强行要求 1:1 进产品代码
- 如果某个设计源组件未来要进入产品运行时，先回到本清单补状态，再进入实现
