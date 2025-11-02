# Desktop API 映射表

## 1. 系统 / 认证

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 登录注册 | `POST sys/login`<br>`POST sys/register` | `POST /auth/login`<br>`POST /auth/register` | 登录接口直接改用 Bearer Token 模式；注册保留用户名 + 密码流程。桌面端登录页已对接。 |
| 短信验证码 | `POST sys/senMobileSMS`<br>`POST sys/login`（携带短信参数） | `POST /auth/sms/send`<br>`POST /auth/login/sms` | 旧版短信登录参数需重写为 `phone` + `code` 形式（当前 UI 暂未提供入口）。 |
| Token 鉴权 | `POST sys/startByToken` | `GET /auth/me` | 启动时改为读取本地 Token 并调用 `/auth/me` 刷新用户信息，Vuex 初始化已实现。 |
| 用户登出 | `POST sys/logout` | 客户端本地清除令牌 | 新后端无登出接口，直接清空本地 Session 并断开 WebSocket（UI 按钮已接入）。 |
| 第三方 / 交易登录 | `POST sys/authlogin`<br>`POST sys/txByToken`<br>`POST sys/gettrctoken` | 暂无对应 | 功能直接下线，UI 需移除入口。 |
| 账号注销 / 校验 | `POST sys/LogOff`<br>`POST sys/checkLoginStatus`<br>`POST sys/checkMobile` | 暂无对应 | 如需保留需新增后端能力，否则下线。 |
| 版本更新 | `POST sys/getAppConfig`<br>`POST sys/getLatestVersion` | 待接入 Release 通知方案 | 桌面端改用手动检查或后端新增 `/settings` 能力。 |

## 2. 用户信息

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 自己信息 | `POST imUser/getUserAccountInfo` | `GET /auth/me` | 数据结构需适配后端 `AuthUser` 定义。 |
| 更新资料 | `POST imUser/updateUserInfo`<br>`POST imUser/updateUserInfoKeepAlive` | `PATCH /users/me` | 保留昵称、签名、头像等字段，去除 KeepAlive 分支。 |
| 修改密码 | `POST imUser/updateUserPassword` | `POST /users/me/password` | 旧参数为 `oldPwd/newPwd`，新接口为 `current_password/new_password`。需要在数据层转换。 |
| 搜索用户 | `POST imUser/searchUser` | `GET /users/search?keyword=` | 返回列表结构不同，使用 `frontend` 的 `AuthUser` 映射。 |
| 上传头像 | 旧版走文件服务 | `POST /users/me/avatar` | 需改用多部分表单上传，依后端返回 URL。 |
| 联系人同步 / 交易密码 / 视频通话 | `imUser/syncContacts` 等 | 暂无对应 | 相应 UI 功能下线。 |

## 3. 好友相关

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 好友列表 | `POST imUserFriend/getMyFriendList` | `GET /friends` | 新接口返回 `FriendInfo[]`，桌面端联系人面板已对接。 |
| 添加好友 | `POST imUserFriend/addFriend` | `POST /friends/requests` | 旧版直接建立好友关系，新版先创建请求，字段需转换为 `target_user_id`、`message`（后续 UI 待补充）。 |
| 审批好友 | `POST imUserFriend/handleFriendApply`<br>`POST imUserFriend/unHandleFriendApply*` | `GET /friends/requests`<br>`POST /friends/requests/:request_id/respond` | 收敛为列表 + Respond 组合。 |
| 发起私聊 | `POST imChatGroup/createSingleChat` | `POST /friends/:friend_user_id/chat` | 新接口返回房间 ID，可复用。 |
| 删除 / 拉黑好友 | `POST imUserFriend/deleteFriend`<br>`POST imUserFriend/blackFriend` | 暂无对应 | 后端尚未开放，桌面端先隐藏相关入口。 |
| 备注管理 | `POST imUserFriend/updateFriendInfo` | 待补充 | 若需保留，需要接口支持或复用 `/friends/:id` PATCH（待后端）。 |

