# android-app 完整迁移任务树

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
- [ ] 登出清理 Token、WS、Room/DataStore/cache/通知态。

## ANDROID-02 网络、WebSocket、本地数据底座

- [ ] HTTP client 与统一错误模型。
- [x] HTTP client 基线、JSON 编解码、Bearer token、错误消息提取。
- [x] Chat HTTP API 基线：`/chats`、`/rooms/{room_id}/messages`、文本发送、已读标记。
- [ ] WebSocket client：鉴权、订阅、重连、去重。
- [x] Room schema：会话、消息、联系人。
- [x] Room Chat/Contacts DAO、Repository 与 Emulator in-memory 验证。
- [ ] Room schema：群、配置。
- [ ] DataStore：偏好、聊天设置。
- [ ] File cache：附件、头像、表情。
- [x] 测试 fake data source 与 Room in-memory test 分层。
- [ ] live smoke 分层。

进度备注：
- 已接入 Preferences DataStore 保存协议勾选状态；聊天设置等非敏感偏好仍在后续阶段扩展。
- 已接入公开设置文档端点：`/settings/privacy-policy`、`/settings/user-agreement`。

## ANDROID-03 聊天核心

- [x] In-memory 会话列表和文本发送基线。
- [x] 每 room 最近消息保留策略单测。
- [x] Room 会话摘要、消息缓存与每 room 最近消息保留策略。
- [x] 真实会话列表。
- [ ] 历史消息分页。
- [x] 历史消息首屏加载。
- [ ] pending/failed/resend。
- [ ] 已读、删除、置顶、引用、reaction。
- [ ] 未读数、置顶、免打扰。
- [ ] 本地搜索索引。
- [ ] H5/API/Android 聊天互通 smoke。

进度备注：
- `RemoteChatRepository` 已接入真实 HTTP 合同，并在 `ANDROID_APP_USE_REMOTE_AUTH=true` 时随真实认证链路启用。
- 当前 Android UI 会在进入会话列表和聊天详情时触发一次 HTTP 刷新；真正的分页、失败重试、WebSocket 增量同步仍在后续阶段。

## ANDROID-04 联系人与好友

- [x] In-memory 联系人列表、搜索和 upsert。
- [x] Room 联系人缓存、搜索、upsert、remove、clear。
- [x] 真实用户搜索。
- [x] 好友申请、接受、拒绝。
- [ ] 联系人详情。
- [x] 打开私聊。
- [ ] H5/API/Android 好友互通 smoke。

进度备注：
- `RemoteContactsRepository` 已接入 `/users/search`、`/friends`、`/friends/requests`、`/friends/requests/{id}/respond`、`/friends/{id}/chat`。
- 当前 Android UI 仍保留极简联系人列表/搜索入口；好友申请列表、联系人详情和互通 smoke 待后续 UI/联调阶段补齐。

## ANDROID-05 群聊和群管理

- [ ] 创建群聊。
- [ ] 群设置、成员列表。
- [ ] 改名、置顶、免打扰。
- [ ] 管理员、禁言、入群申请。
- [ ] 群规则、操作日志。
- [ ] 退出/解散。
- [ ] H5/API/Android 群管理 smoke。

## ANDROID-06 媒体、附件、头像、语音和视频

- [ ] 图片/视频选择。
- [ ] 文件选择。
- [ ] 上传策略、对象存储 mock 直传、commit。
- [ ] 图片/视频/附件预览。
- [ ] 用户头像和群头像缓存。
- [ ] 语音录制、发送、播放。
- [ ] 权限拒绝和恢复路径。
- [ ] H5/API/Android 富媒体互通 smoke。
- [ ] SKIPPED 真机补验：相机、麦克风硬件差异、厂商 ROM 文件选择差异。

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
