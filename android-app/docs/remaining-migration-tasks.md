# android-app 剩余任务整理

更新时间：2026-07-05

本文档只记录当前 Android 原生迁移尚未完成的工作。完整历史任务树见 `android-app/docs/full-migration-task-tree.md`。

## 当前状态

- 已完成：原生 Android 工程骨架、账号密码认证、Chat/Contacts/Rooms 真实 API、WebSocket JSON 增量、Room 缓存、群管理、附件选择、mock 对象存储直传、富媒体消息基线。
- 已验证：`android-app.test.unit`、`android-app.test.live`、`android-app.test.interop`、`android-app.coverage`、`android-app.lint`、`android-app.build.debug`、`android-app.connected-test`、`android-app.smoke.emulator`。
- 当前测试设备：本机 Android Emulator，最近验收设备为 `emulator-5554` / `Pixel_8_Pro(AVD) - 15`。
- 真机依赖策略：需要相机、麦克风、FCM 云投递、厂商 ROM 行为的项不阻塞 Emulator 阶段，记录为 SKIPPED，后续真机补验。
- 最新进度：用户头像缓存和群头像缓存已完成，包含 `AvatarCacheRepository`、avatar remote data source、`CachedAvatarBadge`、`avatarObjectKey` DTO/model/Room mapping 和相关测试；已通过 unit/lint/build/connected/emulator smoke/live/interop 验证。

## 优先级队列

### P0：继续补齐当前媒体切片

目标：完成 ANDROID-06 中不依赖真机的剩余可测能力。

- [x] 用户头像缓存
  - 接入用户头像 download URL。
  - 本地 app cache 保存头像文件。
  - UI 使用缓存头像，失败时降级为占位。
  - 覆盖缓存命中、下载失败、清理逻辑单测。
- [x] 群头像缓存
  - 接入群头像 download URL。
  - 群列表、群详情使用缓存头像。
  - 登出或清理本地状态时清理相关缓存。
  当前结果：
  - 已新增 Android avatar cache repository，用户/群头像按 object key 映射到 app cache 文件。
  - `ChatSummary`、`Contact`、`RoomInfo`、`RoomMember` 和认证 session 已保留 `avatarObjectKey`。
  - 聊天列表、联系人、群列表、群详情、群成员、设置页当前用户头像均接入缓存头像组件。
  - 缓存缺失或下载失败时降级为首字母占位；登出清理本地状态时清理头像缓存。
  - 已覆盖缓存命中、object key 变化、下载失败不污染缓存和 clear 清理。
- [x] 附件本地文件 cache
  - 已发送/已下载附件保存到 app cache。
  - 再次打开时优先使用本地缓存。
  - 文件不存在或损坏时重新拉取 download URL。

  当前结果：
  - 已新增 Android `FileResourceCache`，附件缓存按 object key 映射到 app cache 文件。
  - `APIClient` 已支持 signed URL binary download。
  - 发送附件成功后会保存上传 bytes 并把 `localPath` 回写消息 parts。
  - 聊天附件支持手动缓存；二次缓存优先命中本地文件，缓存文件缺失或大小不匹配时重新获取 download URL。
  - 已覆盖缓存命中、下载失败不污染缓存、损坏清理、上传后保留 localPath、下载后二次命中。
- [ ] 权限拒绝和恢复路径
  - 文件选择器取消选择不报错。
  - 麦克风/通知权限拒绝时 UI 给出可恢复提示。
  - 权限二次拒绝时引导到系统设置。
- [ ] 语音播放基线
  - 已上传 audio part 的播放入口。
  - 播放/暂停/错误状态。
  - 不依赖麦克风录音即可在 Emulator 验证。

### P1：聊天扩展能力

目标：完成 ANDROID-07。

- [ ] 内置 emoji 面板
  - 聊天输入区增加 emoji 入口。
  - 支持插入到 draft。
  - 单测覆盖输入状态。
- [ ] 表情包列表和表情项加载
  - 接入后端表情包 API。
  - Room 或 DataStore 缓存必要元数据。
  - H5/API/Android 表情列表互通 smoke。
- [ ] 表情资源缓存
  - 使用 download URL 下载表情资源。
  - 保存到 app cache。
  - 缓存命中、失效、清理测试。
- [ ] 贴纸发送
  - 贴纸按图片附件链路发送。
  - 消息展示贴纸元数据/预览。
- [ ] 聊天背景
  - DataStore 保存每 room 背景配置。
  - Compose 聊天详情渲染背景。
- [ ] 聊天设置
  - 字体大小、回车发送、媒体自动下载等本地偏好。
  - 与已有 DataStore 偏好层合并。

### P1：设置、账号和配置

目标：完成 ANDROID-08。

- [ ] 个人资料和昵称更新
  - 接入个人资料读取/更新 API。
  - UI 支持昵称、头像入口。
  - Room/会话展示同步最新昵称。
