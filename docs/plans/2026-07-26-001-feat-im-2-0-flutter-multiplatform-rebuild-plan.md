---
title: "feat: 规划 RedCode IM 2.0 Flutter 多端重构"
type: feat
status: superseded
superseded_by: docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md
date: 2026-07-26
---

# feat: 规划 RedCode IM 2.0 Flutter 多端重构

## 目标

把 RedCode IM `2.0.0` 定义为一次完整的客户端重构：

- `app/` 成为唯一 Flutter 主线工程。
- 主线覆盖 Android、iOS、Windows 10+、macOS、Linux。
- `im-ui-html/` 成为 UI 设计源与评审基线。
- `app-win7/` 仅作为后置的 legacy 兼容线，不参与 2.0 第一阶段交付。
- 现有 `desktop/`、`android-app/`、`ios-app/` 不再作为 2.0 主线 UI 方案输入。

## 问题框架

当前仓库已经有可运行的 `app/`、`desktop/`、`admin/`、`api/` 等模块，但用户已经明确：

- `2.0.0` 要做全新 UI 重构，不沿用现有桌面端设计。
- 移动端和桌面端后续都使用 Flutter 实现。
- 主线不要拆成两个 Flutter 业务工程，而是单一 `app/` 多平台承载。
- Win7 需要兼容思路，但不能拖累主线架构与发布节奏。

这意味着 2.0 的首要问题已经不是“继续修补现有页面”，而是先把 **设计源、主线模块边界、共享层策略、交付顺序** 定下来，再进入正式实现。

## 已确认决策

- **单主线 Flutter 工程**：`app/` 同时承载移动端与桌面端，不新建 `app-desktop/`。
- **HTML 先行**：先在 `im-ui-html/` 完成设计系统和页面原型，再让 Flutter 落地。
- **移动端优先，桌面端第二阶段适配**：先收敛手机体验，再补宽屏/桌面壳层。
- **Win7 兼容线独立**：未来单独落成 `app-win7/`，锁旧 Flutter SDK，不和主线混编。
- **正式版发布优先**：后续默认发正式版本，不引入 preview/release candidate 分流。
- **GitHub Actions 继续单仓库多平台构建**：主线仍可通过平台分 runner 分别打包。

## 需求映射

- R1. `2.0.0` 要做全新 UI 重构，而不是局部修补。
- R2. 移动端与桌面端都以 Flutter 为正式实现技术栈。
- R3. 主线只保留一个 Flutter 工程 `app/`，不拆移动/桌面双工程。
- R4. Win7 兼容能力走独立 legacy 模块，不挤进主线。
- R5. 正式实现前，必须先通过 HTML 原型收敛设计系统和页面结构。
- R6. 原型既要覆盖现有 IM 主流程，也要为未来扩展能力预留空间。
- R7. 2.0 第一阶段尽量复用现有 API、WebSocket、上传、对象存储契约，不同时重做后端协议。
- R8. 需要保留多平台构建与发布能力，后续可接 GitHub Actions 正式版发布。
- R9. 设计和实现都要优先考虑移动端与桌面端共享，而不是复制两套 UI。
- R10. `desktop/` 现有实现可以忽略，不作为 2.0 架构约束。

## 范围

### 本计划覆盖

- `app/` 的 2.0 主线定位、目录切分和分阶段重构顺序。
- `im-ui-html/` 作为设计源的职责边界与后续设计阶段。
- 共享层的抽取策略与节奏。
- 多平台构建与 CI 的后续改造边界。
- `app-win7/` 的落位时机和进入条件。

### 本计划不覆盖

- 不在本轮直接实现 Flutter UI 重构代码。
- 不在本轮创建 `app-win7/` 实际代码骨架。
- 不在本轮重做 API 契约、数据库模型或部署拓扑。
- 不把现有 `desktop/` 迁移细节当成 2.0 的兼容目标。
- 不在本轮解决 Win7 具体插件兼容和旧 SDK 选型验证。

## 当前资产与约束

### 可直接复用的资产

- 现有 Flutter 主线：`app/`
  - 入口：`app/lib/main.dart`
  - 应用壳：`app/lib/app.dart`
  - 主 Tab 壳：`app/lib/features/home/home_shell_page.dart`
  - 主题/密度：`app/lib/core/theme/app_theme.dart`、`app/lib/core/theme/phone_density.dart`、`app/lib/core/theme/screen_adaptation.dart`
