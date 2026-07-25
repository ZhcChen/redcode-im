---
title: feat: 新建纯 HTML IM UI 重构原型模块
type: feat
status: completed
date: 2026-07-25
---

# feat: 新建纯 HTML IM UI 重构原型模块

## Overview

新增一个完全独立的纯 HTML/CSS/JS 原型模块，用统一的设计系统重构 RedCode IM 的界面语言，并基于 mock 数据提供可浏览、可跳转、可操作的交互原型。

## Problem Frame

当前 IM 客户端已经具备较完整功能，但用户明确反馈现有 UI 质量偏弱、风格不统一、页面之间的设计语言不够稳定。需要一个不受现有 Flutter / Vue 组件约束的独立原型模块，先把视觉规范、信息层级、交互节奏和功能拓展位定义清楚，再作为后续正式重构的设计基线。

## Requirements Trace

- R1. 新建一个独立模块，技术栈限定为纯 HTML + CSS + JS，不依赖框架。
- R2. 先输出统一的 UI 风格与设计规范，再承载具体页面。
- R3. 覆盖当前 IM 的核心功能页面：登录、会话、聊天详情、联系人、好友申请/添加好友、创建群聊、群设置、消息搜索、设置等。
- R4. 对未来可能扩展的 IM 能力预留并设计页面，例如通话、AI 助理、文件协作/工作台等。
- R5. 使用 mock 数据驱动，页面之间能进行逻辑跳转，关键交互可直接演示。
- R6. 模块应可本地直接打开或以最轻方式启动，不引入额外构建链。

## Scope Boundaries

- 不修改现有 Flutter / H5 / Desktop 正式业务 UI。
- 不接入真实 API、WebSocket、上传、鉴权或数据库。
- 不在本轮把原型转换成正式可发布前端应用。
- 不引入 npm / bundler / framework 作为模块运行前提。

## Context & Research

### Relevant Code and Patterns

- 当前功能基线：`docs/reports/module-function-inventory-2026-03-01.md`
- Frontend 详细功能清单：`docs/reports/2026-03-05-frontend-function-inventory.md`
- 现有 Flutter 聊天主界面：`app/lib/features/chat/chat_list_page.dart`
- 现有 Flutter 聊天详情：`app/lib/features/chat/chat_detail_page_v2.dart`
- 现有联系人与添加好友：`app/lib/features/contacts/contacts_page.dart`、`app/lib/features/contacts/add_friend_page.dart`
- 现有设置页：`app/lib/features/settings/settings_page.dart`

### Institutional Learnings

- `docs/reports/flutter-first-release-readiness-2026-07-23.md` 表明当前移动端主线已经具备账号、好友、群、消息、设置等完整业务闭环，可作为原型覆盖范围依据。

### External References

- 本轮不做外部框架研究，优先输出仓库内可直接运行、可评审的独立设计原型。

## Key Technical Decisions

- **独立模块命名为 `im-ui-html/`**：避免与现有 `app/`、`h5-app/`、`desktop/` 混淆，明确这是设计原型而不是业务实现。
- **单页 hash router + 多视图模板**：保证 `file://` 与静态服务器都能运行，避免服务端路由依赖。
- **设计规范页和业务原型放在同一模块**：评审时可先看设计系统，再切到具体页面，不需要维护两套产物。
- **统一 mock store 管理会话、联系人、群组、设置、扩展模块数据**：让跨页面跳转和状态变化具备连续性。
- **以“统一视觉语言 + 高保真流程”优先，而非像素复刻现有 UI**：目标是作为重构基线，不受现有实现细节绑死。
- **默认采用暗色高密度 IM 视觉体系**：长时间使用更稳定，同时保留浅色 token 与切换开关，验证未来主题扩展能力。

## Open Questions

### Resolved During Planning

- **模块是否需要真实后端？** 不需要，本轮完全 mock。
- **是否要拆成多 HTML 文件？** 不拆，采用单页路由，减少维护成本并保持原型状态连续。
- **是否必须兼容无本地服务场景？** 是，尽量保证直接打开 `index.html` 即可使用。

### Deferred to Implementation

