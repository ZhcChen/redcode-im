# Flutter 2.0 U9 H5 P0 parity 差异审计

## 结论

H5 已关闭 R2.1 聊天差异、R2.2 联系人/群差异与 R2.3 我的/设置差异。P0 路由矩阵已全部实现，但 R2.4 跨端互操作尚未完成，因此仍不宣告 Flutter 2.0 P0 parity。

本轮以 `app/test/contracts/im_ui_route_contract_test.dart` 冻结的 38 个 P0 路由为产品能力清单，以当前 `h5-app/src/router/index.ts`、页面、Pinia store、service、存储和测试为运行实现证据。审计结果如下：

| 状态 | 数量 | 含义 |
| --- | ---: | --- |
| 已有 | 38 | 已有可进入页面或同等主流程，核心 API/store 已接入 |
| 行为漂移 | 0 | 当前路由矩阵无未解释行为漂移 |
| 缺失 | 0 | 当前路由矩阵无缺失页面 |
| 平台不适用 | 0 | 38 个 P0 均有 Web 可表达语义；原生能力差异应降级，不应删除业务入口 |

## P0 路由矩阵

| 领域 | Flutter P0 能力 | H5 状态 | 当前证据与差异 |
| --- | --- | --- | --- |
| 认证 | `auth-login` | 已有 | `/login`、auth store、刷新深链守卫和 auth 单测已存在 |
| 会话 | `chats` | 已有 | `/home` 的聊天 Tab、会话缓存、HTTP 刷新、WebSocket 状态和未读数已存在 |
| 聊天 | `chat-detail` | 已有 | 支持文本、附件、引用、转发来源、删除、失败重发、消息状态和会话长按菜单 |
| 聊天 | `message-reads` | 已有 | 已有消息已读/未读成员详情页、查询入口及真实 API 验收 |
| 聊天 | `message-forward` | 已有 | 已有转发目标选择、发送闭环和转发来源展示 |
| 联系人 | `contacts` | 已有 | 联系人 Tab、缓存、搜索、私聊创建已存在 |
| 联系人 | `contact-requests` | 已有 | 已有独立列表、收件/发件状态、接受/拒绝和刷新深链 |
| 联系人 | `contact-add` | 已有 | 已有独立搜索入口、申请消息和已申请状态 |
| 联系人 | `contact-profile` | 已有 | 已有联系人资料、备注修改、删除好友和资料页私聊入口 |
| 联系人 | `contact-report` | 已有 | 已有举报原因、说明、提交状态和 API 闭环 |
| 发现 | `discover` | 已有 | 四 Tab shell 已提供发现入口；未交付 P1 功能保持不可见 |
| 群组 | `groups` | 已有 | 已有独立群目录、搜索及会话操作入口 |
| 群组 | `group-create` | 已有 | 已有独立建群页、成员搜索、至少一名额外成员校验和 API 闭环 |
| 群组 | `group-settings` | 已有 | 群头像、改名、置顶、免打扰、退出/解散及治理入口均按角色限制 |
| 群组 | `group-members` | 已有 | 已有成员目录、搜索、直接添加和群主/管理员移除闭环 |
| 群组 | `group-admins` | 已有 | 已有管理员列表、群主任命与撤销闭环 |
| 群组 | `group-join-requests` | 已有 | 已有审核开关、申请列表、通过/拒绝、备注及成员状态验证 |
| 群组 | `group-invite` | 已有 | 支持直接添加与正式邀请两种语义，正式邀请不会提前加入成员 |
| 群组 | `group-invitation` | 已有 | 已有群通知收件箱、全部/待处理筛选及接受/拒绝闭环 |
| 群组 | `group-rules` | 已有 | 已有群规读取、新增、修改、删除及权限控制 |
| 群组 | `group-mutes` | 已有 | 已有全体禁言、原因/时长、成员禁言与解禁闭环 |
| 群组 | `group-operation-logs` | 已有 | 已有群主/管理员入口、只读时间线及分页加载 |
| 贴纸 | `stickers` | 已有 | 已有我的贴纸列表、签名图片缓存和移除确认 |
| 贴纸 | `sticker-store` | 已有 | 已有可用贴纸列表、搜索、单贴纸/贴纸包添加闭环 |
| 贴纸 | `sticker-pack` | 已有 | 已有刷新安全详情页、已添加贴纸包内容查询及图像预览 |
| 搜索 | `search` | 已有 | `/messages/search`、本地索引、room 过滤和结果跳转已存在 |
| 我的 | `mine` | 已有 | 四 Tab shell 已提供“我的”资料入口和独立设置入口 |
| 我的 | `mine-profile` | 已有 | 已有只读资料主页及“我的 -> 个人资料 -> 编辑”稳定路径 |
| 设置 | `settings` | 已有 | 已有 `/settings` 独立总览路由和刷新深链 |
| 设置 | `settings-account` | 已有 | `/settings/security` 支持修改密码；账号停用仍缺失 |
| 设置 | `settings-chat` | 已有 | 支持聊天背景持久化、贴纸管理入口及消息/媒体本地缓存清理 |
| 设置 | `settings-privacy` | 已有 | `/settings/privacy` 与 `/settings/agreement` 共用文档页，支持真实配置加载 |
| 设置 | `settings-about` | 已有 | About 使用 package 构建版本，并提供反馈与版本状态入口 |
| 设置 | `settings-profile-edit` | 已有 | `/settings/profile` 支持昵称和头像更新 |
| 设置 | `settings-feedback` | 已有 | `/settings/feedback` 有表单、store 与 service |
| 设置 | `settings-password` | 已有 | 当前合并在 `/settings/security`，行为已具备；后续补兼容深链 |
| 设置 | `settings-deactivate` | 已有 | 双重确认后调用账号停用 API，清理会话与账号本地缓存并回到登录页 |
| 设置 | `settings-version` | 已有 | 使用 package 构建版本查询真实 `/versions/latest`，展示更新状态及 Web 不安装原生包的降级说明 |

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

## R2.1 / R2.2 / R2.3 验收证据

- R2.1 聊天差异：`96ea85ef`、`2b4aee01`、`a1539dec`、`97135b38`、`a91e5ccf`。
- R2.2 联系人/群差异：`12820122`、`62aec5ec`、`debeb1c6`、`5d992bca`、`573c1c8d`、`54a1f235`、`f3a979ad`、`94c0c8f8`、`0dfcf307`。
- R2.3 我的/设置差异：`e5acdd70`、`5ccbc0f9`、`52bfb0a2`、`6d620f5d`。
- 最新 H5 门禁：TypeScript check 通过；unit `178 passed / 4 skipped`；live `4 passed`；真实 API E2E `7 passed`；生产构建通过。
- 真实 API E2E 覆盖注册登录、群聊消息、好友申请、头像上传、群成员增删、入群审核、操作日志、正式群邀请接受/拒绝、四 Tab、聊天设置、贴纸路由、版本状态和账号停用。
- 下一执行阶段：R2.4 跨端互操作；此处不宣告 U9 完成。

## 验收门禁

- `make h5-app.check`
- `make h5-app.test.unit`
- `make h5-app.test.live`
- `make h5-app.test.e2e`
- Flutter/H5 双账号消息与已读、联系人、群治理互操作测试
- 本矩阵中的“缺失”和“行为漂移”全部转为“已有”，或记录为有明确用户可见降级语义的平台不适用项