- 现有 HTML 原型：`im-ui-html/`
  - 说明：`im-ui-html/README.md`
  - 现有原型计划：`docs/plans/2026-07-25-001-feat-html-im-ui-prototype-plan.md`
- 现有 API 文档与契约：`docs/reference/api/`
- 现有发布工作流：`.github/workflows/release-artifacts.yml`
- 现有发布说明：`docs/reference/operations/github-actions-build.md`

### 关键约束

- 现有 `app/` 已包含较多业务逻辑、存储、服务与测试，不能用一次性推倒重来的方式硬切。
- 现有 `app/` 已存在真机 / 集成测试入口，2.0 需要保住这些验证能力，而不是重新发明测试体系。
- 共享层抽取必须服务于 2.0 落地速度，不能先做大规模“为抽而抽”的包拆分。

## 官方能力边界

已按 Flutter 官方当前文档确认：

- Flutter 主线可以在同一个工程中同时支持 Android、iOS、Windows、macOS、Linux。
- 桌面支持可在现有工程上补齐，不要求拆成新仓库或新主模块。
- 各平台构建命令与签名链路不同，但可以由同一仓库和同一工程分别产出。
- 当前 Flutter 主线不把 Win7 作为受支持桌面系统，因此 Win7 只能走独立 legacy 方案。

## 目标架构

```text
app/                          # Flutter 2.0 主线工程
  lib/
    bootstrap/                # 各平台入口、环境注入、启动装配
    shell/
      mobile/                 # 手机壳层：底部 Tab、全屏二级页、手势节奏
      desktop/                # 桌面壳层：侧栏、分栏、宽屏容器、窗口行为
    features/                 # 业务页面与交互
    platform/                 # 平台能力适配（文件、通知、窗口、快捷键等）
  test/
  integration_test/

im-ui-html/                   # 2.0 设计源 / 评审原型

packages/                     # 按需抽取的共享层
  im_ui_kit/                  # 先抽：tokens、组件、布局原语
  im_models/                  # 后抽：稳定的数据模型
  im_api/                     # 后抽：HTTP/WS 协议适配
  im_core/                    # 后抽：跨平台业务服务与状态逻辑

app-win7/                     # 最后进入：Win7 legacy 兼容线
```

## 关键技术决策

- **先拆壳层，再抽共享层**：先让 `app/` 具备 mobile shell / desktop shell 的边界，再决定哪些能力值得下沉到 `packages/`。
- **共享层先从 `im_ui_kit` 开始**：2.0 的第一阶段主要是 UI 重构，最先稳定的资产是 design tokens、组件原语和布局规则，而不是业务服务。
- **`im_models` / `im_api` / `im_core` 延后抽取**：等 UI 主流程稳定后，再把真正复用且边界清楚的领域对象和服务抽出来。
- **`app-win7/` 不提前入场**：只有主线在 Win10+/macOS/Linux 跑通后，才值得为 Win7 单独开一条兼容线。
- **CI 继续围绕单工程多目标构建**：不通过拆工程解决发布问题，而通过 workflow matrix / 多 runner 管理不同平台产物。

## 交付阶段

### 阶段 0：设计源收敛

目标：把 `im-ui-html/` 从“可看的原型”提升为“2.0 设计源”。

输出：

- 统一设计系统
- 页面地图
- 核心组件清单
- 移动端主流程原型
- 桌面宽屏适配原型
- Flutter 落地映射说明

完成标志：

- 用户可以先看 `#/spec` 再看业务页，不需要对照旧 UI 才理解 2.0 的设计语言。

### 阶段 1：`app/` 主线工程重组

目标：在不破坏现有 API 能力的前提下，让 `app/` 成为多平台 Flutter 主线。

输出：

- 平台入口与壳层分离
- 2.0 路由骨架
- `im_ui_kit` 初始落地
- 新旧页面可并行迁移的过渡结构

完成标志：

- `app/` 内部已经不再默认“只有手机端”。

### 阶段 2：移动端主流程重构

目标：按 2.0 设计源重做移动端核心 IM 页面。

输出：

- 登录、聊天、联系人、群、搜索、设置主流程
- 2K / 1.5K / 1K 密度一致性修正
- 动效、组件状态、空态、加载态统一

