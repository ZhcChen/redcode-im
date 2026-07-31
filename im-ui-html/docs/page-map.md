# RedCode IM 2.0 页面地图

## 1. 设计源入口层

这些页面属于 `im-ui-html/` 设计源自身，不等于正式 App 的业务 route。

| Route | 作用 | 说明 |
| --- | --- | --- |
| `#/entry` | 总入口 | 分流到规范页、PC 蓝图页与移动端设备预览 |
| `#/spec` | 规范源 | 展示 token、icon、组件、流转 |
| `#/pc-design` | 桌面蓝图 | 展示桌面三栏工作台结构 |
| `#/mobile-design` | 移动端设备预览 | 只显示一个可交互的手机容器，默认使用 `iPhone 12 Pro` 外壳；宽屏可切换 `iPhone 16 Pro Max` 或 `Pixel 8 Pro`，并可在演示数据与空数据间切换，不显示设计说明或评审侧栏 |

## 2. 独立移动端预览

`#/mobile-design` 是设计源内的完整手机设备画布，不是业务页之外的说明页。宽屏默认使用 `iPhone 12 Pro`，可切换 `iPhone 16 Pro Max` 或 `Pixel 8 Pro`；同时可切换演示数据与空数据场景。空数据仅清空会话、联系人、群聊、关系申请、搜索用户与发现内容，账号、设置和服务入口保持可用。iPhone 16 Pro Max 包含 Dynamic Island、底部白色 Home Indicator 与独立安全区。所有业务内容必须受设备内的独立屏幕裁切层约束，不能露出外壳。

| Route | 说明 |
| --- | --- |
| `#/mobile-design` | 默认显示聊天首页；宽屏默认 `iPhone 12 Pro`，可切换 `iPhone 16 Pro Max` 或 `Pixel 8 Pro` |
| `#/mobile-design/empty` | 空数据手机壳，默认显示空会话；二级页面使用 `#/mobile-design/empty/<业务路径>` 并始终保持空数据场景 |
| `#/mobile-design/chats` | 会话列表 |
| `#/mobile-design/chat/:chatId` | 聊天详情 |
| `#/mobile-design/contacts` | 联系人目录：固定搜索栏、快捷入口和单一分组列表滚动面 |
| `#/mobile-design/discover` | 发现 |
| `#/mobile-design/mine` | 我的 |
| `#/mobile-design/settings` | 设置（从“我的”进入） |
| `#/mobile-design/<业务路径>` | 将任意已注册的移动业务路径保留在同一手机容器内 |

容器内的一级导航、二级跳转、输入、Toast 和返回操作都不能跳出 `#/mobile-design/...`。空数据场景内的跳转必须保留 `#/mobile-design/empty/...` 前缀。二级页返回优先回到实际进入来源；直接打开深链时，使用该业务链路的默认兜底，且仍保留在设备容器内。

## 3. 移动端业务地图

### 一级导航

| 一级入口 | Route | 说明 |
| --- | --- | --- |
| 聊天 | `#/chats` | 会话列表主入口；固定顶部聊天页头，聊天标题与置顶分组标题按同一内容左线对齐，搜索/建群按钮与会话列表右线对齐 |
| 联系人 | `#/contacts` | 联系人与关系链路；固定搜索栏、快捷入口与单一分组列表滚动面 |
| 发现 | `#/discover` | 朋友圈、扫一扫、附近的人、游戏入口 |
| 我的 | `#/mine` | 身份、账户操作与支持入口 |

### 聊天链路

| Route | 说明 |
| --- | --- |
| `#/chat/:chatId` | 聊天详情；群聊在固定会话头部下方显示单行群公告摘要，消息流在其下独立滚动 |
| `#/search` | 消息搜索：紧凑固定搜索栏、常用关键词和连续结果行；结果保留会话/发件人/时间上下文与关键词高亮，点击后返回并高亮原消息 |

