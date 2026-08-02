# Flutter 2.0 U7 我的与设置验收记录

## 结论

U7“重构我的、资料与设置”的代码与自动化合同已完成。移动端第四 Tab 已从旧设置根页切换为正式“我的”页，资料、账号安全、聊天设置、隐私协议、反馈、版本、注销和退出登录均有真实实现，不存在 SMS 重置密码或无效 CTA。

U8 默认设备验收不包含在本结论中。Pixel 8 Pro 当前未连接；iOS Simulator 仍受本机 Xcode 26 build service 卡住影响，Android Emulator 结果仅作为真实 API 补充证据。

## 已验证范围

- “我的”一级页：身份加载、缓存回退、错误重试、资料和设置入口。
- 个人资料：读取昵称、用户名、邮箱和状态；只允许编辑 API 支持的昵称和头像。
- 头像：使用 S3 兼容直传签名与 commit 流程；上传失败保留表单和待上传预览。
- 账号安全：当前密码修改，不进入 SMS 重置流程；密码至少 8 位且同时包含字母和数字。
- 注销账号：影响确认、勾选确认和“注销”文本二次确认。
- 设置：作为二级导航页承载账号安全、聊天、隐私协议和关于，不重复承载资料编辑或危险操作。
- 反馈：失败保留当前输入；真实合同实际提交 `/feedbacks`。
- 版本：latest、optional、forced、error、hot available、hot applied 状态均有确定映射。
- 退出登录：复用 `AuthRepository.logout()`，执行 Push 注销、WebSocket 断开、消息与好友缓存清理、Token 清理并返回登录页。

## 自动化证据

- `make app.check`：通过。
- `make app.test`：324 项通过。
- `make app.test.api-paths`：`app_paths=90 api_routes=212 missing=0`。
- `APP_TEST_DEVICE=emulator-5554 make app.test.integration.contract`：Android 15 Emulator 通过，输出 `All tests passed!`。
- `git diff --check`、`git diff --cached --check`：各业务闭环提交前通过。

## 对应提交

- `6c94bc64 feat(app): 建立我的一级页面`
- `5a828a13 fix(app): 对齐账号安全真实流程`
- `d4555d7a refactor(app): 收敛设置页职责`
- `dafcc0b0 feat(app): 完成个人资料编辑`
- `6a7c81eb feat(app): 完成我的页面退出登录`
- `de8aaa22 feat(app): 补齐反馈与版本状态`

## U8 待验收项

- 按设备策略重新检测 Pixel 8 Pro；缺席时重试 iOS Simulator。
- 验收系统键盘、安全区、相册权限拒绝与恢复、前后台切换、离线恢复和系统返回。
- iOS Xcode build service 恢复前，不得将 Android 合同结果记录为默认设备验收通过。
