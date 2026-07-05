# android-app 完整迁移任务树

剩余任务的执行版清单见 `android-app/docs/remaining-migration-tasks.md`。

## ANDROID-00 方案与骨架

- [x] 创建原生 Android 模块目录。
- [x] 确认官方架构：Compose、ViewModel、UDF、Repository、Flow。
- [x] 建立 Gradle Android 工程。
- [x] 建立 Compose App Shell。
- [x] 建立测试和覆盖率入口。
- [x] 建立迁移文档。

## ANDROID-01 启动、认证与会话

- [x] 普通账号密码注册/登录本地模拟 flow。
- [x] 邮箱登录/注册关闭校验。
- [x] 真实 API `/auth/register`、`/auth/login`、`/auth/me` 客户端合同。
- [x] RemoteAuthRepository 支持真实注册后自动登录、登录、登出清理。
- [x] Token/session store 抽象与 in-memory 测试实现。
- [x] Token Keystore 持久化。
- [x] 启动态恢复。
- [ ] 重置密码。
- [x] 用户协议/隐私协议勾选与文档拉取。
- [x] 登出清理 Token、WS、Room 缓存、Repository 内存态和表单敏感态。
- [ ] 登出清理文件 cache/通知态。

## ANDROID-02 网络、WebSocket、本地数据底座

- [ ] HTTP client 与统一错误模型。
- [x] HTTP client 基线、JSON 编解码、Bearer token、错误消息提取。
- [x] Chat HTTP API 基线：`/chats`、`/rooms/{room_id}/messages`、文本发送、已读标记。
- [x] WebSocket JSON client 基线：鉴权、订阅/退订、ping、重连、重复订阅保护。
- [x] WebSocket 增量事件落库与消息去重基线。
- [ ] WebSocket protobuf 二进制帧。
- [x] Room schema：会话、消息、联系人。
- [x] Room Chat/Contacts DAO、Repository 与 Emulator in-memory 验证。
- [x] 真实 Chat/Contacts HTTP 数据落 Room 组合仓储。
- [x] Room schema：群、成员、配置缓存。
- [ ] DataStore：偏好、聊天设置。
- [ ] File cache：附件、头像、表情（附件和头像已完成，表情待补）。
- [x] 测试 fake data source 与 Room in-memory test 分层。
- [ ] live smoke 分层。

进度备注：
- 已接入 Preferences DataStore 保存协议勾选状态；聊天设置等非敏感偏好仍在后续阶段扩展。
- 已接入公开设置文档端点：`/settings/privacy-policy`、`/settings/user-agreement`。
- 已接入 `/ws?format=json` 控制帧基线，登录后自动鉴权并根据 Room 缓存会话维护房间订阅；`message`、`message_read`、`message_update`、房间变更/清理和好友申请增量事件已接到 Room/Repository。

## ANDROID-03 聊天核心

- [x] In-memory 会话列表和文本发送基线。
- [x] 每 room 最近消息保留策略单测。
- [x] Room 会话摘要、消息缓存与每 room 最近消息保留策略。
- [x] 真实会话列表。
- [x] 历史消息分页基线。
- [x] 历史消息首屏加载。
- [x] pending/failed/resend 基线。
- [x] 消息删除、消息置顶、reaction 基线。
- [x] 引用消息发送和渲染基线。
- [x] 未读数、会话置顶、免打扰基线。
- [x] 本地搜索索引基线。
- [x] H5/API/Android 聊天互通 smoke。

