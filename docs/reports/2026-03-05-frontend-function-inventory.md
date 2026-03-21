# Frontend 功能清单（全量盘点）

更新时间：2026-03-05  
范围：`frontend/lib/**`（Flutter 客户端）

## 1. 启动与应用壳层

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-ST-001 | 应用启动初始化（日志、热更新管理器、通知、Push、屏幕适配） | `frontend/lib/main.dart` |
| FE-FUNC-ST-002 | 动态应用名加载（SettingsService） | `frontend/lib/app.dart` |
| FE-FUNC-ST-003 | 热更新资源覆写（HotPatchAssetBundle） | `frontend/lib/app.dart` |
| FE-FUNC-ST-004 | 启动页会话恢复与路由分流（Home/Login） | `frontend/lib/features/startup/splash_page.dart` |
| FE-FUNC-ST-005 | 启动页整包版本检查（可选更新/强制更新） | `frontend/lib/features/startup/splash_page.dart` |
| FE-FUNC-ST-006 | 启动后异步热更新检查 | `frontend/lib/features/startup/splash_page.dart` |

## 2. 认证与账号

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-AUTH-001 | 密码登录（账号/密码） | `frontend/lib/features/auth/login_page.dart` |
| FE-FUNC-AUTH-002 | 短信验证码登录（含倒计时与验证码开关） | `frontend/lib/features/auth/login_page.dart` |
| FE-FUNC-AUTH-003 | 短信登录自动注册兜底 | `frontend/lib/features/auth/login_page.dart` |
| FE-FUNC-AUTH-004 | 第三方登录入口（Google/Apple） | `frontend/lib/features/auth/login_page.dart` |
| FE-FUNC-AUTH-005 | 协议确认状态读取与保存 | `frontend/lib/features/auth/login_page.dart` |
| FE-FUNC-AUTH-006 | 重置密码（短信码 + 新密码） | `frontend/lib/features/auth/reset_password_page.dart` |
| FE-FUNC-AUTH-007 | 会话模型与用户模型序列化/拷贝 | `frontend/lib/features/auth/models/*.dart` |
| FE-FUNC-AUTH-008 | 认证仓库（登录/注册/短信/OAuth/改密/注销/刷新用户） | `frontend/lib/features/auth/data/auth_repository.dart` |

## 3. 首页导航

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-HOME-001 | 三栏导航（聊天/联系人/设置） | `frontend/lib/features/home/home_shell_page.dart` |
| FE-FUNC-HOME-002 | Tab 未读角标（消息未读 + 待处理好友） | `frontend/lib/features/home/home_shell_page.dart` |
| FE-FUNC-HOME-003 | 进入首页自动建立 WebSocket 连接 | `frontend/lib/features/home/home_shell_page.dart` |
| FE-FUNC-HOME-004 | 切换联系人页触发静默刷新 | `frontend/lib/features/home/home_shell_page.dart` |

## 4. 聊天域（Chat）

### 4.1 会话列表与会话模型

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-CHAT-001 | 会话列表渲染与排序展示 | `frontend/lib/features/chat/chat_list_page.dart` |
| FE-FUNC-CHAT-002 | 收藏夹会话展示策略 | `frontend/lib/features/chat/chat_list_page.dart` |
| FE-FUNC-CHAT-003 | 会话项标题优先级（备注/昵称/名称）与未读角标 | `frontend/lib/features/chat/widgets/chat_list_item.dart` |
| FE-FUNC-CHAT-004 | 会话模型时间文案/复制更新 | `frontend/lib/features/chat/models/chat_model.dart` |

### 4.2 聊天详情与消息行为

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-CHAT-005 | 消息发送（文本/富文本分片/附件） | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-006 | 消息引用、转发、撤回/删除、重发 | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-007 | 表情反应（添加/取消）与 reaction picker | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-008 | @提及成员与输入联想面板 | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-009 | 输入态广播（typing）与订阅处理 | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-010 | 已读回执查看（read receipts） | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-011 | 媒体消息渲染（图/音/视频/文件） | `frontend/lib/features/chat/chat_detail_page_v2.dart` |
| FE-FUNC-CHAT-012 | 聊天气泡渲染（系统消息/普通消息/反应区） | `frontend/lib/features/chat/widgets/chat_message_bubble.dart` |
| FE-FUNC-CHAT-013 | 消息模型序列化、时间戳规则、头像显示规则 | `frontend/lib/features/chat/models/message_model.dart` |
| FE-FUNC-CHAT-014 | 基础聊天详情页（v1 兼容页） | `frontend/lib/features/chat/chat_detail_page.dart` |

### 4.3 群组与高级功能

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-CHAT-015 | 创建群聊与成员选择 | `frontend/lib/features/chat/create_group_page.dart` |
| FE-FUNC-CHAT-016 | 群设置（公告、免打扰、成员管理入口） | `frontend/lib/features/chat/group_settings_page.dart` |
| FE-FUNC-CHAT-017 | 群管理员管理（任命/移除） | `frontend/lib/features/chat/group_admin_management_page.dart` |
| FE-FUNC-CHAT-018 | 入群申请管理（同意/拒绝） | `frontend/lib/features/chat/group_join_requests_page.dart` |
| FE-FUNC-CHAT-019 | 禁言管理（设置/取消） | `frontend/lib/features/chat/group_mute_management_page.dart` |
| FE-FUNC-CHAT-020 | 群规管理（增删改） | `frontend/lib/features/chat/group_rules_page.dart` |
| FE-FUNC-CHAT-021 | 群操作日志浏览 | `frontend/lib/features/chat/group_operation_logs_page.dart` |
| FE-FUNC-CHAT-022 | 置顶消息页（取消置顶） | `frontend/lib/features/chat/pinned_messages_page.dart` |
| FE-FUNC-CHAT-023 | 消息搜索（本地索引 + 服务端补全） | `frontend/lib/features/chat/message_search_page.dart` |
| FE-FUNC-CHAT-024 | 视频预览播放 | `frontend/lib/features/chat/video_preview_page.dart` |
| FE-FUNC-CHAT-025 | 语音播放与录音面板 | `frontend/lib/features/chat/widgets/voice_message_widget.dart` |
| FE-FUNC-CHAT-026 | 聊天状态管理与消息事件编排（ChatProvider） | `frontend/lib/features/chat/providers/chat_provider.dart` |

