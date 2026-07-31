# RedCode IM 2.0 组件清单

## 目的

本文件记录当前 `im-ui-html/` 已经收敛出来的组件原语、状态和 Flutter 映射，避免后续实现阶段只看页面截图自行拆组件。

## 共享组件

| 组件 | 用途 | 状态 | Flutter 映射 |
| --- | --- | --- | --- |
| `App Shell` | 状态栏、App Bar、根滚动区、页面容器 | `Root / Subpage / Overlay` | `Scaffold + SafeArea + custom shell` |
| `App Bar` | 标题、返回、右侧轻操作统一头部结构 | `Root / Subpage / Action / Dense / Fixed Content-aligned List / Compact Detail / Compact Fixed Feed / Fixed Directory / Source-aware Back` | `PreferredSizeWidget + shared title/action slots` |
| `Input Field` | 单行表单、搜索与聊天输入的尺寸和聚焦语言 | `Composer 40px / Toolbar Search 44px / Standard Field 48px / Surface Focus` | `TextField + semantic size token + container surface treatment` |
| `Conversation Cell` | 会话、群目录、联系人、搜索结果等列表基础行 | `Default / Pinned / Unread / Muted / 48px Avatar / Group Composite Avatar` | `Reusable list tile + leading avatar + trailing meta` |
| `Message Bubble` | 单聊/群聊消息体，引用态显示回复来源与摘要 | `Incoming / Outgoing / Reply / Recent / Highlighted / Large Emoji / Playing` | `Message bubble + reaction row` |
| `Group Announcement Context` | 群聊顶部导航栏下方的固定单行公告摘要入口 | `Default / Updated / Truncated` | `Fixed context row + announcement detail route` |
| `Composer` | 输入框、表情、更多面板、发送动作 | `Idle / Typing / Compact Emoji Panel / Attachment Panel` | `Bottom composer + panel controller` |
| `Custom Emoji` | 通过稳定 emoji ID 解析 fallback、静态资源与播放资源 | `Panel Glyph / Large / Playing / Fallback` | `Emoji registry + asset resolver` |
| `Search Box` | 搜索 icon、输入框、上下文标签共用容器 | `Idle / Focused / Typing / Contextual / Clearable` | `Shared search field + optional context label` |
| `Message Search Result` | 消息检索结果：会话上下文、发件人、时间与关键词高亮 | `Recent / Query / Highlighted / Empty` | `Continuous result row + source message navigation` |
| `Button Set` | Primary / Ghost / Icon / Quiet Icon 四类按钮 | `Default / Pressed / Selected / Disabled / Loading` | `Button theme + semantic icon-button variants` |
| `Chip` | 轻标签、状态提示、过滤器 | `Soft / Filled / Selected / Dismissible` | `Assist chip / filter chip variants` |
| `Empty State` | 空列表、无结果、未开启功能说明 | `Plain / Actionable / Illustrated` | `Shared empty state widget` |
| `Action Card` | 设计入口、发现入口、快速评审卡片 | `Default / Pressed / Active / Disabled` | `Pressable surface card` |
| `Mine Profile` | 我的页资料主卡、在线状态与资料入口 | `Default / Online / Pressed` | `ProfileHeader + profile route` |
| `Contact Profile` | 居中身份区、可编辑的用户备注名、连续资料行、按需共同群聊、联系人操作面板与固定底部操作栏 | `Online / Away / Busy / Remark Set / Remark Unset / Remark Editing / Contact Actions / Shared Groups / No Shared Groups` | `ContactIdentity + editable user-owned remark row + contact action sheet + fixed message dock` |
| `Settings Row` | 设置、资料字段等通用行 | `Plain / Clickable / Switch / Static Detail / Danger` | `Row + optional trailing control` |
| `Scanner Workspace` | 扫描取景框、相册、手电筒和识别结果 | `Scanning / Torch On / Success / Error` | `Scanner scaffold + permission/result state` |
| `Nearby Person Row` | 附近人员、距离、在线状态与打招呼 | `Default / Filtered / Greeting Sent / Empty` | `Nearby person tile + greeting action` |
| `Game Entry` | 最近玩过与全部游戏内容单元 | `Recent / Available / Maintenance / Empty` | `Game cover tile + availability state` |
| `Settings Detail Sheet` | 设备、协议、存储和反馈的设备内详情面板 | `Informational / Actionable / Completed` | `Modal bottom sheet + settings action` |