### 联系人链路

| Route | 说明 |
| --- | --- |
| `#/contacts/requests` | 好友申请：无右侧统计数字的紧凑页头，固定顶部文字 Tab 以短指示线与分类总数切换收到与发出的申请，每条申请使用带无边框留言容器的关系摘要卡 |
| `#/contacts/add` | 添加好友 |
| `#/contacts/profile/:contactId` | 联系人资料页：保留顶部返回导航；主体使用居中身份区和连续资料行，首行“备注名”仅承载当前用户为该联系人设置的别名，点击可编辑、清空或取消；职责说明不作为备注展示。共同群聊仅在存在时作为可跳转列表显示；固定底栏左侧“更多联系人操作”打开包含修改备注、语音通话和视频通话的设备内底部面板，主“发送消息”按钮固定在设备内容区底部 |

### 群组链路

| Route | 说明 |
| --- | --- |
| `#/groups` | 群会话目录：顶部返回与创建操作分别和群列表的左右内容线对齐；所有仍有效的群成员关系都会出现，收藏群以“收藏群聊”分组优先展示，未收藏群不重复显示“已加入”标题 |
| `#/groups/create` | 创建群聊：顶部返回、群聊名称表单、成员选择器和底部创建操作共用一层主内容边界 |
| `#/groups/settings/:groupId` | 群设置：复合头像群概览后优先展示按可用宽度自适应四至五列、限高的成员预览，仅保留头像与姓名；可通过紧凑“查看更多成员”控件展开，其余内容按当前用户收藏偏好、公告与权限分组，避免将每项拆成独立资料卡 |

### 发现链路

| Route | 说明 |
| --- | --- |
| `#/discover/moments` | 朋友圈内容流，使用紧凑固定导航栏；图片数量布局遵循 `moments-media-layout.md` |
| `#/discover/moments/:momentId` | 朋友圈动态详情；复用内容流的图片分栏规则并提供点赞、评论交互 |
| `#/discover/scan` | 扫一扫：全宽扫描工作区，提供相册、模拟识别、手电筒及成功/失败结果状态 |
| `#/discover/nearby` | 附近的人：位置状态、距离/在线筛选、连续人员列表和打招呼反馈 |
| `#/discover/games` | 游戏：最近玩过、全部游戏、可进入/维护中及空数据状态 |

### 我的与设置链路

| Route | 说明 |
| --- | --- |
| `#/mine` | 我的一级页：资料、账户操作与支持入口 |
| `#/mine/profile` | 个人资料，使用紧凑详情导航栏；`#/settings/profile` 保持兼容映射 |
| `#/settings` | 设置二级页：账号、通知、隐私与偏好 |
| `#/settings/account` | 账号与安全 |
| `#/settings/chat` | 聊天偏好与存储 |
| `#/settings/privacy` | 隐私协议与数据使用 |
| `#/settings/about` | 关于与版本信息 |

### 其他业务页

| Route | 说明 |
| --- | --- |
| `#/auth/login` | 登录页 |

### 设计源内部工具

| Route | 说明 |
| --- | --- |
| `#/lab` | 实验模块总览，仅用于概念、状态与方向评审 |
| `#/lab/:moduleId` | 实验模块详情；不进入正式 App 导航或 Flutter route 映射 |

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
6. `#/mobile-design/groups`
7. `#/mobile-design/groups/create`
8. `#/mobile-design/discover`
9. `#/mobile-design/mine`
10. `#/mobile-design/mine/profile`
11. `#/mobile-design/settings`
12. `#/pc-design`

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
| `#/mine` | `home/mine` |
| `#/mine/profile` | `mine/profile` |
| `#/settings` | `mine/settings` |
| `#/settings/:section` | `mine/settings/:section` |
| `#/lab`、`#/lab/:moduleId` | 不进入正式 runtime；保留为 HTML 设计源内部工具 |

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
