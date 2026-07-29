# RedCode IM 2.0 设计 Tokens

## 目的

本文件把 `im-ui-html/` 当前已经落地的视觉基础整理成稳定 token，作为后续 Flutter `im_ui_kit` 的输入，而不是继续靠页面截图口头传递。

设计源参考页面：

- `#/entry`
- `#/spec`
- `#/pc-design`
- `#/mobile-design`

## 颜色

| Token | Value | 用途 |
| --- | --- | --- |
| `Primary` | `#2563EB` | 主动作、激活态、关键强调；HTML 设计源的科技蓝主色 |
| `Primary Strong` | `#1D4ED8` | 主按钮深色端、文字强调 |
| `Primary Soft` | `#E8F0FF` | 激活 icon 背景、轻提示与低强调面层 |
| `Background` | `#F5F7FB` | 移动业务页冷白蓝灰基底背景 |
| `Surface` | `#FFFFFF` | 列表、设置分组、消息气泡 |
| `Surface Soft` | `#EEF3FA` | 输入区、轻提示，以及 Quiet Icon 的按下/悬停反馈；不作为顶部工具按钮的默认底色 |
| `Surface Muted` | `#E4EAF3` | 分隔线与更弱层级 |
| `Text Primary` | `#172033` | 主标题、正文 |
| `Text Secondary` | `#6F7D91` | 摘要、说明、次级信息 |
| `Divider` | `rgba(22, 35, 57, 0.08)` | 列表内部弱分隔，不作为常态外框 |
| `Danger` | `#F6695E` | 删除、未读提醒、危险操作 |

深色模式的对应强调色为 `#5B8CFF / #8CB3FF / #172E5C`。本轮科技蓝只作用于 `im-ui-html/` 设计源；Flutter 当前 `AppColors.primary` 仍保持既有值，待视觉方向确认后单独映射。

## 字体

| Token | Value | 用途 |
| --- | --- | --- |
| `Display` | `SF Pro Display / PingFang SC / MiSans` | 大标题、入口页、规范页主标题 |
| `UI` | `SF Pro Text / PingFang SC` | 列表、按钮、正文、设置项 |
| `Scale` | `28 / 22 / 18 / 16 / 14 / 12` | 标题到注释的统一字号级差 |

约束：

- 移动端不再为每个页面单独发明字号体系。
- 入口页和规范页允许更大的 Display 层级，但业务页正文仍以 UI 字体节奏为主。
- PC 蓝图可以提升信息密度，但不另起一套字体规范。

## 间距 / 圆角 / 动效

| Token | Value | 用途 |
| --- | --- | --- |
| `Core Spacing` | `4 / 8 / 12 / 16 / 20 / 24` | 全局间距基线 |
| `Radius` | `14 / 18 / 22 / Pill` | 控件使用 `14px`；列表、设置分组使用 `18px`；强调卡片与大面层使用 `22px`；不以描边充当层级 |
| `Motion` | `140ms / 220ms / 280ms` | 悬浮反馈、页面入场、消息动效 |
| `Density` | `2K 1.00 / 1.5K 0.94 / 1K 0.88` | 手机密度缩放系数 |

动效原则：

- 页面切换：轻位移 + 淡入
- 消息进入：自下而上短距离入场
- 面板展开：输入区上移，表情或更多面板在其下方展开/收缩，不覆盖底部安全区
- 纯表情消息：registry 内的纯表情不使用文本气泡；刚发送时按 motion key 播放一次，且必须遵从 `prefers-reduced-motion`

## 密度策略

| 档位 | Scale | 策略 |
| --- | --- | --- |
| `2K` | `1.00` | 保持精细留白，优先保住呼吸感 |
| `1.5K` | `0.94` | 同步收紧字号、圆角、控件高度，避免“发胖” |
| `1K` | `0.88` | 继续压缩视觉体积，但不牺牲触达热区 |

规则：

