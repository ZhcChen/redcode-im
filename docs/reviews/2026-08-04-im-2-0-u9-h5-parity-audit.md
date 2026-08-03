# Flutter 2.0 U9 H5 P0 parity 差异审计

## 结论

H5 已具备认证、会话、文本聊天、本地消息搜索、联系人基础流程、基础群设置、资料与部分设置页面，但尚未达到 Flutter 2.0 P0 parity。

本轮以 `app/test/contracts/im_ui_route_contract_test.dart` 冻结的 38 个 P0 路由为产品能力清单，以当前 `h5-app/src/router/index.ts`、页面、Pinia store、service、存储和测试为运行实现证据。审计结果如下：

| 状态 | 数量 | 含义 |
| --- | ---: | --- |
| 已有 | 9 | 已有可进入页面或同等主流程，核心 API/store 已接入 |
| 行为漂移 | 12 | 有部分实现，但入口、权限、状态或操作不满足 Flutter 2.0 P0 |
| 缺失 | 17 | 没有对应 H5 页面或完整用户流程 |
| 平台不适用 | 0 | 38 个 P0 均有 Web 可表达语义；原生能力差异应降级，不应删除业务入口 |

## P0 路由矩阵

| 领域 | Flutter P0 能力 | H5 状态 | 当前证据与差异 |
| --- | --- | --- | --- |
| 认证 | `auth-login` | 已有 | `/login`、auth store、刷新深链守卫和 auth 单测已存在 |
| 会话 | `chats` | 已有 | `/home` 的聊天 Tab、会话缓存、HTTP 刷新、WebSocket 状态和未读数已存在 |
| 聊天 | `chat-detail` | 行为漂移 | `/chats/:roomId` 支持文本、引用、删除、置顶和失败重发；缺少附件发送、贴纸、消息菜单和完整发送/已读状态展示 |
| 聊天 | `message-reads` | 缺失 | 无消息已读/未读成员详情页和查询入口 |
| 聊天 | `message-forward` | 缺失 | 无转发目标选择页；当前引用不能替代转发 |
| 联系人 | `contacts` | 已有 | 联系人 Tab、缓存、搜索、私聊创建已存在 |
| 联系人 | `contact-requests` | 行为漂移 | 请求列表内嵌在联系人 Tab，支持接受/拒绝；缺少独立列表、出站状态与刷新深链 |
| 联系人 | `contact-add` | 行为漂移 | 搜索与添加内嵌在联系人 Tab；缺少独立入口、申请消息和已申请状态 |
| 联系人 | `contact-profile` | 缺失 | 无联系人资料页、备注修改、删除好友和从资料进入聊天 |
| 联系人 | `contact-report` | 缺失 | 无举报用户页面与 API 流程 |
| 发现 | `discover` | 缺失 | H5 只有聊天/联系人/设置三个 Tab，没有 P0 发现 shell；P1 入口不得在 U9 伪实现 |
| 群组 | `groups` | 行为漂移 | 群列表内嵌联系人 Tab；缺少独立目录、搜索、置顶与删除会话操作 |
| 群组 | `group-create` | 行为漂移 | 创建表单内嵌联系人 Tab；缺少独立页面、成员搜索和完整校验反馈 |
| 群组 | `group-settings` | 行为漂移 | 有群头像、改名、置顶、免打扰、退出/解散；“进群审核”是无动作按钮，角色权限未限制危险操作 |
| 群组 | `group-members` | 行为漂移 | 只读成员网格内嵌群设置；缺少成员目录、添加/移除和角色操作 |
| 群组 | `group-admins` | 缺失 | service/store/UI 均无管理员任命与移除闭环 |
| 群组 | `group-join-requests` | 缺失 | 无入群申请列表和审核动作 |
| 群组 | `group-invite` | 缺失 | 无邀请联系人入群页面；service 虽有 `addMembers`，没有正式 UI 闭环 |
| 群组 | `group-invitation` | 缺失 | 无群邀请详情及接受/拒绝页面 |
| 群组 | `group-rules` | 缺失 | 无群规则读取与编辑页面 |
| 群组 | `group-mutes` | 缺失 | 无全体禁言、成员禁言/解禁及权限刷新页面 |
| 群组 | `group-operation-logs` | 缺失 | service 有日志查询，但无页面和入口 |
| 贴纸 | `stickers` | 缺失 | 有 `emoji-cache`，但无我的贴纸页面和管理状态 |
| 贴纸 | `sticker-store` | 缺失 | 无贴纸商店列表、下载/移除流程 |
| 贴纸 | `sticker-pack` | 缺失 | 无贴纸包详情与项目预览 |
| 搜索 | `search` | 已有 | `/messages/search`、本地索引、room 过滤和结果跳转已存在 |
| 我的 | `mine` | 行为漂移 | H5 将设置直接作为一级 Tab，没有 Flutter 2.0 的“我的”资料入口与分组信息架构 |
| 我的 | `mine-profile` | 行为漂移 | `/settings/profile` 可编辑资料和头像，但缺少只读资料主页及稳定的“我的 -> 个人资料”路径 |
| 设置 | `settings` | 行为漂移 | 设置入口内嵌 HomeView，没有独立设置总览路由和深链 |
| 设置 | `settings-account` | 已有 | `/settings/security` 支持修改密码；账号停用仍缺失 |
| 设置 | `settings-chat` | 缺失 | 无聊天背景、贴纸管理和本地存储设置页 |
| 设置 | `settings-privacy` | 已有 | `/settings/privacy` 与 `/settings/agreement` 共用文档页，支持真实配置加载 |
| 设置 | `settings-about` | 行为漂移 | `/settings/about` 有运行模式与反馈入口，但版本写死为 `0.1.0`，没有版本检查状态 |
| 设置 | `settings-profile-edit` | 已有 | `/settings/profile` 支持昵称和头像更新 |
| 设置 | `settings-feedback` | 已有 | `/settings/feedback` 有表单、store 与 service |
| 设置 | `settings-password` | 已有 | 当前合并在 `/settings/security`，行为已具备；后续补兼容深链 |
| 设置 | `settings-deactivate` | 缺失 | 无注销账号确认页和 session 清理闭环 |
| 设置 | `settings-version` | 行为漂移 | About 页显示静态版本，没有真实版本 API、可用更新状态和平台降级说明 |

