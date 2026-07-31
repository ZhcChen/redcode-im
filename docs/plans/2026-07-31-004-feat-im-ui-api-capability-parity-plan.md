---
title: "feat: 补齐 IM HTML 设计源相对 API 缺失的界面能力"
date: 2026-07-31
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
---

# feat: 补齐 IM HTML 设计源相对 API 缺失的界面能力

## Goal Capsule

- **目标：** 让 `im-ui-html` 完整表达 API 已有的用户侧能力，为后续 Flutter 落地提供可点击、可评审、可追踪的设计依据。
- **范围：** 仅修改 `im-ui-html/` 静态设计源及其附属文档，不修改 Flutter、API、Admin 或数据库。
- **事实来源：** API 能力以 `api/src/routes.rs` 和对应 handler 契约为准；现有设计语言以 `im-ui-html/assets/styles.css`、`im-ui-html/docs/design-tokens.md` 和已稳定页面为准。
- **执行方式：** 按消息、会话、联系人、群治理、内容与账号六个独立页面闭环推进，每个闭环包含路由、页面、状态、mock 数据和文档。
- **停止条件：** 若实现中发现接口只存在路由但运行时不可用，或 UI 所需状态无法从当前 API 契约得到，不在原型中假装成功，转为显式待确认项。
- **后续归属：** Flutter/API 联调由 `docs/plans/2026-07-31-003-feat-api-ui-capability-parity-plan.md` 承接，不计入本计划完成标准。

---

## Product Contract

### Summary

当前 `im-ui-html` 已覆盖登录、会话列表、聊天、联系人、群目录、基础群设置、搜索和设置，但对 API 已实现的深层操作表达不足。
主要问题不是缺少首页，而是缺少消息管理、归档恢复、危险操作、角色化群治理、贴纸管理、举报反馈、资料维护和版本状态等可执行界面。

本计划把这些能力补成正式设计源页面，不接真实请求，但所有交互和状态必须能映射到现有 API。

### Problem Frame

- API 已提供完整操作，HTML 设计源只有文字、Toast 或基础入口，Flutter 后续无法从设计源确定页面结构和状态。
- 部分操作只存在于隐含长按菜单或设置底部 Sheet，缺少独立深链，无法稳定截图和评审。
- 群设置把多类治理能力压在一个页面中，未表达群主、管理员、普通成员之间的权限差异。
- 原型中的部分功能属于 API 尚未实现的未来能力，容易与“API 已有但 UI 缺失”混为一谈。

### Actors

- A1. 普通用户：管理自己的消息、会话、好友、贴纸、资料和反馈。
- A2. 群普通成员：查看规则、成员和自己的禁言状态，可退出群聊。
- A3. 群管理员：审核申请、管理成员和禁言，但不能执行群主专属操作。
- A4. 群主：任命管理员、转让群主、解散群聊及执行完整治理操作。
- A5. 设计评审者：通过固定深链和确定性 mock 状态检查页面完整性与一致性。

### Requirements

**消息与会话**

- R1. 聊天消息必须提供符合消息归属和类型的操作菜单，覆盖转发、引用、编辑、删除、置顶、取消置顶和 reaction。
- R2. 自己发送的消息必须能进入已读详情，展示已读/未读成员、计数、长名单和空态。
- R3. 编辑、删除、清空聊天记录等不可逆或高影响操作必须有明确确认状态、处理中状态、成功反馈和失败恢复。
- R4. 会话列表必须提供置顶/取消置顶、通知静音/恢复和归档操作，并在归档成功后提供可撤销恢复入口；当前 API 没有归档会话列表查询，因此不得设计成可长期浏览和恢复的归档中心。
- R5. `relay_only` 等能力受限状态应在相关操作中表达不可用原因，但不在本计划设计运行模式开关本身。

**联系人与安全操作**

- R6. 联系人资料页必须补齐修改备注、删除好友和发起举报，危险操作与普通信息分区。
- R7. 举报页面必须覆盖举报对象、原因、补充说明、至少一张截图、提交中、成功和失败状态；原因与补充说明按明确格式合并到 API 的 `content` 字段。
- R8. 删除好友后必须表达联系人列表、资料页和已有私聊之间的状态变化，不假设删除历史消息。

**群治理**

