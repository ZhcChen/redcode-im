# RedCode IM 2.0 U6 群角色合同验收

> 日期：2026-08-02
> 对应计划：`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md` U6

## 结论

- 三账号真实 API contract 已在 Android Emulator（`emulator-5554`，Android 15）通过。
- contract 使用本机 API dev 栈 `http://10.0.2.2:8010`，实际覆盖 owner、admin、member 三种角色。
- 当时默认的 Pixel 8 Pro 未连接；iPhone 17 Pro Simulator 上 Xcode 两次停在 workspace/package loading，业务测试未启动，因此 iOS 设备验收仍未关闭。当前仓库已改为默认使用 iOS Simulator。

## 已验证链路

1. owner 创建群聊，并关闭 `member_can_invite`。
2. 普通 member 创建群邀请被服务端拒绝。
3. owner 开启 `member_can_invite`，member 成功邀请第三个账号。
4. invitee 查询待处理邀请、核对群和邀请人信息并接受邀请。
5. 新成员查询群设置，证明已进入群聊。
6. owner 任命 member 为 admin，admin 成功更新群设置。
7. owner 解除 admin，后续禁言、解除禁言、群规和操作日志合同继续通过。

## 命令证据

通过：

```bash
APP_TEST_DEVICE=emulator-5554 make app.test.integration.contract
```

结果：`All tests passed`，真实流程完成三个普通账号注册与清理。

未通过：

```bash
make app.test.integration.contract
```

自动选择 iPhone 17 Pro Simulator，连续两次停在 Xcode workspace/package loading；中止后显示 `No tests ran`。该结果只记录工具链问题，不作为 U6 iOS 验收证据。

## 剩余门禁

- 解决本机 Xcode 构建阻塞后，在默认 iOS Simulator 上执行真实 contract。
- Pixel 仍缺席时，需要修复当前 Xcode package loading 卡住问题并重新执行 iOS Simulator contract。
- U6 页面级设备 smoke 仍需覆盖群通知入口、邀请接受/拒绝和 owner/admin/member 权限可见性。
