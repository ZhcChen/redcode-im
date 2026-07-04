# android-app Flutter parity 范围

## 参考来源

- Flutter：`app/lib/`
- Flutter 测试：`app/test/`、`app/integration_test/`、`app/patrol_test/`
- H5 parity：`h5-app/src/`
- iOS 原生迁移经验：`ios-app/` 与 `docs/plans/2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`

## 功能范围

- Startup：启动页、会话恢复、未登录跳转。
- Auth：普通账号密码注册、登录、登出、重置密码；邮箱和第三方登录当前关闭。
- Shell：聊天、联系人、设置主 Tab。
- Chat：会话列表、聊天详情、文本、富媒体、语音、已读、未读、置顶、免打扰、引用、reaction、搜索。
- Contacts：联系人列表、用户搜索、好友申请、处理申请、联系人详情、私聊。
- Groups：建群、群设置、成员、管理员、禁言、申请、规则、日志、退出/解散。
- Media：图片、视频、文件、头像、附件缓存、对象存储 mock 直传。
- Emoji：内置 emoji、表情包、贴纸管理、资源缓存。
- Settings：资料、账号安全、协议、隐私、关于、反馈、配置、版本检查、更新提示。
- Push：本地通知、FCM channel、通知导航、登出清理。

## 原生映射

- Flutter local SQLite 缓存 -> Android Room。
- Flutter secure/token storage -> Android Keystore / Jetpack Security。
- Flutter shared preferences -> Android DataStore。
- Flutter service/provider -> Android Repository + ViewModel。
- Flutter widget 页面 -> Compose screen。
- Flutter integration/patrol -> JVM unit test + Compose instrumented test + live smoke。

## 当前已落地

- Compose App Shell。
- 账号密码注册/登录 in-memory flow。
- Chat / Contacts / Settings 三主 Tab。
- 基础聊天发送和每 room 最近消息策略。
- 联系人搜索和本地 upsert。
- 设置通知开关。
- 单元测试、Compose UI test、Jacoco 覆盖率入口。
