# RedCode IM Flutter App

`app/` 是当前保留维护的 Flutter 移动端模块。它不再作为新原生迁移的唯一实现来源，但必须持续对齐当前已闭合的 `api/` 合同，作为行为对照、回滚包和跨端回归入口。

## 当前维护口径

- 默认认证链路：普通账号密码注册/登录。
- 邮箱注册/登录：仅作为后台配置兼容能力保留，当前自动化不依赖真实邮箱资源。
- 短信验证码登录/重置密码：保留接口入口，不作为当前默认验收主线。
- Google / Apple 登录：不进入当前主线。
- 对象存储、Push、IPInfo：本地联调必须走 Compose API dev 栈内的 `external-mock`，不得访问线上 B2、FCM、APNs。
- 设备验收：优先 `Pixel 8 Pro (3A091FDJG001DN)`；未连接时回退本机 iOS Simulator；真机前必须重新检测本机 LAN IP。

## 常用命令

```bash
make app.install
make app.check
make app.test.scripts
make app.test.unit
make app.test.integration.smoke

# 真实 API 联调：先启动 Compose API dev 栈
make api.up
make api.wait
make app.test.integration.auth
```

设备联调同样需要先启动并等待 API dev 栈：

```bash
make api.up
make api.wait
make app.test.integration.device
make app.test.integration.device.auth
```

## API 合同基线

Flutter 当前直接对接 `api/` 的 REST 和 WebSocket JSON 合同；核心入口包括但不限于：

- `/auth/register`、`/auth/login`、`/auth/login/sms`、`/auth/me`、`/auth/refresh`
- `/auth/sms/send`、`/auth/password/reset`
- `/users/me`、`/users/me/password`、`/users/me/avatar/*`
- `/users/search`、`/users/{user_id}`、`/friends/*`
- `/chats`、`/chats/{room_id}`、`/rooms/*`
- `/rooms/{room_id}/messages/*`
- `/rooms/{room_id}/messages/attachments/*`
- `/uploads/multipart/*`
- `/messages/search`
- `/emoji-packs/*`
- `/settings/*`
- `/versions/*`
- `/feedbacks`、`/reports/*`
- `/push/devices`
- `/system/upload-policy`

API 侧闭合验证入口为 `make api.test`；Flutter 侧维护变更至少跑 `make app.check` 和 `make app.test.unit`。涉及真实 API 合同的变更还要跑 `make app.test.integration.auth` 或对应 integration 入口。

## 文档入口

- 脚本说明：`app/scripts/README.md`
- 测试总览：`docs/reference/testing/README.md`
- 剩余任务总账：`docs/reports/task-list.md`