- [ ] 账号安全和修改密码
  - 接入修改密码 API。
  - 表单校验、错误展示、成功后状态处理。
- [ ] 用户协议、隐私政策、关于页完善
  - 当前已有协议勾选和文档拉取基线。
  - 设置页补完整入口和加载/错误态。
- [ ] 反馈提交
  - 接入反馈 API。
  - 支持文本、联系方式、可选附件。
- [ ] App 配置拉取与缓存
  - 启动或登录后拉取远端配置。
  - DataStore/Room 缓存配置。
  - 失败时使用本地默认配置。
- [ ] 版本检查和更新提示
  - 接入版本 API。
  - 设置页展示当前版本、最新版本和下载入口。

### P2：通知和 Push

目标：完成 ANDROID-09 中 Emulator 可测部分，并记录真机补验项。

- [ ] 本地通知权限请求
  - Android 13+ 请求 `POST_NOTIFICATIONS`。
  - 拒绝/允许/不再询问状态处理。
- [ ] 本地通知展示
  - 前后台消息通知基线。
  - 通知 channel 管理。
  - 登出清理通知。
- [ ] 通知导航
  - 点击通知进入对应 room。
  - 冷启动和已启动两种路径。
- [ ] FCM token 注册与上报
  - 接入 FCM SDK。
  - token 获取和上报 API。
  - mock token 单测；真实 token 走真机补验。
- [ ] 登出通知态清理
  - 清理本地通知、token 绑定状态、本地 channel 相关状态。

### P2：底座和协议补齐

这些是早期任务树里保留的底层补齐项。

- [ ] HTTP client 与统一错误模型完善
  - 当前已有 `NetworkFailure` 基线。
  - 补齐错误码分类、重试建议、用户可读错误映射。
- [ ] WebSocket protobuf 二进制帧
  - 当前只完成 JSON `/ws?format=json`。
  - 需要确认后端二进制帧协议和兼容策略。
- [ ] DataStore：偏好、聊天设置
  - 当前已有协议勾选偏好。
  - 需要承接聊天设置、通知设置、外观设置。
- [ ] live smoke 分层
  - 当前 `android-app.test.live` 一次跑 Chat/Friend/Room/Media。
  - 拆成可独立选择的 smoke 子集，便于定位失败。
- [ ] 重置密码
  - 当前测试主线关闭邮箱资源。
  - 后续按普通账号安全策略决定是否保留。
- [ ] 登出清理文件 cache/通知态
  - 与 File cache、通知模块完成后一起补齐。

### P3：全量验收与切换准备

目标：完成 ANDROID-10。

- [ ] Android vs Flutter 功能对照清单
  - 逐项比对 Flutter `app/` 已有功能。
  - 标出 Android 已完成、部分完成、跳过、缺失。
- [ ] H5/API/Android 联调脚本
  - 串联认证、联系人、群、文本、富媒体、设置、通知可测路径。
  - 保持 Docker Compose-first。
- [ ] Emulator smoke 扩展
  - 覆盖主要 Compose UI 入口。
  - 保持无真机依赖。
- [ ] Compose UI 回归
  - 聊天、联系人、群、设置关键页面截图或 UI test。
- [ ] 覆盖率继续提升
  - 优先补 ViewModel、Repository、DTO mapping、Room cache。
  - 真机能力不强行伪造 100%，但可用 mock 覆盖分支。
- [ ] P0/P1 缺口清单
  - 发布切换前生成阻塞项列表。
- [ ] Flutter Android 下线条件
  - 明确何时 Android 原生可替代 Flutter Android。
  - Flutter `app/` 暂保留，不移除。
- [ ] 回滚策略
  - 保留 Flutter Android 构建路径。
  - 记录后端/API 兼容要求。

## 真机补验清单

以下任务不在 Emulator 阶段伪造通过，待有 Android 真机时补验：

- [ ] 相机拍摄图片/视频。
- [ ] 麦克风录音质量、权限、后台中断。
- [ ] 厂商 ROM 文件选择器差异。
- [ ] FCM 真实 token 获取。
- [ ] 云端 Push 投递。
- [ ] 前台/后台/冷启动通知导航。
- [ ] 厂商 ROM 后台限制。
- [ ] Play 签名、release 包安装和发布链路。

## 建议执行顺序

1. ANDROID-06：继续推进权限拒绝恢复、语音播放基线。
2. ANDROID-07：emoji、表情包、贴纸、聊天设置。
3. ANDROID-08：个人资料、账号安全、反馈、配置、版本。
4. ANDROID-09：通知权限、本地通知、通知导航、FCM mock 链路。
5. ANDROID-10：全量对照、联调脚本、覆盖率提升、切换准备。

每个阶段完成后继续执行：

```bash
make android-app.test.unit
make android-app.test.live
make android-app.test.interop
make android-app.coverage
make android-app.lint
make android-app.build.debug
make android-app.connected-test
make android-app.smoke.emulator
git diff --check
```