## 4. 房间 / 群聊

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 我的房间列表 | `POST imChatGroup/getMyChatGroupList`<br>`POST imChatGroup/getMyJoinChatGroupList` | `GET /chats`<br>`GET /rooms` | `/chats` 用于汇总最近会话，`/rooms` 返回详细信息；桌面端会话列表采用 `/chats`。 |
| 创建房间 | `POST imChatGroup/launchChatGroup` | `POST /rooms` | 新接口支持多人房间，字段需映射为 `name`、`member_ids` 等。 |
| 加入/退出 | `POST imGroupUser/addMemberForGroup`<br>`POST imGroupUser/quitChatGroup` | `POST /rooms/:room_id/join`<br>`POST /rooms/:room_id/leave` | 权限控制改由后端校验。 |
| 房间成员 | `POST imChatGroup/getChatGroupMembers`<br>`POST imUser/getGroupMemberInfo` | `GET /rooms/:room_id/members` | 需调整展示字段。 |
| 房间设置 | `POST imChatGroup/setChatGroupInfo`<br>`POST imGroupUser/updateMyGroupSet` | `PATCH /rooms/:room_id`（待后端） | 目前后端仅支持基础创建，进阶设置需排期。 |
| 清空消息 / 置顶 | `POST imGroupUser/clearChatMessage` 等 | `POST /rooms/:room_id/messages/read_until`<br>`POST /rooms/:room_id/messages/:message_id/pin` | 清空逻辑替换为读取至末尾，置顶沿用新接口。 |
| 红包 / 转账 | `imGroupUser/sendRedBag*`、`sendTransfer` 等 | 暂无对应 | 功能移除。 |

## 5. 消息

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 拉取消息 | `POST imMessageGroup/getMessageListByChatGroupId` | `GET /rooms/:room_id/messages` | 支持分页参数 `limit`、`before_id`、`since_id`；桌面端消息面板已接入。 |
| 发送消息 | `POST imMessageGroup/send<Text|Image|File>Message` | `POST /rooms/:room_id/messages` | 新接口统一 `content` + `message_type`，多媒体需先上传文件获取 URL；当前桌面实现支持文本。 |
| 转发消息 | `POST imMessageGroup/forwardMessages` | `POST /rooms/:room_id/messages/forward` | 传入 `original_message_id`。 |
| 删除消息 | `POST imMessageGroup/deleteMessages` | `DELETE /rooms/:room_id/messages/:message_id` | 支持单条删除。 |
| 撤回消息 | `POST imMessageGroup/revertMsg` | 待开发 | 目前后端未提供撤回，暂不支持。 |
| 标记已读 | `POST imMessageGroup/markMessagesAsRead`<br>`POST imMessageGroup/getUnreadMessageCount` | `POST /rooms/:room_id/messages/read`<br>`GET /rooms/:room_id/unread_count`<br>`GET /unread_counts` | 新接口拆分为房间级/全局统计。 |
| 置顶 / 引用 | 旧版自定义字段 | `POST /rooms/:room_id/messages/:message_id/pin`<br>`POST /rooms/:room_id/messages`（携带 `quoted_message_id`） | 引用消息通过可选字段实现。 |

## 6. 文件与存储

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 文件上传/下载 | `file/upload`、`file/getDownloadUrl` 等 | 待后端提供统一文件服务 | 现阶段仅保留头像上传，聊天文件需走对象存储能力或暂不开放。 |
| 图片/音视频 | `send<Image|Audio|Video>Message` | 使用 `/rooms/:room_id/messages` + 外部 URL | 需引入文件上传流程或限制为外链。 |

## 7. 朋友圈 / 账户 / AI / 音乐

| 模块 | 旧接口 | 新接口 / 策略 | 说明 |
| --- | --- | --- | --- |
| 账户流水 | `accountRecord/*` | 暂无对应 | 功能移除，页面直接下线。 |
| 朋友圈 | `imFriendCircle/*` | 暂无对应 | 功能移除。 |
| AI 聊天 | `/chatGpt/*` | 暂无对应 | 功能移除，后续若需接入统一 AI 服务再行规划。 |
| 音乐 | `/freeMusic/*` | 暂无对应 | 功能移除。 |

## 8. 实时通信

| 模块 | 旧实现 | 新实现 / 策略 | 说明 |
| --- | --- | --- | --- |
| WebSocket | `TIO_SERVER` (`ws://...:9022`) | `WS_URL`（默认 `ws://<host>:8010/ws`） | 迁移至后端自带 WebSocket，鉴权需要携带 Bearer Token（参照 Flutter `WebSocketService`）。 |
| 推送消息 | 自建协议 | 后端 Redis Pub/Sub + `ServerPush` | 桌面端需实现与 Flutter 一致的事件处理。 |

> 注：映射中标记为“暂无对应”的功能将在迁移过程中移除或等待后端能力补齐，需同步更新产品文档与 UI。﻿
