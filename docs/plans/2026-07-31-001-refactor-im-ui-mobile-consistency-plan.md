---
title: "refactor: 收敛 im-ui-html 移动端页面设计规范"
type: refactor
status: completed
date: 2026-07-31
origin: docs/plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md
---

# refactor: 收敛 im-ui-html 移动端页面设计规范

## 目标

基于 2026-07-31 的全页面审查，收敛 `im-ui-html/` 中仍沿用旧式说明卡、卡片嵌套或静态占位结构的移动端页面，使正式业务路由统一遵循现有 `runtime-screen`、设计 token、共享组件和产品文案规范。

完成后必须满足：

- 扫一扫、附近的人、游戏不再呈现为设计说明稿，而是可操作的产品页面。
- 添加好友不再依赖旧页面容器和卡片套卡片结构。
- 设置详情具备与页面主题对应的操作结构，不再只是静态值清单。
- `lab` 明确归属设计源内部工具，不与正式移动端产品信息架构混用。
- 演示数据与空数据场景、三种设备预览和直接业务深链均保持可用。
- 页面地图、组件清单和 Flutter handoff 与最终页面结构一致。

## 来源与问题框架

上游设计源计划已确定“设计系统先于页面”“业务页不承载评审说明”“移动端优先”和“Flutter 可映射”等原则（见 origin：`docs/plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md`）。本次审查确认核心 IM 页面已经基本统一，但以下页面仍存在规范漂移：

| 等级 | 页面 | 主要问题 |
| --- | --- | --- |
| P0 | `#/discover/scan` | 设计说明文案、英文评审标签、缺少扫描器标准操作和状态 |
| P0 | `#/discover/nearby` | 卡片套卡片、距离与标签重复、操作语义弱、列表结构不统一 |
| P0 | `#/discover/games` | 入口规划说明替代产品内容、缺少视觉资产和真实入口状态 |
| P1 | `#/contacts/add` | 旧页面结构、打招呼区域卡片嵌套、预览说明文案偏重 |
| P1 | `#/settings/:section` | 视觉基本统一，但只有静态值，页面完成度不足 |
| 条件性 | `#/lab`、`#/lab/:moduleId` | 适合作为内部评审工具，不适合进入正式产品信息架构 |

登录、聊天、联系人目录、好友申请、联系人资料、群聊、消息搜索、朋友圈、我的、设置主页、个人资料及各类空状态作为本轮基线，不进行无关重构。

## 范围

### 本计划覆盖

- 重构扫一扫、附近的人、游戏、添加好友页面。
- 完善账号与安全、聊天、隐私协议、关于四类设置详情。
- 必要时扩展现有语义 icon key、mock 数据和共享运行时组件。
- 明确实验模块与正式业务路由的边界。
- 同步 `README`、页面地图、组件清单和 Flutter handoff。
- 为演示数据、空数据、交互状态和多设备尺寸建立明确验收清单。

### 非目标

- 不接入真实相机、定位、游戏服务、账号设备管理或反馈 API。
- 不修改 API、Flutter、H5、iOS、Android 或 Desktop 模块。
- 不重新设计已经通过审查的核心页面和朋友圈页面。
- 不引入 Vue、React、bundler、npm 包或新的 UI 框架。
- 不把 `lab` 的实验能力实现为正式业务功能。
- 不以此次视觉收敛为理由重写 hash router 或全局状态管理。

## 设计与技术决策

### 1. 正式业务页统一使用运行时结构

- 目标页面迁移到 `screen runtime-screen`、共享 `App Bar`、`runtime-scroll` 和稳定内容边界。
- 正式业务页不显示 eyebrow、英文状态 badge、实现说明、后续规划或组件设计解释。
- 页面层级优先由背景、实色 Surface、间距和弱分隔建立，不使用常驻描边堆叠层级。
- 禁止卡片套卡片；确需独立决策的重复项才使用单项卡片，否则使用连续列表或设置组。

### 2. 先复用现有原语，再增加页面专用组件

- 返回、搜索、筛选、相册、手电筒等操作优先通过 `renderIcon()` 的语义 key 输出。
- 列表优先复用 `Conversation Cell`、头像、状态、尾部元信息的密度节奏。
- 新组件只有在扫一扫扫描视口、附近筛选栏和游戏内容单元确有独立结构时才增加。
- 不为了消除少量模板重复引入新的 JS 抽象层。