完成标志：

- 主要页面不再依赖旧 1.x 视觉与排版策略。

### 阶段 3：桌面壳层适配

目标：在同一 `app/` 中补齐桌面布局与交互。

输出：

- 桌面导航与分栏布局
- 宽屏聊天详情与侧栏规则
- 桌面文件/窗口/通知差异适配

完成标志：

- 桌面端不再只是移动界面拉伸，而是同设计语言下的桌面形态。

### 阶段 4：构建与发布链路切换

目标：让 2.0 主线重新具备稳定的多平台构建发布能力。

输出：

- `app/` 多平台构建矩阵
- Release artifact 命名与上传规则
- 平台签名/无签名产物说明

完成标志：

- 同一 `app/` 工程可以在 GitHub Actions 中分别产出目标平台 artifact。

### 阶段 5：Win7 legacy 评估与落线

目标：在主线稳定后，决定是否真的创建 `app-win7/`。

前置条件：

- `app/` 主线 UI、协议、构建链路稳定。
- 已确认 Win7 用户群体值得维护。
- 已完成旧 Flutter SDK 的最小兼容验证。

## 实施单元

### Unit 1：把 `im-ui-html/` 升级为 2.0 设计源

**目标：** 明确 2.0 的设计系统、页面地图和组件语义，让 Flutter 实现不再自己补产品定义。

**关联需求：** R1, R5, R6, R9

**依赖：** None

**文件：**
- Modify: `im-ui-html/index.html`
- Modify: `im-ui-html/assets/styles.css`
- Modify: `im-ui-html/assets/app.js`
- Modify: `im-ui-html/assets/mock-data.js`
- Modify: `im-ui-html/README.md`
- Create: `docs/plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md`

**测试文件 / 验证入口：**
- `im-ui-html/index.html`
- `im-ui-html/README.md`

**测试场景：**
- Happy path — `#/spec` 明确给出 2.0 tokens、组件、页面地图和密度策略。
- Happy path — 聊天 / 联系人 / 群 / 设置等路由可完整演示主流程。
- Edge case — 关闭网络或直接 `file://` 打开时，原型仍可用。

### Unit 2：重组 `app/` 的多平台入口与壳层边界

**目标：** 让 `app/` 先具备 mobile shell / desktop shell 分层，而不是直接在旧手机壳上叠桌面能力。

**关联需求：** R2, R3, R8, R9

**依赖：** Unit 1