- R9. 群设置必须按信息架构拆出群资料、成员、管理员、入群申请、邀请成员、群规则、禁言管理和操作日志；群资料覆盖群头像、群名称、描述和公告的查看与可编辑状态。
- R10. 所有群治理页面必须提供群主、管理员、普通成员三种确定性角色预览，隐藏或禁用无权限操作并说明原因。
- R11. 群成员管理必须覆盖添加、移除、搜索、角色标识、长名单和成员资料入口。
- R12. 入群申请必须覆盖待处理、已同意和已拒绝状态；邀请能力覆盖邀请成员的目标选择、创建结果，以及已知邀请 ID 的待响应、已接受、已拒绝和已过期状态，不提供 API 无法支撑的邀请列表。
- R13. 禁言管理必须覆盖全员禁言、单成员禁言、时长选择、解除禁言和当前用户被禁言状态。
- R14. 群规则必须覆盖列表、创建、编辑、删除、排序展示和空态。
- R15. 转让群主、退出群聊和解散群聊必须使用独立确认流程，明确结果和不可撤销影响。

**内容、账号与支持**

- R16. 贴纸管理必须覆盖可用贴纸包、搜索、我的贴纸包、套装详情、添加、移除、下载/加载和错误状态。
- R17. 体验反馈必须从简化 Sheet 升级为正式页面，覆盖分类、正文、联系方式可选项、提交状态和成功结果；分类作为客户端预设前缀合并进 API 的 `content` 字段。
- R18. 个人资料必须表达头像上传、昵称和个性签名编辑，以及上传中、裁剪/预览、失败和保存状态。
- R19. 账号与安全必须补齐修改密码和注销账号；SMS 登录、短信重置密码、更换手机号不在本轮完善。
- R20. 关于页面必须补齐版本检查、可选更新、强制更新、下载进度、失败重试和热更新状态。
- R21. 所有新增页面必须同时具备 demo、空态或异常态的稳定预览入口，并纳入移动端设计源页面地图。
- R22. 页面文案必须描述用户当前状态和可执行动作，不使用“这里展示了什么功能”一类设计说明文案。

### Key Flows

- F1. 消息管理
  - **Trigger:** 用户长按一条消息。
  - **Steps:** 操作菜单按消息归属显示动作 -> 用户选择动作 -> 进入确认、选择器或详情状态 -> 显示结果并保持聊天上下文。
  - **Outcome:** R1-R3 可在同一聊天深链连续演示。

- F2. 会话归档与撤销
  - **Trigger:** 用户在会话列表侧滑或打开会话菜单。
  - **Steps:** 归档会话 -> 会话从主列表移除 -> 显示带“撤销”的结果提示 -> 撤销后调用指定会话恢复能力并回到原位置。
  - **Outcome:** R4-R5 有完整状态连续性。

- F3. 联系人删除与举报
  - **Trigger:** 用户从联系人资料页进入更多操作。
  - **Steps:** 修改备注、删除好友或举报 -> 完成表单/确认 -> 返回资料页或联系人列表 -> 状态按操作结果变化。
  - **Outcome:** R6-R8 不依赖 Toast 假装完成。

- F4. 群治理
  - **Trigger:** 不同角色进入群设置。
  - **Steps:** 根据角色进入治理子页 -> 查看或执行操作 -> 确认高风险动作 -> 返回时保留变更后的 mock 状态。
  - **Outcome:** R9-R15 可按角色单独评审。

- F5. 贴纸、反馈与账号维护
  - **Trigger:** 用户从聊天加号面板、我的页面或设置页进入功能。
  - **Steps:** 浏览/编辑内容 -> 触发提交或下载 -> 展示处理中、成功或失败 -> 返回来源页面。
  - **Outcome:** R16-R20 形成独立、可重复的设计链路。

### Acceptance Examples

- AE1. 给定一条自己发送且部分成员未读的群消息，长按后应显示编辑、删除、转发、置顶等适用动作；进入已读详情后可分别查看已读和未读成员。
- AE2. 给定一条他人消息，菜单不得显示编辑；选择 reaction 后消息下方计数和当前用户选中态同步变化。
- AE3. 给定用户归档一个会话，成功提示在有效时间内提供“撤销”；撤销后该会话回到主列表，提示消失后不再展示无法由 API 查询的数据。
- AE4. 给定普通群成员进入管理员页面，只能查看管理员列表，不显示任命和移除操作。
- AE5. 给定群管理员审核申请，可以同意或拒绝，但不能看到转让群主和解散群聊动作。
- AE6. 给定贴纸包下载失败，页面保留包详情和重试入口，不显示已添加状态。
- AE7. 给定反馈提交失败，用户输入内容保持不丢失；重试成功后进入成功结果页。
- AE8. 给定检测到强制更新，关闭操作不可用，页面只提供下载/重试和进度状态。