### 3. 静态原型也必须表达完整状态

- 不调用真实设备能力，但要可演示权限前、扫描中、识别成功、识别失败等状态。
- 附近的人要表达定位状态、筛选结果、加载结束与空结果。
- 游戏页要表达最近玩过、可进入、维护中或暂无内容等产品状态。
- 设置详情中的动作使用本地 mock 状态或 Toast 闭环，不伪装成已接入后端。

### 4. `lab` 归入设计源内部工具

- `lab` 保留英文模块名和实验状态的前提，是它只能作为设计源内部入口存在。
- `lab` 不进入移动端正式推荐评审路径、底部导航或 Flutter 正式 route 映射。
- 若未来决定正式产品化某个模块，需单独建立产品需求与页面计划，不直接复用实验说明页。

## 影响区域

### 主要实现

- `im-ui-html/assets/app.js`
- `im-ui-html/assets/styles.css`
- `im-ui-html/assets/mock-data.js`

### 文档与验收入口

- `im-ui-html/index.html`
- `im-ui-html/README.md`
- `im-ui-html/docs/design-tokens.md`
- `im-ui-html/docs/component-inventory.md`
- `im-ui-html/docs/page-map.md`
- `im-ui-html/docs/flutter-handoff.md`

当前模块没有自动化测试工具链。本计划保持纯静态技术约束，以 `im-ui-html/index.html` 为测试入口，通过路由深链、交互检查和多设备截图完成验收；如执行阶段发现重复回归无法靠人工稳定覆盖，再另行评估无依赖的静态契约检查，不在本次预先引入测试框架。

## 阶段拆分

### 阶段 1：收敛发现页

目标：优先清除三个最明显的设计说明页，让发现首页的入口都能进入完成度一致的产品页面。

#### 单元 1.1：扫一扫

- 路由：`#/discover/scan`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`
- 实现方向：
  - 使用紧凑二级页导航和全宽扫描工作区，不再把扫描框包在说明卡中。
  - 扫描视口提供稳定宽高比、四角定位标记和扫描线，不因提示文字改变尺寸。
  - 在底部工具区提供相册与手电筒 icon 操作，并提供清晰的可访问名称。
  - 用 mock 状态演示权限提示、扫描中、识别成功和无法识别；结果通过设备内 sheet 或结果面层承接。
  - 删除 `Scan Gateway`、`Quick Action`、后续规划和能力清单。
- 验收场景：
  1. 直接打开深链时，返回操作留在移动端预览壳内。
  2. 扫描区域在三种设备尺寸下均居中、完整且不溢出。
  3. 相册、手电筒、结果关闭操作有稳定热区，不发生文案或 icon 断行。
  4. 空数据模式不改变静态扫描能力入口。

#### 单元 1.2：附近的人

- 路由：`#/discover/nearby`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`、`im-ui-html/assets/mock-data.js`
- 实现方向：
  - 页面顶部使用位置状态与紧凑筛选控件，筛选项覆盖距离、在线状态或排序中的必要维度。
  - 人员结果改为连续列表；每行只保留头像、姓名、身份摘要、在线状态和一处距离信息。
  - 删除重复的“附近的人”chip 和含义模糊的“看看”按钮，整行进入资料或使用明确的“打招呼”动作。
  - 增加较长摘要、不同距离、不同在线状态和空结果数据，验证排版边界。
- 验收场景：
  1. 列表中不存在卡片套卡片及重复距离。
  2. 长姓名、长摘要和两位数距离不会挤压操作区。
  3. 筛选切换后结果和空状态均在当前页面完成反馈。
  4. 点击人员可进入联系人资料，并能按来源正确返回。

#### 单元 1.3：游戏

