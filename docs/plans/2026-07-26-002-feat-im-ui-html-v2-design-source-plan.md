---
title: "feat: 将 im-ui-html 升级为 RedCode IM 2.0 设计源"
type: feat
status: superseded
superseded_by: docs/plans/2026-08-01-002-refactor-im-ui-preview-stabilization-and-handoff-plan.md
date: 2026-07-26
---

# feat: 将 im-ui-html 升级为 RedCode IM 2.0 设计源

## 目标

把现有 `im-ui-html/` 从“可浏览的原型模块”提升为 **RedCode IM 2.0 的正式设计源**，用于：

- 定义统一视觉规范
- 定义核心页面结构和交互节奏
- 先完成移动端设计
- 再补桌面端适配
- 最后给 Flutter 落地提供清晰映射

## 来源与上下文

- 现有原型模块：`im-ui-html/`
- 现有原型计划：`docs/plans/2026-07-25-001-feat-html-im-ui-prototype-plan.md`
- 2.0 总计划：`docs/plans/2026-07-26-001-feat-im-2-0-flutter-multiplatform-rebuild-plan.md`

当前用户已经明确：

- 先设计，不先写 Flutter 正式页面。
- 设计阶段继续沿用 `im-ui-html/`，不新开第二个 HTML 模块。
- 先做移动端 UI 规范、样式和组件封装。
- 入口页要先提供 **规范页面 / PC 端设计 / 移动端 UI 设计** 3 个总入口。
- 移动端主链路纳入 **发现**，并给朋友圈、扫一扫、附近的人、游戏保留正式入口位。
- 再在同一设计语言下补桌面端适配。

## 需求映射

- R1. `im-ui-html/` 必须继续保留，并作为 2.0 设计入口。
- R2. 设计阶段先做 **规范 -> 样式 -> 组件 -> 页面**，而不是先堆页面。
- R3. 移动端是第一优先级，要先收敛手机端整体观感与交互节奏。
- R4. 原型要覆盖现有 IM 核心功能：登录、聊天、联系人、发现、好友申请/添加、建群、群设置、搜索、设置。
- R5. 原型要为未来扩展能力保留空间，但不能抢占当前主流程优先级。
- R6. 原型必须可点击、可跳转、可操作，mock 状态连续。
- R7. 要明确 2K / 1.5K / 1K 的视觉密度策略，避免 Flutter 落地后再次出现整体放大失真。
- R8. 在移动端方案稳定后，再补桌面宽屏适配；当前阶段允许先提供 `#/pc-design` 作为桌面蓝图入口。
- R9. 设计源最终要能给 Flutter 落地提供 token、组件、页面与状态映射。

## 范围

### 本计划覆盖

- `#/entry` 的 2.0 设计源总入口
- `#/spec` 的 2.0 设计系统升级
- `im-ui-html` 的移动端页面体系升级
- 页面与组件的状态说明
- 宽屏 / 桌面端适配原型
- Flutter handoff 所需的设计映射资产

### 本计划不覆盖

- 不接真实 API、WebSocket、上传或对象存储
- 不在本轮把 HTML 自动转成 Flutter 代码
- 不在本轮做像素级资产导出、Figma 同步或设计稿切图流水线
- 不在本轮引入 bundler、framework 或 npm 依赖

## 设计原则

- **移动端优先**：先定义手机端的视觉与交互，再扩展桌面端。
- **设计系统先于页面**：先定 tokens、布局、组件，后做页面重构。
- **强状态可视化**：空态、选中态、失败态、加载态、禁用态必须能直接看到。
- **流程完整优先于特效炫技**：先保证 IM 主流程都能走通，再补动效细节。
- **Flutter 可映射**：避免只适合 HTML 拼装、却不适合 Flutter 落地的结构。

## 关键技术决策

- **继续使用单页 hash router**：维持 `file://` 和本地静态服务双可用。
- **继续使用纯静态技术栈**：保持 `HTML + CSS + JS`，不引入新工具链。
- **把 `#/entry` 升格为第一入口**：总入口先分流到规范页、PC 端设计和移动端 UI 设计，`#/spec` 继续作为规范源核心页面。
- **原型内同时承载“可浏览页面”和“可交付说明”**：让评审者不必再翻文档和旧页面对照理解。
- **桌面适配不新开第二套原型**：仍在同一 `im-ui-html/` 中通过 layout mode 展示。

## 目标产物

```text
im-ui-html/
  index.html
  README.md
  assets/
    styles.css
    app.js
    mock-data.js
  docs/
    design-tokens.md
    component-inventory.md
    page-map.md
    flutter-handoff.md
```

> `docs/` 目录当前还不存在，本计划把它定义为设计源的附属文档目录。

## 页面范围

### 移动端必须覆盖

- `#/entry`
- `#/spec`
- `#/pc-design`
- `#/mobile-design`
- `#/auth/login`
- `#/chats`
- `#/chat/:chatId`
- `#/contacts`
- `#/discover`
- `#/discover/moments`
- `#/discover/scan`
- `#/discover/nearby`
- `#/discover/games`
- `#/contacts/requests`
- `#/contacts/add`
- `#/contacts/profile/:contactId`
- `#/groups/create`
- `#/groups/settings/:groupId`
- `#/search`
- `#/settings`

### 桌面适配阶段补充

- 宽屏聊天首页 / 默认空态
- 宽屏聊天详情三栏或双栏结构
- 桌面设置页布局
- 桌面联系人 / 群管理布局
- 桌面文件 / 侧边信息面板示意

## 实施单元

### Unit 1：先完成 `#/entry` 与 `#/spec`，把设计源入口做成双层结构

**目标：** 先把总入口、token、密度、布局、组件状态、动效原则讲清楚。