### Scope Boundaries

**本计划内**

- `im-ui-html/index.html`
- `im-ui-html/assets/app.js`
- `im-ui-html/assets/mock-data.js`
- `im-ui-html/assets/styles.css`
- `im-ui-html/README.md`
- `im-ui-html/docs/page-map.md`
- `im-ui-html/docs/component-inventory.md`
- `im-ui-html/docs/flutter-handoff.md`

**明确排除**

- Flutter 页面、service、provider 和测试。
- API 路由、handler、数据库、WebSocket 或 Admin 修改。
- SMS 登录和短信重置密码页面。
- 登录设备管理、更换手机号、消息保留策略等当前 API 不完整的操作页。
- 朋友圈、音视频通话、扫一扫、附近的人、游戏的后端对齐。
- 联系人名片、收藏内容的服务端结构化消息能力。
- HTML 原型真实请求 API 或模拟真实安全能力。

---

## Planning Contract

### Key Technical Decisions

- KTD1. **设计源先表达 API 契约，不复制 API 数据结构。** Mock 数据只保留页面需要的字段，文档记录对应路由，避免静态原型被误用为客户端模型定义。
- KTD2. **深层能力使用独立 hash route。** 需要稳定截图、返回导航或多状态评审的功能不得只放在临时 Toast 或不可寻址 Sheet 中。
- KTD3. **轻操作留在上下文菜单，复杂操作进入页面。** Reaction、引用、置顶等留在消息上下文；已读详情、转发选择、举报、群治理、贴纸管理和反馈使用独立页面。
- KTD4. **群治理按角色驱动同一套页面。** 不复制三套群设置，通过 mock 角色和权限矩阵控制动作显隐，减少设计分叉。
- KTD5. **危险操作使用统一确认组件。** 删除消息、清空聊天、删除好友、移除成员、退出群、转让和解散共享一致的标题、影响说明、主次按钮和处理中状态。
- KTD6. **状态由确定性 mock 数据驱动。** Demo、empty、error、loading、role 等预览必须能通过固定路由或预览控制切换，禁止依赖随机数据或一次性内存操作才能复现。
- KTD7. **沿用现有移动端视觉基线。** 新页面复用 `runtime-screen`、`renderScreenHeader`、列表分组、底部 Sheet、按钮和现有 token，不创建另一套卡片或导航风格。
- KTD8. **桌面端只保证现有设计源容器可评审。** 本轮优先移动端页面完整性，不新建独立 PC 信息架构；宽屏不得溢出或破坏现有预览框架。

### Route Design

建议新增以下设计源深链，命名保持资源层级清晰：

| 页面组 | 建议路由 |
| --- | --- |
| 消息详情 | `#/chat/:chatId/message/:messageId/reads`、`#/chat/:chatId/forward/:messageId` |
| 联系人操作 | `#/contacts/profile/:contactId/report` |
| 群成员与角色 | `#/groups/:groupId/members`、`#/groups/:groupId/admins` |
| 群申请与邀请 | `#/groups/:groupId/join-requests`、`#/groups/:groupId/invite`、`#/groups/:groupId/invitations/:invitationId` |
| 群规则与禁言 | `#/groups/:groupId/rules`、`#/groups/:groupId/mutes` |
| 群日志 | `#/groups/:groupId/operation-logs` |
| 贴纸 | `#/stickers`、`#/stickers/store`、`#/stickers/packs/:packId` |
| 举报反馈 | `#/reports/new`、`#/settings/feedback` |
| 资料账号 | `#/settings/profile/edit`、`#/settings/password`、`#/settings/deactivate` |
| 版本更新 | `#/settings/version` |

具体路由可在实现时根据现有 `parseRoute()` 保持一致，但不得把多个独立页面重新压回一个不可寻址 Sheet。

### API Traceability