- 路由：`#/discover/games`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`、`im-ui-html/assets/mock-data.js`，必要时新增 `im-ui-html/assets/images/games/` 下的本地位图资源
- 实现方向：
  - 使用“最近玩过 + 全部游戏”或等价的产品内容结构，替换入口规划说明。
  - 每个游戏单元提供可识别的封面或图标、名称、类型、状态和明确进入动作。
  - 游戏资源必须是本地可审查资产，不依赖远程图片；避免用纯渐变或空白占位冒充封面。
  - 对不可用内容展示“维护中”等真实状态，不再使用“入口”badge。
- 验收场景：
  1. 页面首屏具有可识别内容，不出现大面积无意义空白。
  2. 最长名称和状态标签在三种设备下不纵向拆字。
  3. 可用、维护中、空数据三种状态层级清晰。
  4. 点击可用项有可见反馈，且不导航到未注册路由。

阶段 1 完成后先进入一次独立设计 review，再继续修改 P1 页面，避免三个页面在结构上各自形成新风格。

### 阶段 2：收敛任务页与设置详情

#### 单元 2.1：添加好友

- 路由：`#/contacts/add`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`
- 实现方向：
  - 迁移到与群创建、消息搜索一致的运行时任务页结构。
  - 保留现有搜索结果作为视觉基线，统一搜索、结果、状态和操作的内容线。
  - “打招呼内容”改为表单字段或无嵌套的连续设置行；删除“当前预览”“添加时会携带”等设计说明。
  - 明确未搜索、搜索中、无结果、可申请、已申请、已是好友等状态。
- 验收场景：
  1. 输入、清空、搜索和结果操作形成完整闭环。
  2. 长用户名、长身份说明和长招呼语不溢出。
  3. 页面不存在旧 `hero-card` 或卡片嵌套。
  4. 空数据模式可显示合理的无结果状态。

#### 单元 2.2：设置详情

- 路由：`#/settings/account`、`#/settings/chat`、`#/settings/privacy`、`#/settings/about`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`、`im-ui-html/assets/mock-data.js`
- 实现方向：
  - 保留共享 `Settings Row` 与现有导航结构，不为每个详情页重新发明容器。
  - 账号与安全：组织手机号、登录设备、账号状态及可执行的设备管理入口。
  - 聊天：承载聊天背景、自动下载媒体、消息保留策略等开关或选项。
  - 隐私协议：分离隐私偏好和协议/数据使用文档入口，避免把协议页面做成开关集合。
  - 关于：展示版本、协议、反馈和必要的产品信息；反馈动作以 mock Toast 或本地 sheet 闭环。
  - 对尚未接后端的能力使用明确状态，不展示虚假的成功结果。
- 验收场景：
  1. 四个页面之间共享标题、分组、行高、分隔和尾部操作规范。
  2. 开关、链接、静态值的视觉语义可以明确区分。
  3. 每个详情页至少存在与主题对应的有效操作或内容入口。
  4. 所有操作在刷新、返回或 Toast 反馈方面符合 mock 状态约定。

阶段 2 完成后复查所有核心基线页，确认共享 CSS 调整没有造成聊天、联系人、群聊、朋友圈和设置主页回归。

### 阶段 3：边界与交付文档

#### 单元 3.1：明确实验模块边界

- 路由：`#/lab`、`#/lab/:moduleId`
- 涉及文件：`im-ui-html/assets/app.js`、`im-ui-html/README.md`、`im-ui-html/docs/page-map.md`、`im-ui-html/docs/flutter-handoff.md`
- 实现方向：
  - 保留实验页现有评审属性，但增加清晰的“设计源内部”归属，不伪装成正式 App 页面。
  - 从正式移动端业务地图和 Flutter route 映射中分离，不通过底部导航或正式发现入口访问。
  - 保证直接深链仍可用于内部评审。
- 验收场景：
  1. 正式移动端推荐路径不会进入 `lab`。
  2. 内部深链仍能打开模块总览和详情。
  3. 文档不会再把实验页与正式产品页面并列描述。

#### 单元 3.2：同步设计契约

- 涉及文件：`im-ui-html/README.md`、`im-ui-html/docs/design-tokens.md`、`im-ui-html/docs/component-inventory.md`、`im-ui-html/docs/page-map.md`、`im-ui-html/docs/flutter-handoff.md`
- 实现方向：
  - 补充扫描工作区、附近人员行、游戏内容单元和设置详情状态。
  - 更新发现链路与推荐评审顺序。
  - 记录哪些组件进入正式 Flutter 映射，哪些只属于 HTML 设计源。
  - 删除与最终页面不一致的旧结构描述。