App Bar 对齐规则：会话列表使用固定的内容对齐页头，列表滚动时标题和工具操作保持可见；嵌在已提供横向内容边距的列表滚动容器内时，页头不再额外添加横向 padding；左侧返回或标题与列表左线对齐，右侧操作与列表右线对齐。页面直接承载的普通页头保留一层内容边距；紧凑居中导航维持其独立的固定布局。

输入控件规则：聊天 composer 使用 `40px`，固定导航内搜索使用 `44px`，页面内搜索与单行表单字段使用 `48px`。触摸、鼠标和键盘聚焦均只改变外层 `Surface Soft` 表面色；内部 `input` 和 `textarea` 不增加边框、轮廓或外发光。

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

### 2. 移动设备预览壳 `Mobile Device Preview`

使用位置：

- `#/mobile-design`

结构：

- 宽屏设备选择器：默认 `iPhone 12 Pro`，可切换 `iPhone 16 Pro Max` 与 `Pixel 8 Pro`
- 宽屏数据模式选择器：`演示数据` 与 `空数据`；空数据场景保留账号、设置和静态服务入口，但会话、联系人、群聊、关系申请、搜索用户、动态、附近的人和游戏内容均为空
- device frame：独立的机身、侧键与顶部传感器装饰；iPhone 16 Pro Max 包含 Dynamic Island 与底部白色 Home Indicator
- screen clip：独立圆角裁切层，所有 App 内容、导航与 Toast 必须留在其中，并让底部固定内容避开 Home Indicator 安全区
- status bar
- full IM screen
- embedded toast layer

备注：

- 这是设计源专用的单一手机容器，用来串联完整移动端交互。
- `#/mobile-design/empty` 默认打开空会话首页，二级跳转保持 `#/mobile-design/empty/...` 前缀，避免空态审查回落到演示数据。
- 宽屏使用设备外壳进行尺寸和安全区审查；`640px` 以下直接显示 App，不展示外壳或切换器。
- 容器内必须使用真实业务页面，不能再放移动端路线说明、组件说明或评审卡片。
- 正式 App 不保留设备外框，但应继承其中的 App Shell、导航和页面层级。

### 3. 我的页资料区 `Mine Profile`

使用位置：

- `#/mine`

结构：

- 头像、在线状态、单行个性签名与资料入口
- 全卡与尾部导航指示共同承接资料跳转，不重复展示文字 CTA
- 账号安全与设置入口
- 隐私协议与关于入口

备注：

- 这是一级“我的”页的身份锚点；通知与隐私偏好不在这里展开。
- 不展示静态统计或聊天、联系人等根页已承接的快捷入口。
- 隐私协议和关于使用已有设置详情路由，作为低频支持入口保留。
- 账号安全与设置条目使用真实业务路由，设置入口固定进入 `#/settings`。

### 4. 联系人目录 `Contact Directory`

使用位置：

- `#/contacts`

结构：

- 固定目录栏：左侧联系人搜索、右侧添加好友操作
- 可随内容滚动的新的朋友与群聊快捷入口
- 单一字母分组联系人列表滚动面

备注：

- 联系人搜索替换可见页面标题并固定在目录栏内；保留屏读标题、搜索关联与输入光标恢复，不会在进入页面时自动唤起键盘。
- 目录栏仅在滚动后显示弱分隔与阴影；不使用二级页返回式居中标题。
- 不引入嵌套滚动；字母索引仅在真实分组数量足够多时再启用。

### 5. 群会话行 `Group Conversation Cell`

使用位置：

- `#/groups`
- `#/chats` 中的群聊会话

结构：

- 2 × 2 成员复合头像，使用 `48px` 外框，最多展示四位代表成员；已知成员不足四位时可用余量格表示更多成员
- 群名称、最后消息摘要、时间与未读状态
- 整行进入群会话
- 群设置中的当前用户收藏开关；收藏仅调整群目录优先级，不决定群是否可从联系人入口访问

备注：

- 群目录复用 `Conversation Cell` 的单行节奏，不再使用公告、标签、并列动作组成的资料卡。
- 联系人群目录以有效群成员关系为来源；收藏群显示在独立的“收藏群聊”分组，其他群继续直接列表展示，不再增加“已加入”标题。
- 群设置从列表下沉到群会话顶部资料入口，避免与“进入聊天”竞争主操作；成员预览紧随群概览，按可用宽度在每行五位与四位之间自动切换并限高，仅展示头像和姓名，不重复群总人数或成员状态；底部通过紧凑的“查看更多成员”控件展开已知成员与剩余人数；其余信息使用连续设置组组织公告与权限，不将每项拆成独立资料卡。
- 群成员关系不是联系人条目；联系人页仅提供进入群目录的快捷入口。