- 密度变化必须统一作用于字号、圆角、间距和控件高度。
- 禁止单个页面自行放大或缩小 UI。
- Flutter 落地时优先走统一 `phone_density` / `screen_adaptation`，不要在页面局部再做比例补丁。

## Icon 规则

虽然 icon 分类展示在 `#/spec` 的 Icon tab 中，这里只记录会影响实现的基础约束：

- 导航、操作、发现功能三类 icon 均使用简洁轮廓语义。
- 点击 icon 必须落在稳定热区内，目标尺寸优先对齐 `40-44dp`。
- 移动端以无外框面层为默认：通过页面底色、实色 Surface、明显圆角和内部弱分隔建立层级；避免给每个卡片、输入框和列表组加描边。
- 底部导航的 icon 视觉尺寸固定为 `26px`，每项保留至少 `44px` 热区；激活态只为 icon 提供局部弱高亮，不做覆盖内容的大型浮动胶囊。
- 顶部返回与工具操作使用 `Quiet Icon`：默认透明且保持 `44px` 热区，仅在按下或具备 hover 能力的设备悬停时使用 `Surface Soft`；键盘焦点保留可访问性描边。
- `Primary Soft` 只表达激活/选中状态，例如底部当前 tab、选中筛选或已打开的面板，不能作为所有 icon button 的默认底色。
- 搜索等输入容器可持续使用 `Surface Soft`；输入获得焦点不以常驻外发光表达状态。
- 当前正式 key 统一收敛为三组：
  - 一级导航：`chats / contacts / discover / profile`
  - 基础操作：`back / search / plus / emoji / more / send / settings / shield`
  - 发现功能：`moments / scan / nearby / games`
- Flutter 落地时优先把 icon key 当语义层，不要把某页临时字符或图片资源继续带进组件实现。

## 壳层规则

### 设计源壳层

- `#/entry`：设计源总入口，不属于正式业务页。
- `#/spec`：规范源核心页面，用来评审 token、icon、组件、流转。
- `#/pc-design`：桌面蓝图页，用来说明宽屏布局原则。
- `#/mobile-design`：独立手机设备画布，默认展示聊天首页；宽屏默认使用 `iPhone 12 Pro` 外壳，可切换 `iPhone 16 Pro Max` 或 `Pixel 8 Pro`，其业务路径以 `#/mobile-design/<业务路径>` 保留在同一手机容器内。
- `#/mobile-design` 是独立设备预览模式：不显示工具条、说明卡或验证侧栏；设备切换器仅在宽屏作为紧凑预览控制存在，App 内容、导航和 Toast 必须受独立屏幕裁切层约束。
- 设计评审模式：普通业务路由在桌面默认显示机框与评审控制；可显式通过 `?mode=review` 固定。
- 手机运行模式：普通业务路由在 `640px` 以下直接显示应用界面，不显示外层工具条、机框或验证卡；可通过 `?mode=app` 强制开启。

### 业务壳层

- 移动端一级导航：聊天 / 联系人 / 发现 / 我的，采用稳定底栏；设置从“我的”页下沉为二级入口，不使用覆盖内容的大型浮动胶囊。
- 所有详情、搜索、申请、群设置下沉到二级页。
- 聊天详情的消息流优先级最高；群公告以头部下方固定的单行上下文条呈现，资料、文件与其他低频信息以轻提示或二级入口承载。
- 桌面端沿用同一视觉语言，但重组为导航 / 会话 / 主聊天 / 资料侧栏。

## Flutter 落地提示

- `Primary`、`Surface`、`Text`、`Divider` 这些 token 应优先进入 `app/lib/core/theme` 或未来的 `packages/im_ui_kit/`
- 密度 token 继续映射到现有 `phone_density.dart`、`screen_adaptation.dart`
- 设计源入口本身不一定成为正式业务 route，但它定义的 token 必须成为正式实现的唯一视觉来源
