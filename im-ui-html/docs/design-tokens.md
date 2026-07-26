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
| `Primary` | `#19C7B8` | 主动作、激活态、关键强调 |
| `Primary Strong` | `#0D9D91` | 主按钮深色端、文字强调 |
| `Background` | `#F6F8FB` | 页面基底背景 |
| `Surface` | `#FFFFFF` | 主内容面板 |
| `Surface Soft` | `#F2F5F8` | 输入区、次级容器、辅助面层 |
| `Surface Muted` | `#E9EDF2` | 更弱的背景对比层 |
| `Text Primary` | `#131927` | 主标题、正文 |
| `Text Secondary` | `#617085` | 说明文案、摘要 |
| `Divider` | `rgba(16,24,40,0.08)` | 分隔线、描边 |
| `Danger` | `#F6695E` | 删除、未读提醒、危险操作 |

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
| `Radius` | `10 / 14 / 18 / 22 / Pill` | 输入框、卡片、胶囊导航、Badge |
| `Motion` | `140ms / 220ms / 280ms` | 悬浮反馈、页面入场、消息动效 |
| `Density` | `2K 1.00 / 1.5K 0.94 / 1K 0.88` | 手机密度缩放系数 |

动效原则：

- 页面切换：轻位移 + 淡入
- 消息进入：自下而上短距离入场
- 面板展开：输入区上浮，不打断当前上下文

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
- 激活态优先用主色、胶囊底和弱高亮表达，不依赖复杂填充或插画。

## 壳层规则

### 设计源壳层

- `#/entry`：设计源总入口，不属于正式业务页。
- `#/spec`：规范源核心页面，用来评审 token、icon、组件、流转。
- `#/pc-design`：桌面蓝图页，用来说明宽屏布局原则。
- `#/mobile-design`：移动端入口页，用来收敛手机主链路。

### 业务壳层

- 移动端一级导航：聊天 / 联系人 / 发现 / 设置
- 所有详情、搜索、申请、群设置下沉到二级页
- 桌面端沿用同一视觉语言，但重组为导航 / 会话 / 主聊天 / 资料侧栏

## Flutter 落地提示

- `Primary`、`Surface`、`Text`、`Divider` 这些 token 应优先进入 `app/lib/core/theme` 或未来的 `packages/im_ui_kit/`
- 密度 token 继续映射到现有 `phone_density.dart`、`screen_adaptation.dart`
- 设计源入口本身不一定成为正式业务 route，但它定义的 token 必须成为正式实现的唯一视觉来源