## 状态与基础设施矩阵

| 能力 | 状态 | 证据或缺口 |
| --- | --- | --- |
| 登录会话与刷新深链 | 已有 | router guard、session service、auth store 单测已覆盖 |
| HTTP 与 WebSocket | 已有 | 统一 token/error 处理、重连、订阅和事件测试已存在 |
| 会话/消息/联系人缓存 | 已有 | wa-sqlite adapter、IndexedDB fallback、存储单测已存在 |
| OPFS 不可用降级 | 已有 | capability probe 与 IndexedDB/memory fallback 测试已存在 |
| 多标签页会话一致性 | 缺失 | session 只依赖 localStorage，没有 `storage`/BroadcastChannel 同步登出与 token 变化 |
| 附件接收与缓存 | 已有 | `CachedAttachment`、blob cache 和富媒体 interop smoke 已存在 |
| 附件发送 | 行为漂移 | service 支持富媒体发送，但聊天 composer 没有图片/文件浏览器入口 |
| 语音/相机能力 | 平台降级待补 | Web 应使用 file input/mediaDevices；不支持时显示明确状态，不能保留无动作入口 |
| 跨端消息/联系人/群 | 部分已有 | H5/iOS 历史 smoke 已覆盖基础消息、好友和群；尚未对齐 Flutter 2.0 已读、治理和状态刷新 |

## 执行顺序

1. **R2.1 聊天差异**：补消息已读详情、转发、附件发送、会话操作与消息状态；强化搜索定位和刷新深链。
2. **R2.2 联系人/群差异**：拆出联系人请求/添加/资料/举报页面；补群目录、创建、成员、管理员、邀请、规则、禁言、审核与日志。
3. **R2.3 我的/设置差异**：建立“发现/我的”四 Tab shell 和独立设置总览；补聊天设置、注销账号和真实版本状态。
4. **R2.4 跨端互操作**：补多标签页 session、存储降级、Flutter/H5 消息与已读、好友和群治理实时同步验收。

每个阶段只在对应 store/service/component 测试与真实 API 流程通过后提交。P1 的朋友圈、扫一扫、附近的人、游戏和音视频通话不纳入 U9；发现 Tab 只交付 P0 shell 和明确的未启用状态。

## 验收门禁

- `make h5-app.check`
- `make h5-app.test.unit`
- `make h5-app.test.live`
- `make h5-app.test.e2e`
- Flutter/H5 双账号消息与已读、联系人、群治理互操作测试
- 本矩阵中的“缺失”和“行为漂移”全部转为“已有”，或记录为有明确用户可见降级语义的平台不适用项