进度备注：
- `RemoteChatRepository` 已接入真实 HTTP 合同，并在 `ANDROID_APP_USE_REMOTE_AUTH=true` 时随真实认证链路启用。
- 当前 Android UI 会在进入会话列表和聊天详情时触发一次 HTTP 刷新；真正的分页、失败重试、WebSocket 增量同步仍在后续阶段。
- 真实 API 构建下，Chat/Contacts 远端刷新结果已经写入 Room，UI 订阅 Room Flow；后续 WebSocket 增量同步会写入同一缓存层。
- WebSocket JSON client 已能维持会话房间订阅；消息增量会按消息 ID 去重写入 Room，并同步会话摘要、未读数和本机已读清零。
- 文本发送已接入乐观 Pending，本地/远端失败会落 Failed 状态，失败消息支持重试后替换为服务端消息。
- 历史消息已支持使用当前首条消息作为 `before_id` 加载更早消息，并合并写入本地消息流。
- 消息删除、消息置顶和 `👍` reaction 已接入真实 HTTP 合同、Room v2 缓存、ViewModel/UI 操作入口，并处理 `pin_update` / `reaction_update` WebSocket 增量事件。
- 引用消息已接入 `quoted_message_id` 发送、`quoted_message` 解析、Room v3 缓存和聊天详情引用预览。
- 会话置顶和免打扰已接入 `/rooms/{room_id}/pin`、`/rooms/{room_id}/notification-settings`，并在 Room 会话摘要、列表排序和 Compose 操作入口中生效；未读数已有摘要显示和进入会话已读清零基线，后续联调阶段再补独立未读拉取/多端校验。
- 本地消息搜索已基于 Room 缓存接入，当前支持按房间搜索消息正文、发送人名、引用内容和富媒体附件元数据，Compose 聊天详情页提供搜索入口；远端 `/messages/search` 互通后续随联调阶段补齐。
- 已新增 `make android-app.test.live` 与 `make android-app.test.interop`；`android-app.test.interop` 串联 H5 live smoke 与 Android 数据层 live smoke，在同一 Compose API 上验证账号注册、建群、H5-compatible/Android HTTP 双向文本/附件引用互发、双方消息可见和已读标记。

## ANDROID-04 联系人与好友

- [x] In-memory 联系人列表、搜索和 upsert。
- [x] Room 联系人缓存、搜索、upsert、remove、clear。
- [x] 真实用户搜索。
- [x] 好友申请、接受、拒绝。
- [x] 联系人详情。
- [x] 打开私聊。
- [x] H5/API/Android 好友互通 smoke。

进度备注：
- `RemoteContactsRepository` 已接入 `/users/search`、`/friends`、`/friends/requests`、`/friends/requests/{id}/respond`、`/friends/{id}/chat`。
- Android 联系人 UI 已补齐搜索添加、好友申请列表、同意/拒绝、已发送申请、联系人详情弹窗和私聊入口；已通过 `make android-app.test.interop` 覆盖 H5 live smoke 与 Android 数据层好友搜索、好友申请、接受、联系人刷新、打开私聊和私聊消息可见。

## ANDROID-05 群聊和群管理

- [x] 创建群聊。
- [x] 群设置、成员列表。
- [x] 改名、置顶、免打扰。
- [x] 管理员、禁言、入群申请 API 合同。
- [x] 群规则、操作日志。
- [x] 退出/解散。
- [x] H5/API/Android 群管理 smoke。

进度备注：
- 已新增 `RoomRepository` / `RoomRemoteDataSource` / `HttpRoomRemoteDataSource`，覆盖 `/rooms`、成员、群设置、置顶、免打扰、管理员、禁言、群规、入群申请和操作日志合同。
- Room v4 已新增群、成员和群设置缓存表；真实 API 构建下使用 `CachedRemoteRoomRepository` 写入 Room，默认无后端构建使用 `InMemoryRoomRepository` 保障 emulator smoke。
- Compose 新增“群聊”主 Tab，支持创建群、选择好友成员、群详情、资料编辑、成员管理、入群审批/全员禁言切换、管理员/禁言、群规、日志、退出/解散，以及打开群聊。
- 已新增 `AndroidRoomLiveSmokeTest`，`make android-app.test.live` 覆盖群管理 live smoke；`make android-app.test.interop` 会串联 H5 live smoke 与 Android 认证/聊天/好友/群管理数据层 smoke。

## ANDROID-06 媒体、附件、头像、语音和视频