**关联需求：** R1, R2, R3, R7, R9

**依赖：** None

**文件：**
- Modify: `im-ui-html/index.html`
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/assets/app.js`
- Create: `im-ui-html/docs/design-tokens.md`
- Create: `im-ui-html/docs/page-map.md`

**测试文件 / 验证入口：**
- `im-ui-html/index.html`
- `im-ui-html/docs/design-tokens.md`
- `im-ui-html/docs/page-map.md`

**测试场景：**
- Happy path — `#/entry` 能明确分流到规范页、PC 端设计和移动端 UI 设计。
- Happy path — `#/spec` 能明确展示颜色、字体、圆角、间距、层级、动效和密度映射。
- Happy path — 能一眼看出 2K / 1.5K / 1K 三档密度规则。
- Edge case — 规范页本身不是海报，而是可切换、可比对、可用于评审的页面。

### Unit 2：重做移动端核心页面的视觉与交互基线

**目标：** 先把手机端核心 IM 流程做成统一且高保真的 2.0 基线。

**关联需求：** R2, R3, R4, R6, R7

**依赖：** Unit 1

**文件：**
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/assets/mock-data.js`
- Modify: `im-ui-html/README.md`

**测试文件 / 验证入口：**
- `im-ui-html/index.html`
- `im-ui-html/README.md`

**测试场景：**
- Happy path — 从登录到聊天、联系人、建群、搜索、设置形成完整可走通链路。
- Happy path — 聊天输入区、消息气泡、搜索结果、好友申请、建群页和群设置页都有一致语言。
- Edge case — 空态、无搜索结果、无好友、无群成员、未开启功能时均有清晰占位。

### Unit 3：补组件清单与状态契约

**目标：** 让 Flutter 实现阶段知道“有哪些组件、每个组件有哪些状态”，而不是只看到页面截图。

**关联需求：** R2, R6, R9

**依赖：** Unit 1, Unit 2

**文件：**
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/assets/app.js`
- Create: `im-ui-html/docs/component-inventory.md`
- Create: `im-ui-html/docs/flutter-handoff.md`

**测试文件 / 验证入口：**
- `im-ui-html/docs/component-inventory.md`
- `im-ui-html/docs/flutter-handoff.md`

**测试场景：**
- Happy path — 输入框、按钮、卡片、列表项、弹窗、消息气泡、过滤器等组件都有状态定义。
- Happy path — 文档能说明哪些组件共享、哪些是页面专用。
- Edge case — 复杂组件如聊天输入区、附件卡片、搜索结果项有明确拆分建议。

### Unit 4：在同一原型中补桌面适配

**目标：** 让 2.0 设计源同时提供桌面布局基线，但不抢移动端先手。

**关联需求：** R3, R5, R8, R9

**依赖：** Unit 2, Unit 3

**文件：**
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/README.md`
- Modify: `im-ui-html/docs/page-map.md`
- Modify: `im-ui-html/docs/flutter-handoff.md`

**测试文件 / 验证入口：**
- `im-ui-html/index.html`
- `im-ui-html/docs/flutter-handoff.md`

**测试场景：**
- Happy path — 原型能切换或展示桌面宽屏布局。
- Happy path — 桌面聊天页至少能演示双栏/三栏结构与信息侧栏。
- Edge case — 桌面布局不是单纯把手机页面横向放大。

### Unit 5：形成 Flutter 实施交接包

**目标：** 在开始 Flutter 正式开发前，把设计源沉淀成可执行的交付物。

**关联需求：** R1, R6, R8, R9

**依赖：** Unit 1, Unit 2, Unit 3, Unit 4

**文件：**
- Modify: `im-ui-html/README.md`
- Modify: `im-ui-html/docs/design-tokens.md`
- Modify: `im-ui-html/docs/component-inventory.md`
- Modify: `im-ui-html/docs/page-map.md`
- Modify: `im-ui-html/docs/flutter-handoff.md`

**测试文件 / 验证入口：**
- `im-ui-html/README.md`
- `im-ui-html/docs/`

**测试场景：**
- Happy path — 开发者只看 `im-ui-html/` 与其 docs，就能知道 2.0 先实现哪些页面与组件。
- Happy path — Flutter 落地时能直接对应 shell、route、component、token、density 五类信息。
- Edge case — 评审者不需要翻旧 UI 或旧代码，也能理解 2.0 要长什么样。

## 执行顺序

1. 先完成 Unit 1：规范页升级。
2. 再完成 Unit 2：移动端主流程页面升级。
3. 再完成 Unit 3：组件和 handoff 文档。
4. 再完成 Unit 4：桌面宽屏适配。
5. 最后完成 Unit 5：形成 Flutter 交接包。

## 风险与防错

- **先堆页面、后补规范**：会导致风格再次发散。规避方式：`#/entry` 与 `#/spec` 必须先完成。
- **只做视觉，不做状态**：Flutter 落地时会再次自己发明交互。规避方式：组件清单与状态契约必须出文档。
- **移动端未稳定就补桌面**：会造成双端一起发散。规避方式：桌面适配延后到 Unit 4。
- **原型和 handoff 脱节**：会让 HTML 评审价值下降。规避方式：同模块内保留设计说明 docs。

## 验证策略

- 原型阶段以本地静态方式验证，不接真实后端。
- 每个里程碑都要保证推荐评审路径可复现。
- `README`、`#/entry`、`#/spec`、业务路由和 `docs/` 说明必须互相一致。

## 下一步

1. 直接从 Unit 1 开始，先升级 `#/entry` 与 `#/spec`。
2. 然后进入移动端核心页面重构。
3. `im-ui-html/` 稳定后，再切到 `app/` 做 Flutter 多平台壳层重组。