**文件：**
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/app.dart`
- Create: `app/lib/bootstrap/main_mobile.dart`
- Create: `app/lib/bootstrap/main_desktop.dart`
- Create: `app/lib/shell/mobile/mobile_app_shell.dart`
- Create: `app/lib/shell/desktop/desktop_app_shell.dart`
- Create: `app/lib/platform/platform_capabilities.dart`

**测试文件 / 验证入口：**
- Create: `app/test/shell/mobile_app_shell_test.dart`
- Create: `app/test/shell/desktop_app_shell_test.dart`
- Modify: `app/test/smoke_test.dart`

**测试场景：**
- Happy path — 手机形态仍能进入主壳并加载核心导航。
- Happy path — 桌面形态可切入独立 shell，而不是直接复用旧手机壳布局。
- Edge case — 平台能力缺失时，桌面/移动壳层都有可降级兜底。

### Unit 3：先抽 `packages/im_ui_kit`

**目标：** 先稳定 2.0 的视觉语言和组件原语，而不是一开始就大规模拆业务。

**关联需求：** R1, R5, R9

**依赖：** Unit 1, Unit 2

**文件：**
- Create: `packages/im_ui_kit/pubspec.yaml`
- Create: `packages/im_ui_kit/lib/tokens/`
- Create: `packages/im_ui_kit/lib/components/`
- Create: `packages/im_ui_kit/lib/layout/`
- Modify: `app/lib/core/theme/app_theme.dart`
- Modify: `app/lib/core/theme/phone_density.dart`
- Modify: `app/lib/core/theme/screen_adaptation.dart`

**测试文件 / 验证入口：**
- Create: `packages/im_ui_kit/test/token_contract_test.dart`
- Create: `packages/im_ui_kit/test/component_smoke_test.dart`
- Modify: `app/test/core/phone_density_test.dart`
- Modify: `app/test/core/screen_adaptation_test.dart`

**测试场景：**
- Happy path — HTML 设计源里的颜色、圆角、间距、字号能在 Flutter token 层一一映射。
- Happy path — 输入框、按钮、卡片、列表项等基础组件可独立验证。
- Edge case — 1K / 1.5K / 2K 密度映射不会再次出现整体放大失真。

### Unit 4：按主流程重做 2.0 移动端页面

**目标：** 先拿下最核心的 IM 使用闭环，让 2.0 不是只有规范没有应用。

**关联需求：** R1, R2, R5, R6, R7

**依赖：** Unit 2, Unit 3

**文件：**
- Modify: `app/lib/features/auth/`
- Modify: `app/lib/features/home/`
- Modify: `app/lib/features/chat/`
- Modify: `app/lib/features/contacts/`
- Modify: `app/lib/features/settings/`

**测试文件 / 验证入口：**
- Modify: `app/test/features/login_page_test.dart`
- Modify: `app/test/chat/chat_input_widget_test.dart`
- Modify: `app/test/chat/chat_detail_page_runtime_test.dart`
- Modify: `app/test/chat/create_group_page_test.dart`
- Modify: `app/test/chat/message_search_page_test.dart`
- Modify: `app/test/features/add_friend_page_test.dart`
- Modify: `app/integration_test/smoke_test.dart`
- Modify: `app/integration_test/api_contract_flow_test.dart`

**测试场景：**
- Happy path — 登录后能完成聊天、联系人、建群、搜索、设置的主流程。
- Happy path — 图片、文件、语音、附件等现有协议能力不因 UI 重构而回退。
- Edge case — 空列表、失败态、权限缺失、长文本、多媒体消息都有统一表现。

### Unit 5：补齐桌面端适配与构建发布

**目标：** 在同一 `app/` 工程中完成桌面形态适配，并接回发布流水线。

**关联需求：** R2, R3, R8, R10

**依赖：** Unit 3, Unit 4

**文件：**
- Modify: `app/windows/`
- Modify: `app/macos/`
- Modify: `app/linux/`
- Modify: `app/scripts/build.sh`
- Modify: `app/scripts/README.md`
- Modify: `.github/workflows/release-artifacts.yml`
- Modify: `docs/reference/operations/github-actions-build.md`

**测试文件 / 验证入口：**
- Create: `app/test/shell/desktop_navigation_test.dart`
- Create: `app/test/chat/desktop_chat_layout_test.dart`
- Modify: `app/integration_test/smoke_test.dart`

**测试场景：**
- Happy path — Windows / macOS / Linux 各自产出目标构建物。
- Happy path — 桌面布局具备侧栏、宽屏聊天区和信息面板，不是简单放大手机布局。
- Edge case — 文件选择、通知、窗口尺寸变化有明确桌面兜底策略。

## 依赖与排序

1. 先完成 `im-ui-html/` 设计源收敛。
2. 再重组 `app/` 壳层和入口。
3. 再抽 `im_ui_kit`。
4. 再重做移动端主流程页面。
5. 最后做桌面适配与发布链路。
6. `app-win7/` 独立排在全部主线工作之后。

## 风险与防错

- **过早抽共享层**：会把 2.0 做成架构工程而不是产品重构。规避方式：先壳层、后 UI kit、再领域层。
- **桌面端过早入场**：会干扰手机端设计收敛。规避方式：设计先 mobile-first，桌面第二阶段进入。
- **直接复刻 1.x 页面结构**：会把旧布局问题原样带进 2.0。规避方式：以 `im-ui-html/` 设计源为唯一视觉基线。
- **Win7 过早绑定主线**：会锁死 Flutter 版本与插件选择。规避方式：legacy 独立、延后落线。

## 验证策略

- 设计阶段优先验证 `im-ui-html/` 的页面逻辑、密度、组件状态和信息架构。
- Flutter 实现阶段优先保住 `app/test/` 与 `app/integration_test/` 现有入口，并按新壳层补充测试。
- 发布阶段继续使用 GitHub Actions 的单仓库多 runner 模式，不通过拆仓或拆工程解决构建问题。

## 下一步

1. 按 `docs/plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md` 先推进 `im-ui-html/`。
2. 设计源稳定后，再进入 `app/` 的多平台壳层重组。
3. 主线稳定后，再决定是否正式创建 `app-win7/`。
