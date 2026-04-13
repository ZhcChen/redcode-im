# Backend Wave C（短信登录 / 头像上传）测试设计

**日期**: 2026-03-05  
**范围**: `tests/go/backend/auth`、`tests/go/backend/users`

## 1. 目标

补齐 Backend 剩余 TODO 的 Wave C：

1. `BE-AUTH-003`：短信登录 `POST /auth/login/sms`。
2. `BE-USER-004`：头像上传提交流程 `/users/me/avatar/*`。

## 2. 策略

- 测试类型：Go 黑盒契约。
- 核心原则：
  - 对短信登录，验证“错误码拒绝 + 通用验证码成功登录（自动注册）”。
  - 对头像上传，验证“直传签名 -> 对象上传 -> commit -> 下载 URL -> 内容回读”端到端链路。
- 外部依赖：头像上传链路通过 external-mock（对象存储模拟）执行。

## 3. 用例设计

### 3.1 SMS 登录

- 管理员开启 `require_captcha_for_login` 并配置通用验证码。
- `/auth/sms/send` 返回发送成功。
- `/auth/login/sms` 使用错误验证码返回 400。
- `/auth/login/sms` 使用通用验证码返回 200，包含 token/refresh_token，且用户名等于手机号。
- 登录后 `/auth/me` 可访问。

### 3.2 用户头像上传

- 先校验非法 key commit（路径不合法）返回业务失败。
- `POST /users/me/avatar/direct-upload` 获取 key + 直传签名。
- 按签名上传对象到 external-mock。
- `POST /users/me/avatar/commit` 成功并返回下载 URL。
- `/auth/me` 中 `avatar_object_key` 更新为新 key。
- `/users/me/avatar/url` 获取下载 URL 并拉取二进制内容与上传内容一致。

## 4. 验收标准

1. 两组测试在隔离栈通过。
2. `backend.csv` 中 `BE-AUTH-003`、`BE-USER-004` 标记为 done。
3. 测试指南与回归报告同步更新。