- 验收场景：
  1. route、组件名称、状态和页面截图可一一对应。
  2. Flutter 实施者无需参考旧页面即可理解目标结构。
  3. `README`、页面地图、组件清单和 handoff 不相互矛盾。

## 建议执行与提交顺序

每个提交必须形成可独立预览和验证的业务闭环，建议拆分为：

1. `refactor: 重构扫一扫交互页面`
2. `refactor: 收敛附近的人列表规范`
3. `refactor: 完善游戏入口页面`
4. `refactor: 统一添加好友任务页`
5. `feat: 完善设置详情交互`
6. `docs: 同步移动端页面设计契约`

实验模块边界调整可与第 6 个文档提交合并；如果需要修改运行时导航或路由行为，则单独提交。

## 验证方式

### 静态与代码检查

- `git diff --check`
- `git diff --cached --check`
- 浏览器 Console 无新增 error 或未注册路由错误。
- 所有新增图片使用仓库内相对路径，断网时仍可加载。

### 路由验收

逐一检查演示数据和空数据：

- `#/mobile-design/discover/scan`
- `#/mobile-design/discover/nearby`
- `#/mobile-design/discover/games`
- `#/mobile-design/contacts/add`
- `#/mobile-design/settings/account`
- `#/mobile-design/settings/chat`
- `#/mobile-design/settings/privacy`
- `#/mobile-design/settings/about`
- `#/mobile-design/empty/discover/nearby`
- `#/mobile-design/empty/discover/games`
- `#/mobile-design/empty/contacts/add`

### 设备与视觉验收

- iPhone 12 Pro：默认密度与主要评审基线。
- iPhone 16 Pro Max：Dynamic Island、Home Indicator 和安全区。
- Pixel 8 Pro：Android 比例、底部安全区和长屏内容分布。
- 检查 390px 级窄屏下的长文案、badge、按钮与 icon 对齐。
- 检查页面切换、sheet、筛选、空态和 Toast 不超出设备裁切层。
- 截图对比核心基线页，确保共享样式没有产生视觉回归。

### 回归页面

- `#/mobile-design/chats`
- `#/mobile-design/chat/c_room_launch`
- `#/mobile-design/contacts`
- `#/mobile-design/contacts/requests`
- `#/mobile-design/groups`
- `#/mobile-design/groups/create`
- `#/mobile-design/groups/settings/g_launch`
- `#/mobile-design/discover`
- `#/mobile-design/discover/moments`
- `#/mobile-design/mine`
- `#/mobile-design/settings`

## 完成标准

- P0、P1 页面不再出现设计说明文案、英文评审标签或卡片套卡片。
- 所有正式业务页均使用统一运行时壳层和共享视觉 token。
- 新增交互具备默认、按下、禁用、空数据及必要错误状态。
- 三种设备预览无文字断裂、icon 错位、内容溢出或底部遮挡。
- 业务深链、来源返回和空数据前缀均正确保留。
- 文档与实现同步，且 `lab` 的内部工具边界清晰。
- 相关改动按最小业务闭环完成 review、commit 和 push。

## 风险与待审核决策

1. **游戏内容定位**：本计划默认采用“最近玩过 + 全部游戏”的轻量目录，不设计真实游戏大厅或排行榜。
2. **扫一扫能力边界**：本计划只表达相机扫描器的产品状态，不申请真实权限、不调用摄像头。
3. **附近的人主操作**：本计划建议整行进入资料，并保留明确“打招呼”动作；执行前可由设计审核决定是否只保留其中一种。
4. **隐私协议归属**：当前路由同时承载隐私偏好和协议说明，实施时应在同一路由内分组，暂不新增更多路由。
5. **实验模块保留方式**：默认保留内部深链并从正式 IA 分离；若审核决定完全移除，再单独处理路由兼容和文档引用。

## 沉淀跟进

任务完成后，仅在以下内容形成稳定复用价值时新增 `docs/solutions/`：

- 纯静态设计源如何区分正式产品页与内部评审页。
- 多设备预览下避免卡片嵌套、说明文案泄漏和安全区回归的检查方法。

普通页面调整记录不进入方案库，由本计划、Git 历史和设计源附属文档承载。