### 6. 好友申请决策卡 `Friend Request Decision Card`

使用位置：

- `#/contacts/requests`

结构：

- 固定页头下的收到/发出文字 Tab；Tab 不随申请列表滚动，分类文字等宽居中，当前分类以短活动指示线和文字层级标识
- 单一活动面板：仅展示当前分类的申请列表
- 关系请求摘要：头像、身份与右上角时间构成顶行；“申请留言”标签和高对比度正文置于无边框浅色内容容器；底部动作不使用额外分割线

备注：

- “收到的申请”与“发出的申请”使用固定顶部文字 Tab 切换，不再纵向拼接两个分组；当前项用短指示线表达，Tab 内数字说明当前分类的总量。
- 每条申请使用关系摘要卡：时间位于右上角；“申请留言”作为明确标签，高对比度正文置于无边框浅色内容容器；动作区以留白而非横线分隔。
- 申请卡和空状态复用运行时 `Surface` 的 `18px` 圆角，而不使用低圆角特例。
- Tab 必须使用按钮语义、当前状态和对应面板关联，并支持键盘方向键切换。
- 每条申请是独立决策单元，必须由单独表面卡片承载，不能将多条申请塞进一个连续的大容器；卡片内部只允许一处无边框的申请留言内容容器。
- 卡片状态变化后用同高度的结果栏替换操作栏，保持原有位置，避免处理动作造成无意义的页面跳动。

### 7. 发现入口卡片 `Discover Entry Card`

使用位置：

- `#/discover`

结构：

- icon
- title

备注：

- 发现页和总入口页都在使用“轻表面卡片 + 明确 CTA”的模式。
- 快捷入口卡只呈现图标与主标题，三项使用一行等分、内容居中布局，避免副标题和不完整网格制造噪音。
- Flutter 实现可以抽成同源容器，但保留不同的内容槽位。

### 8. 规范展示卡片 `Spec Surface`

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

### 9. 发现工具与内容单元

使用位置：

- `#/discover/scan`
- `#/discover/nearby`
- `#/discover/games`

规则：

- 扫一扫使用独立扫描工作区，不放入说明卡；相册、识别和手电筒保持稳定热区，结果由设备内面层承接。
- 附近的人复用连续列表节奏，一行只展示一处距离；整行进入资料，独立“打招呼”动作提供发送状态。
- 游戏页按“最近玩过 + 全部游戏”分组；封面使用可识别的本地图形资产，并明确可进入、维护中和空数据状态。

### 10. 设置详情面板

使用位置：

- `#/settings/account`
- `#/settings/chat`
- `#/settings/privacy`
- `#/settings/about`

规则：

- 静态值、链接和开关必须具有不同语义，不能统一渲染为不可操作的信息行。
- 设备、协议、存储策略和反馈详情使用设备内 bottom sheet；即时操作使用 Toast 完成反馈。
- bottom sheet 离开当前 route 时必须关闭，不能泄漏到其他设置页面。

## 高优先级组件实现顺序

建议 Flutter 落地顺序：

1. `App Shell`
2. `App Bar`
3. `Mine Profile`
4. `Conversation Cell`
5. `Message Bubble`
6. `Composer`
7. `Search Box`
8. `Button Set`
9. `Chip`
10. `Empty State`
11. `Settings Row`

原因：

- 会话、联系人、搜索、我的、设置与群聊等主流程直接依赖前 7 项的组件契约。
- `Button Set / Chip / Empty State` 决定全局反馈语言是否统一，不应等页面写散了再回收。
- `Action Card` 更多服务于设计入口、发现入口和次级导航，可在主流程稳定后补强。

## 复杂组件拆分建议

### Composer

建议拆成：

- 输入容器
- 文本输入区
- 左右动作位
- 表情面板
- 更多面板
- 面板在输入区下方展开/收缩，并与输入区共同处理底部安全区
- 表情 registry：稳定 `id`、fallback glyph、无障碍名称与 motion key；当前设计源仅使用系统 glyph fallback，正式运行时再由 asset resolver 装配自有静态与动画资源
- 纯表情消息：仅 registry 表情组成、且不含引用时使用无气泡大表情；刚发送的一条播放一次 motion
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