- [x] 图片/视频选择（系统文件选择器基线）。
- [x] 文件选择（系统文件选择器基线）。
- [x] 上传签名、对象存储 commit、下载 URL API 合同。
- [x] 对象存储 mock 直传执行。
- [x] 图片/视频/语音/文件消息 parts DTO、WebSocket 增量解析和 Room v5 缓存。
- [x] 图片/视频/附件元数据预览基线。
- [x] 用户头像和群头像缓存。
- [ ] 语音录制、发送、播放（播放基线已完成；录制/真机质量待补）。
- [x] 权限拒绝和恢复路径。
- [x] H5/API/Android 富媒体互通 smoke 基线。
- [ ] SKIPPED 真机补验：相机、麦克风硬件差异、厂商 ROM 文件选择差异。

进度备注：
- `ChatMessage.parts` 已对齐后端 `MessagePartPayload`，支持 text/image/video/audio/file 分片和附件元数据。
- `HttpChatRemoteDataSource` 已接入 `/rooms/{room_id}/messages/attachments/signature`、直传 signature URL、`/commit`、`/download`，并支持发送富媒体消息引用已生成的 `messages/*` object key。
- Compose 聊天详情已接入 Android 系统 `OpenDocument` 文件选择器，选择图片/视频/音频/普通文件后会读取元数据、推断 part type，并经真实 API 构建执行“签名 -> mock 对象存储直传 -> commit -> 发送富媒体消息”链路。
- Room v5 为 `chat_messages` 增加 `partsJson`，会话详情可渲染附件类型、文件名、MIME、大小等元数据，本地搜索可命中附件名。
- `RealtimeEventProcessor` 已解析 WebSocket `parts` / `attachments` 增量字段，写入同一 Room 消息缓存。
- `AndroidChatLiveSmokeTest` 已覆盖文本互发、Android image attachment mock 直传/commit/发送，以及 H5-compatible HTTP / Android HTTP 双方可见和下载 URL 可生成。
- 已新增附件本地 cache 底座：上传成功后保存 bytes 到 app cache，附件手动缓存时优先命中本地文件，缺失或大小不匹配时重新拉 download URL，并把 `localPath` 持久化到消息 parts。
- 用户头像和群头像缓存已完成：当前包含 avatar download URL、avatar cache repository、`CachedAvatarBadge`、`avatarObjectKey` DTO/model/Room mapping 和单测；已通过 unit/lint/build/connected/emulator smoke/live/interop 验证。
- 权限拒绝和恢复路径已完成：文件选择器取消不污染 draft，麦克风/通知权限拒绝可重新授权，二次拒绝或系统不再询问引导打开系统设置；真机差异项保持 SKIPPED。
- 语音播放基线已完成：聊天详情页 audio part 可加载本地缓存、播放、暂停和展示失败状态，Compose UI test 已触发播放/暂停路径；播放器初始化失败时会释放临时实例并清空旧播放器引用。
- 当前未接相机、麦克风录音和硬件音频质量链路；这些能力按真机补验项保持 SKIPPED。

## ANDROID-07 表情、贴纸、搜索和聊天扩展

- [ ] 内置 emoji。
- [ ] 表情包列表和表情项加载。
- [ ] 表情资源缓存。
- [ ] 贴纸管理。
- [ ] 聊天背景。
- [ ] 聊天设置。

## ANDROID-08 设置、账号、文档、反馈、配置和版本

- [x] In-memory 设置通知开关。
- [ ] 个人资料和昵称更新。
- [ ] 账号安全和修改密码。
- [ ] 用户协议、隐私政策、关于。
- [ ] 反馈提交。
- [ ] App 配置拉取与缓存。
- [ ] 版本检查和更新提示。

## ANDROID-09 Push、本地通知和通知导航

- [ ] 本地通知权限请求。
- [ ] 本地通知展示。
- [ ] FCM token 注册与上报。
- [ ] 前台/后台/冷启动通知导航。
- [ ] 登出通知态清理。
- [ ] SKIPPED 真机补验：FCM 真实 token、云端投递、后台限制和厂商 ROM 行为。

## ANDROID-10 全量验收与切换准备

- [ ] Android vs Flutter 功能对照清单。
- [ ] H5/API/Android 联调脚本。
- [ ] Emulator smoke。
- [ ] Compose UI 回归。
- [ ] 覆盖率尽可能接近 100%。
- [ ] P0/P1 缺口清单。
- [ ] Flutter Android 下线条件。
- [ ] 回滚策略。