| UI 能力 | API 依据 |
| --- | --- |
| 归档/撤销恢复会话 | `DELETE /chats/{room_id}`、`POST /chats/{room_id}/restore`；当前没有归档列表查询 |
| 会话置顶/通知 | `POST/DELETE /rooms/{room_id}/pin`、`POST /rooms/{room_id}/notification-settings` |
| 消息转发/编辑/删除/置顶 | `/rooms/{room_id}/messages/forward`、`PATCH/DELETE /rooms/{room_id}/messages/{message_id}`、`POST/DELETE .../pin` |
| Reaction/已读详情 | `GET/POST/DELETE .../reactions`、`GET .../reads` |
| 删除好友/备注 | `DELETE /friends/{friend_user_id}`、`PATCH /friends/{friend_user_id}/remark` |
| 举报/附件 | `POST /reports`、`POST /reports/attachments/signature`、`POST /reports/attachments/commit`；仅支持用户/群聊目标且至少一张截图 |
| 群成员/资料/头像/退出/转让/解散 | `/rooms/{room_id}`、`/rooms/{room_id}/avatar/*`、`/members`、`/leave`、`/transfer` |
| 群申请/邀请/管理员 | `/join-requests`、`/invitations`、`/admins`；邀请只支持创建和按 ID 响应，没有列表查询 |
| 群禁言/规则/日志 | `/mutes`、`/rules`、`/operation-logs` |
| 贴纸包 | `/emoji-packs/available`、`/search`、`/my`、`/{pack_id}/add`、`/{pack_id}/remove` |
| 反馈 | `POST /feedbacks`；请求字段仅为 `content` 和可选 `contact` |
| 个人资料/头像/密码/注销 | `PATCH/DELETE /users/me`、`POST /users/me/password`、`/users/me/avatar/*` |
| 版本与热更新 | `/versions/latest`、`/versions/hot-update`、对应下载与事件上报接口 |

### Sequence

1. 先建立路由、通用状态组件和页面地图，固定后续页面入口。
2. 完成消息与会话闭环，作为菜单、确认、列表状态的复用基线。
3. 完成联系人和举报，验证表单、附件与危险操作模式。
4. 完成群治理页面族，复用前述列表、确认和角色状态。
5. 完成贴纸、反馈、资料、账号和版本页面。
6. 最后执行全路由、空态、异常态、移动/宽屏和文档一致性审查。

---

## Implementation Units

### U1. 路由与通用交互基座

- **Goal:** 为新增深层页面建立可寻址路由、返回策略、预览状态和复用组件。
- **Requirements:** R3、R10、R15、R21、R22。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/styles.css`、`im-ui-html/assets/mock-data.js`、`im-ui-html/docs/component-inventory.md`。
- **Approach:** 扩展 `parseRoute()` / `renderRoute()`；增加统一操作菜单、确认对话框、提交状态、错误提示、角色标识和空态；复用现有 icon/token。
- **Test Scenarios:** 每个新增深链可直接打开和刷新；返回路径稳定；无效 ID 进入明确 fallback；长标题和错误文案不溢出；dialog 支持遮罩关闭策略和键盘焦点语义。
- **Verification:** 静态语法检查、全深链遍历、移动与宽屏截图。

### U2. 消息操作与已读详情

- **Goal:** 补齐消息上下文菜单、转发选择、编辑/删除/置顶/reaction 和已读详情。
- **Requirements:** R1-R3、R5、R21。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用聊天详情、联系人选择器、reaction row 和现有消息状态样式。
- **Test Scenarios:** 自己/他人消息动作不同；文本与附件动作不同；编辑后状态可见；删除确认可取消；转发支持搜索和多选；已读 0 人、部分已读、全部已读和长名单；`relay_only` 禁用依赖历史的动作。
- **Verification:** 从 `#/chat/:chatId` 连续走通所有动作；独立打开已读/转发深链；检查状态回写到聊天 mock。

### U3. 会话归档与撤销恢复

- **Goal:** 补齐会话置顶、通知静音、归档入口和归档后的限时撤销恢复流程，不虚构归档列表能力。
- **Requirements:** R4、R5、R21。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用会话列表和现有 Toast/结果提示，通过侧滑或会话菜单提供动作，在提示中增加明确的撤销命令，不新增归档列表页面。
- **Test Scenarios:** 置顶/取消置顶后排序同步；静音/恢复后状态同步；普通会话归档；置顶会话归档；撤销后恢复原位置；归档失败后原位置保持；撤销失败后给出重试；提示超时后不再展示恢复入口。
- **Verification:** 主列表中的置顶、静音、归档、撤销、失败和超时状态连续，页面不出现 API 无数据来源的归档列表入口。

