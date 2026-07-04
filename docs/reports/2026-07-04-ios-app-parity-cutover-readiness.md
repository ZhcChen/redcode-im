# ios-app Flutter parity 与切换准备报告

生成时间：2026-07-04

## 结论

`ios-app` 的主要 Flutter parity 功能链路已完成原生 Swift/SwiftUI 实现，并已通过 SwiftPM 单测、H5/API/iOS live smoke、H5/iOS 富媒体互通、媒体 mock 回归、本机 iOS Simulator smoke 和 XCUITest。

当前不建议删除 Flutter `app/`。删除/下线 Flutter iOS 前仍需补齐一个非代码条件：

- 使用 iPhone 真机和 Apple APNs 平台凭据补验 APNs token 获取、离线系统通知投递与点击深链。

## 已验证命令

```bash
cd ios-app && swift test
git diff --check
make ios-app.check
make ios-app.test.interop
make ios-app.smoke.simulator
make ios-app.ui-test
```

结果：

- `swift test`：149 passed，7 个 live 用例按环境变量跳过。
- `git diff --check`：通过。
- `make ios-app.check`：通过。
- `make ios-app.test.interop`：通过，包含 H5 live smoke、H5/iOS 富媒体互通与 iOS 认证、WebSocket、聊天、好友、群、媒体 mock live smoke。
- `make ios-app.smoke.simulator`：通过，已在本机 `iPhone 17 Pro` Simulator 启动。
- `make ios-app.ui-test`：通过，2 个 XCUITest 用例覆盖认证协议门禁/登录和聊天详情发送。

## Flutter vs iOS 功能对照

已对齐：

- 启动与认证：启动恢复、普通账号密码注册/登录、登录态恢复、登出清理、重置密码、协议勾选。
- 网络与缓存：HTTP client、WebSocket 认证/订阅/重连/去重、SwiftData 本地会话/消息/联系人/群/配置缓存、FileManager 媒体缓存。
- 聊天核心：会话列表、未读、置顶/免打扰展示、聊天详情、历史合并、文本发送、pending/failed/resend、引用、已读、删除、消息置顶、reaction。
- 联系人与好友：搜索用户、好友申请、请求 badge、接受/拒绝、联系人详情、打开私聊、H5/iOS 好友互通。
- 群管理：建群、群设置、成员管理、改名、置顶/免打扰、退出/解散、管理员、禁言、入群申请、群规则、操作日志。
- 媒体与附件：图片/视频/文件选择、上传策略、mock B2 直传、commit、下载、附件缓存、头像缓存、头像上传、语音录制/发送/播放。
- 表情与扩展：内置 emoji、表情包、贴纸缓存、贴纸发送链路、消息搜索、本地索引、聊天背景和聊天设置。
- 设置与配置：个人资料、昵称更新、账号安全、修改密码、用户协议、隐私协议、关于、反馈、通用配置缓存、版本检查、iOS 原生更新提示。
- 通知：本地通知权限、后台 WebSocket 新消息本地通知兜底、APNs token 注册底座、push device 上报/注销、通知点击导航、冷启动 pending payload、登出通知态清理。

已补自动化前置：

- API 已支持 APNs provider 配置、APNs token 投递、Push 日志和 `external-mock` APNs 投递自测；本地/CI 测试不访问 Apple 或 Firebase 线上推送服务。
- iOS App 已支持从 Info.plist / 启动环境读取真机可访问的 API/WS 地址，并新增 `make ios-app.apns.preflight` 作为真机通知补验预检入口。

仍需真机补验：

- 离线系统通知：需要 iPhone 真机与 Apple APNs 平台凭据，Simulator/单测只能覆盖本地通知调度与 payload 导航。

## P0/P1 缺口清单

当前未发现阻断 H5/API/iOS 主链路联调的 P0/P1 功能缺口。

非 P0/P1 待办：

- 准备 iPhone 真机和 Apple APNs 平台凭据后补跑通知投递验收。

补充说明：

- H5 主动发送富媒体已补 `messageService.sendRichMessage` 与 live smoke；当前媒体链路已覆盖 H5 直传 mock 对象存储、commit、发送富媒体消息，以及 iOS-compatible HTTP 读取附件。

## Flutter iOS 下线条件

必须全部满足后再删除或下线 Flutter iOS：

1. `make ios-app.check` 通过。
2. `make ios-app.test.interop` 通过。
3. `make ios-app.smoke.simulator` 通过。
4. `make ios-app.ui-test` 通过。
5. iPhone 真机通知补验通过，至少覆盖 APNs token 获取、后端设备上报、离线推送、点击进入会话/联系人请求。
6. `app/` Flutter iOS 无独有 P0/P1 功能仍未迁移。
7. 发布说明中明确 iOS 原生包切换版本、回滚版本和数据兼容策略。

## 回滚策略

- 代码回滚：保留 Flutter `app/`，直到原生 iOS 切换完成且稳定；若原生 iOS 发布异常，移动端 iOS 发布渠道回滚到上一个 Flutter iOS 包。
- 服务端回滚：本次 iOS parity 不引入破坏性后端接口迁移；若发现接口兼容问题，优先回滚客户端调用或通过后端兼容字段修复。
- 数据回滚：iOS 本地缓存使用 SwiftData/FileManager/Keychain，不改变服务端数据结构；客户端异常时可清理本地缓存和重新登录恢复。
- 通知回滚：APNs 真机投递未完成前，不把离线系统通知作为切换强依赖；保留 WebSocket 在线收消息与本地通知兜底。

## 后续补验入口

```bash
# iPhone 真机和推送凭据就绪后执行真机通知补验
# API mock 链路已纳入 make api.test；真机补验需连接 iPhone 并配置真实 APNs 凭据后记录到本报告或后续报告。
IOS_APP_API_BASE_URL=http://<LAN_IP>:8010 \
IOS_APP_WS_URL=ws://<LAN_IP>:8010/ws \
IOS_APNS_PROVIDER_CONFIGURED=1 \
make ios-app.apns.preflight

IOS_APP_API_BASE_URL=http://<LAN_IP>:8010 \
IOS_APP_WS_URL=ws://<LAN_IP>:8010/ws \
IOS_APNS_PROVIDER_CONFIGURED=1 \
IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID> \
make ios-app.smoke.device
```