- **最终扩展页面保留哪些功能卡片最合适？** 先按 IM 常见扩展位（通话、AI、文件协作、任务流）实现，后续评审可再删减。
- **是否补充更多品牌视觉素材（图标、插画、真实头像）？** 本轮先用 CSS/SVG/字母头像与 mock 缩略图占位。

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
index.html
  ├─ static shell
  │   ├─ app sidebar / topbar
  │   ├─ main stage
  │   └─ contextual panel / modal root
  ├─ styles.css
  │   ├─ tokens: color / spacing / radius / shadow / motion
  │   ├─ layout system
  │   ├─ component primitives
  │   └─ page-specific polish
  └─ app.js
      ├─ mock store
      ├─ hash router
      ├─ renderers by route
      ├─ action handlers (send / search / add friend / create group / toggles)
      └─ lightweight UI state (drawer / modal / active filters / theme)
```

## Implementation Units

- [x] **Unit 1: 建立原型模块骨架与设计规范页**

**Goal:** 创建 `im-ui-html/` 模块基础目录、入口文件、样式层和设计规范页，先把视觉语言固定下来。

**Requirements:** R1, R2, R6

**Dependencies:** None

**Files:**
- Create: `im-ui-html/index.html`
- Create: `im-ui-html/assets/styles.css`
- Create: `im-ui-html/README.md`
- Create: `docs/plans/2026-07-25-001-feat-html-im-ui-prototype-plan.md`

**Approach:**
- 在入口页提供“设计规范 / 原型总览 / 进入应用”三个主区块。
- 定义颜色、字体、圆角、阴影、间距、栅格、交互反馈和页面模板规则。
- 以 CSS variables 承担 design tokens，避免后续页面各自发散。

**Patterns to follow:**
- 仓库中独立模块目录结构风格：`website/`、`h5-app/`
- 文档命名和路径规则：`docs/index.md`、`docs/plans/*.md`

**Test scenarios:**
- Happy path — 直接打开 `im-ui-html/index.html` 能看到设计规范页与原型入口。
- Happy path — 规范页能展示 token、组件状态、页面清单与视觉原则。
- Edge case — 关闭网络后页面仍可打开，不依赖外部框架资源。

**Verification:**
- 模块目录可独立打开。
- 设计规范页已能清晰表达统一 UI 风格，不需要阅读代码才能理解设计方向。

- [x] **Unit 2: 建立路由、mock store 与全局应用骨架**

**Goal:** 让原型具备真实应用般的导航框架、状态容器与跨页跳转能力。

**Requirements:** R1, R3, R5, R6

**Dependencies:** Unit 1

**Files:**
- Modify: `im-ui-html/index.html`
- Create: `im-ui-html/assets/mock-data.js`
- Create: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/assets/styles.css`
- Test: `im-ui-html/README.md`

**Approach:**
- 使用 hash route 管理页面切换，例如 `#/spec`、`#/chats`、`#/chat/<id>`。
- mock 数据集中管理用户、联系人、群组、消息、请求、扩展模块卡片、设置选项。
- 建立统一 shell：左侧导航、顶栏、内容区、右侧情报面板、底部移动导航。

**Patterns to follow:**
- 功能域边界参考：`docs/reports/2026-03-05-frontend-function-inventory.md`
- 业务模块划分参考：`docs/reports/module-function-inventory-2026-03-01.md`

**Test scenarios:**
- Happy path — 点击一级导航可在设计规范、会话、联系人、发现/扩展、设置之间切换。
- Happy path — 页面刷新后 hash 路由仍能回到当前视图。
- Edge case — 路由不存在时回退到默认页。
- Integration — 不同页面共享同一份 mock 状态，聊天列表、联系人、群组等数据能连续使用。

**Verification:**
- 原型具备可持续浏览的应用骨架，不再是单页静态海报。

- [x] **Unit 3: 实现 IM 当前核心流程页面与关键交互**

**Goal:** 覆盖现有 IM 主线功能，形成可演示的聊天 / 联系人 / 建群闭环。

**Requirements:** R3, R5

**Dependencies:** Unit 2

**Files:**
- Modify: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/assets/mock-data.js`
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/index.html`
- Test: `im-ui-html/README.md`

**Approach:**
- 实现登录页、会话列表、聊天详情、联系人列表、好友申请、添加好友、联系人详情、创建群聊、群设置、消息搜索等页面。
- 关键交互要能驱动 mock state：发送消息、切换会话、搜索联系人、发送申请、处理申请、选择成员建群、切换群设置、从搜索结果跳转聊天等。
- 聊天详情页要体现消息层级、附件卡片、引用、reaction、输入区和情报侧栏。

**Patterns to follow:**
- 聊天能力基线：`app/lib/features/chat/chat_detail_page_v2.dart`
- 联系人流程基线：`app/lib/features/contacts/add_friend_page.dart`
- 创建群聊流程基线：`app/lib/features/chat/create_group_page.dart`

**Test scenarios:**
- Happy path — 从会话列表进入聊天详情，发送新消息后列表与详情同步更新。
- Happy path — 在添加好友页输入关键词，结果列表过滤并能触发“发送申请”。
- Happy path — 在好友申请页接受/拒绝后状态更新，接受后联系人页可见新好友。
- Happy path — 在创建群聊页选择好友并创建新群，自动跳转到新群聊天页。
- Happy path — 在消息搜索页点击结果可跳回对应聊天上下文。
- Edge case — 没有搜索结果、没有群成员、没有待处理申请时显示空态。
- Integration — 联系人、会话、群组之间的数据流转保持一致。

**Verification:**
- 核心 IM 主流程已可完整走通，评审者不需要脑补交互。

- [x] **Unit 4: 实现未来扩展页面、主题切换与原型使用说明**

**Goal:** 在统一风格下展示未来扩展能力，并把原型作为可复用评审资产交付。

**Requirements:** R4, R5, R6

**Dependencies:** Unit 3

**Files:**
- Modify: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/assets/mock-data.js`
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/README.md`

**Approach:**
- 增加未来扩展位页面，例如通话中台、AI 助理、文件协作/知识库、团队工作台。
- 通过设置页提供主题切换、布局密度切换、通知偏好等示意能力。
- README 说明模块目标、路由清单、启动方式和建议评审路径。

**Patterns to follow:**
- 发现页 / mock 内容思路：`frontend/lib/features/discover/discover_page.dart`
- 设置能力边界：`frontend/lib/features/settings/settings_page.dart`

**Test scenarios:**
- Happy path — 扩展页之间可以跳转，并可从主导航与卡片入口进入。
- Happy path — 主题切换后全局 token 生效，主要页面视觉同步变化。
- Edge case — 扩展页空数据或未启用状态有明确占位和说明。
- Integration — README 的启动步骤与页面路由与实际产物一致。

**Verification:**
- 原型既覆盖现有 IM，也清楚展示未来扩展空间，可直接用于重构评审。

## System-Wide Impact

- **Interaction graph:** 本轮仅新增独立原型模块，不接入现有业务运行时。
- **Error propagation:** 不涉及生产链路；交互失败以 mock 提示和空态呈现。
- **State lifecycle risks:** 主要风险是 mock 状态之间不一致，需要统一 store 管理。
- **API surface parity:** 不改变任何现有 API、客户端路由或部署配置。
- **Integration coverage:** 关键在跨页跳转、数据更新、主题切换和聊天状态连续性。
- **Unchanged invariants:** `app/`、`h5-app/`、`desktop/`、`admin/` 现有功能与构建流程保持不变。

## Risks & Dependencies

- 纯静态实现若页面太多，`app.js` 可能膨胀；需通过 route renderer 与模板函数分层。
- 若原型只做视觉不做流程，评审价值会下降；因此必须让关键动作可操作。
- 若设计 token 没有先收敛，后续页面会再次发散；因此先做规范页。

## Verification Strategy

- 本地直接打开 `im-ui-html/index.html` 进行 smoke。
- 如需本地 server，使用最轻方式（例如 `python3 -m http.server`）验证静态资源路径。
- 通过浏览器截图检查设计规范页、会话列表页、聊天详情页、联系人/建群页、扩展页的完整视觉。

## Post-Deploy Monitoring & Validation

No additional operational monitoring required — 本轮仅新增本地静态设计原型模块，不影响生产运行时。