### U4. 联系人备注、删除与举报

- **Goal:** 将联系人资料页补成完整关系管理入口，并提供正式举报流程。
- **Requirements:** R6-R8、R21-R22。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用联系人资料页、设置表单和危险操作确认组件。
- **Test Scenarios:** 备注编辑为空/超长/保存成功；删除好友取消/确认/失败；举报原因选择、长说明、缺少截图校验、1/多张截图、上传中、提交失败和成功；删除后已有会话仍可见但关系标识变化。
- **Verification:** 从资料页进入所有流程并正确返回；举报深链可独立评审。

### U5. 群成员、管理员与群生命周期

- **Goal:** 补齐群资料编辑、成员列表、角色管理、退出、转让和解散页面状态。
- **Requirements:** R9-R11、R15、R21。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用群目录成员列表、联系人选择器和统一确认组件。
- **Test Scenarios:** 群头像预览/上传失败；群名称、描述和公告编辑；普通成员只读；长成员列表搜索；群主任命/移除管理员；管理员移除普通成员；不能移除群主；转让目标选择；退出和解散的不同影响文案；处理失败后保留当前页。
- **Verification:** owner/admin/member 三种角色深链截图，动作矩阵与 API 权限一致。

### U6. 群申请、邀请、规则、禁言与日志

- **Goal:** 完成剩余群治理页面族及角色状态。
- **Requirements:** R9-R10、R12-R14、R21。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用分段筛选、状态标签、列表行、表单和时间线样式。
- **Test Scenarios:** 申请待处理/通过/拒绝；邀请成员搜索、多选和创建结果；通过已知邀请 ID 展示待响应/接受/拒绝/过期；不存在邀请列表入口；规则增改删和空态；全员禁言开关；单人定时禁言和解除；当前用户被禁言；日志按操作人/类型筛选；普通成员无写权限。
- **Verification:** 各子页固定路由可打开，角色切换后操作显隐和状态说明正确。

### U7. 贴纸中心与聊天入口