## 5. 联系人域（Contacts）

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-CON-001 | 联系人列表分组与索引侧边栏 | `frontend/lib/features/contacts/contacts_page.dart` |
| FE-FUNC-CON-002 | 添加好友（搜索、发送申请、处理申请） | `frontend/lib/features/contacts/add_friend_page.dart` |
| FE-FUNC-CON-003 | 联系人详情（发消息、删除好友） | `frontend/lib/features/contacts/contact_detail_page.dart` |
| FE-FUNC-CON-004 | 好友关系模型、申请状态转换 | `frontend/lib/features/contacts/models/friend_models.dart` |

## 6. 设置域（Settings）

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-SET-001 | 设置首页（用户信息、导航、退出） | `frontend/lib/features/settings/settings_page.dart` |
| FE-FUNC-SET-002 | 账号安全入口 | `frontend/lib/features/settings/account_security_page.dart` |
| FE-FUNC-SET-003 | 聊天设置（背景、贴纸、缓存清理） | `frontend/lib/features/settings/chat_settings_page.dart` |
| FE-FUNC-SET-004 | 聊天背景选择/保存 | `frontend/lib/features/settings/chat_background_page.dart` |
| FE-FUNC-SET-005 | 贴纸管理（我的贴纸/商店） | `frontend/lib/features/settings/sticker_management_page.dart` |
| FE-FUNC-SET-006 | 反馈提交 | `frontend/lib/features/settings/feedback_page.dart` |
| FE-FUNC-SET-007 | 隐私协议拉取与展示 | `frontend/lib/features/settings/privacy_policy_page.dart` |
| FE-FUNC-SET-008 | 关于页（版本信息、检查更新、下载） | `frontend/lib/features/settings/about_page.dart` |
| FE-FUNC-SET-009 | 危险操作确认弹窗（关键字确认） | `frontend/lib/features/settings/widgets/confirm_action_dialog.dart` |
| FE-FUNC-SET-010 | 通用确认弹窗（异步确认/取消） | `frontend/lib/core/widgets/tip_dialog.dart` |

## 7. 发现与表情

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-DIS-001 | 发现页模块化展示（当前为 mock 内容） | `frontend/lib/features/discover/discover_page.dart` |
| FE-FUNC-EMJ-001 | 表情包/表情项模型 | `frontend/lib/features/emoji/models/emoji_pack_models.dart` |
| FE-FUNC-EMJ-002 | 表情包服务（我的/可用/搜索/添加/删除） | `frontend/lib/core/services/emoji_pack_service.dart` |

## 8. 核心服务与基础设施

| 功能ID | 功能说明 | 入口文件 |
|---|---|---|
| FE-FUNC-CORE-001 | 认证状态总线与路由守卫 | `frontend/lib/core/auth/*.dart` |
| FE-FUNC-CORE-002 | 版本服务（latest/download） | `frontend/lib/core/services/version_service.dart` |
| FE-FUNC-CORE-003 | 设置服务（应用名、协议、验证码） | `frontend/lib/core/services/settings_service.dart` |
| FE-FUNC-CORE-004 | 应用名缓存服务（内存 + 本地 + API） | `frontend/lib/core/services/app_config_service.dart` |
| FE-FUNC-CORE-005 | 反馈服务 | `frontend/lib/core/services/feedback_service.dart` |
| FE-FUNC-CORE-006 | 上传策略服务（缓存 + 远端刷新） | `frontend/lib/core/services/upload_policy_service.dart` |
| FE-FUNC-CORE-007 | 消息服务（发送、分片、附件、反应） | `frontend/lib/core/services/message_service.dart` |
| FE-FUNC-CORE-008 | 房间服务（群设置、成员、申请、禁言等） | `frontend/lib/core/services/room_service.dart` |
| FE-FUNC-CORE-009 | WebSocket 服务（消息事件、连接态） | `frontend/lib/core/services/websocket_service.dart` |
| FE-FUNC-CORE-010 | Push + 本地通知 + 导航 | `frontend/lib/core/services/push_*.dart` |
| FE-FUNC-CORE-011 | 语音服务 | `frontend/lib/core/services/voice_service.dart` |
| FE-FUNC-CORE-012 | 头像服务（用户/群） | `frontend/lib/core/services/*avatar_service.dart` |
| FE-FUNC-CORE-013 | 本地存储（token/chat/message/avatar/emoji等） | `frontend/lib/core/storage/*.dart` |
| FE-FUNC-CORE-014 | 热更新模型/持久化/运行时 | `frontend/lib/core/update/*.dart` |

## 9. 外部依赖点（测试关注）

- HTTP API：`/healthz`、`/versions/*`、`/settings/*`、`/feedbacks`、`/system/upload-policy`、聊天/房间/好友接口。
- WebSocket：`/ws` 实时消息链路。
- Push/通知：FCM/APNs + 本地通知（当前自动化中以可替代链路为主）。
- 下载与外部跳转：`url_launcher` 外部浏览器安装包下载。
- 本地持久化：`SharedPreferences` / SQLite（由 storage/service 封装）。