- **Goal:** 补齐贴纸商店、我的贴纸、套装详情及聊天选择面板映射。
- **Requirements:** R16、R21-R22。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`、`im-ui-html/docs/component-inventory.md`。
- **Patterns:** 复用现有表情面板切换动画和设置列表，不创建嵌套卡片。
- **Test Scenarios:** 可用/我的/搜索结果；添加和移除；套装多包；下载中、下载失败、空搜索；聊天面板显示已添加贴纸并保持面板高度过渡。
- **Verification:** 从聊天和设置两个入口进入同一贴纸状态，返回路径分别正确。

### U8. 反馈、资料与账号操作

- **Goal:** 把设置中的简化操作升级为正式反馈、资料编辑、修改密码和注销账号页面。
- **Requirements:** R17-R19、R21-R22。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用现有设置分组、表单字段、头像和确认组件。
- **Test Scenarios:** 反馈分类和长正文；失败保留输入；头像选择/预览/上传失败；资料未修改禁用保存；密码校验错误；注销二次确认、处理中和失败；页面不出现 SMS 重置或短信登录入口。
- **Verification:** 所有表单具备默认、聚焦、校验、提交中、失败、成功状态，键盘弹出时主操作可达。

### U9. 版本与热更新状态

- **Goal:** 将版本信息 Sheet 升级为覆盖真实版本 API 状态的页面。
- **Requirements:** R20-R22。
- **Files:** `im-ui-html/assets/app.js`、`im-ui-html/assets/mock-data.js`、`im-ui-html/assets/styles.css`、`im-ui-html/docs/page-map.md`。
- **Patterns:** 复用关于页产品标识和进度组件，保持设置页安静、工具化的视觉风格。
- **Test Scenarios:** 已是最新；发现可选更新；强制更新；下载 0/50/100%；下载失败重试；热更新可用、应用中、成功和回滚提示。
- **Verification:** 每个版本状态有固定预览数据，强制更新状态无误导性关闭入口。

### U10. 页面地图、交付说明与全量审查

- **Goal:** 让设计文档、路由和页面实现保持一致，并形成 Flutter 可消费的交付说明。
- **Requirements:** R21-R22 及全部功能要求。
- **Files:** `im-ui-html/README.md`、`im-ui-html/docs/page-map.md`、`im-ui-html/docs/component-inventory.md`、`im-ui-html/docs/flutter-handoff.md`、必要的 HTML/JS/CSS 修正。
- **Approach:** 更新页面矩阵、API 映射、角色状态、组件状态和 Flutter handoff；清理没有页面承接的死入口。
- **Test Scenarios:** 页面地图每条路由可打开；每个 API 已有能力有页面或明确不适用结论；UI 有/API 无能力保持独立标注；移动端和宽屏无重叠、溢出或断裂返回链路。
- **Verification:** 全路由自动巡检、关键页面截图审查、静态资源引用检查和文档链接检查。

---

## Verification Contract

| 验证层 | 适用单元 | 方法 | 通过信号 |
| --- | --- | --- | --- |
| 静态质量 | U1-U10 | `node --check im-ui-html/assets/app.js`、`node --check im-ui-html/assets/mock-data.js`、`git diff --check`、资源和深链扫描 | 无语法错误、空链接、未知路由或格式错误 |
| 路由巡检 | U1-U10 | 启动现有静态预览后逐条打开 `page-map` 路由 | 页面可刷新、返回路径正确、无 fallback 误判 |
| 交互状态 | U2-U9 | 单一浏览器会话连续执行正常、取消、失败和重试流程 | 状态连续且 mock 数据变化符合页面语义 |
| 角色矩阵 | U5-U6 | owner/admin/member 固定 mock 预览 | 无越权动作，受限原因清晰 |
| 视觉回归 | U1-U10 | Chrome for Testing headed 模式，移动与宽屏截图 | 无重叠、裁切、异常留白、文字溢出或不一致导航 |
| 可访问性 | U1-U10 | 检查按钮语义、dialog、焦点、标签和触控尺寸 | 图标有名称，表单有标签，弹层焦点与关闭策略合理 |
| 文档一致性 | U10 | 对照 `api/src/routes.rs`、页面地图和组件清单 | 三者映射一致，排除项未混入完成范围 |

浏览器验收默认复用单一 `agent-browser` session，按“打开一次 -> 等待稳定 -> 连续操作 -> 统一截图”执行；本计划不要求 Playwright 正式 E2E 脚本，若现有静态巡检脚本可复用则优先扩展。

---

## Definition of Done

- D1. R1-R22 均至少由一个实施单元和一个明确测试场景覆盖。
- D2. API 已有的消息管理、会话归档及即时撤销恢复、好友危险操作、群治理、举报反馈、贴纸、资料账号和版本能力均在设计源有正式入口。
- D3. 所有复杂功能都有独立深链，能直接刷新、截图和返回，不依赖先执行隐藏操作才能进入。
- D4. owner/admin/member、demo/empty/error/loading 等关键状态可确定性复现。
- D5. SMS 登录、短信重置密码及 API 尚未具备的发现能力未被误标为本计划成果。
- D6. 页面沿用当前设计 token、顶部导航、列表密度、底部操作和图标规范，不出现孤立的新视觉体系。
- D7. `im-ui-html/docs/page-map.md`、`component-inventory.md`、`flutter-handoff.md` 与实际路由一致。
- D8. 移动与宽屏验收无页面重叠、文字溢出、底部操作遮挡或失效返回链路。
- D9. 每个独立功能闭环通过静态检查和浏览器验收后再提交，提交保持最小可解释业务边界。
- D10. 设计源不出现归档会话列表、邀请列表、无截图举报，也不把反馈分类映射为独立 API 字段等当前 API 无法直接支撑的契约。

## Appendix

### Related Plans

- `docs/plans/2026-07-31-003-feat-api-ui-capability-parity-plan.md`
- `docs/plans/2026-07-26-002-feat-im-ui-html-v2-design-source-plan.md`
- `docs/plans/2026-07-31-001-refactor-im-ui-mobile-consistency-plan.md`

### Review Priority

实现完成后的评审顺序为：权限和危险操作正确性 -> 路由与状态完整性 -> API 映射一致性 -> 移动端布局 -> 宽屏适配 -> 文档交付质量。
