# Flutter iOS 设备人工验收清单

本文档只记录 Patrol / integration 无法可靠证明的系统交互，不用自动化 mock 结果替代真实设备证据。

## 2026-08-03 iOS Simulator 布局验收

- 设备：iPhone 17 Pro Simulator，iOS 26.3，`EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`
- API：`http://127.0.0.1:8010`
- 账号：使用 `/tmp/redcode-dual-env` 中的 A/B 测试账号

| 场景 | 操作 | 通过标准 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| 真实系统软键盘 | 真实登录后进入 A/B 私聊，手指点击 composer | iOS 软键盘可见，不能使用 Patrol `enterText()` 代替 | SKIPPED | Patrol 4.3 XCTest native tree 不暴露 Flutter `TextField`，native index、selector 和坐标点击均无法稳定拉起键盘 |
| 键盘遮挡 | 输入至少三行长文本 | composer、发送按钮和当前输入行完整位于键盘上方 | PENDING | 待人工截图，建议保存到 `docs/reviews/evidence/` 的本地验收目录，不提交账号信息 |
| 返回优先级 | 键盘打开时点击聊天页返回键，再次点击 | 第一次只收键盘并保留聊天页，第二次退出聊天页 | PENDING | 自动化已证明“焦点优先返回”，仍需真实软键盘人工复核 |
| 顶部/底部安全区 | 分别检查登录页、四 Tab、聊天页和长设置页 | 状态栏不遮挡标题，Home Indicator 不遮挡底栏或最后一项 | PENDING | 待竖屏截图 |
| 横屏策略 | 聊天页旋转到横屏并恢复竖屏 | 页面不溢出，`.h/.sp` 不异常放大，恢复后状态保留 | PENDING | 尺寸算法自动化已通过，待设备截图 |
| 大字号与长文本 | 系统文字调至最大，再巡检四 Tab、聊天和设置页 | 文案不重叠、不截断关键命令，列表可滚动至最后一项 | PENDING | 组件 2x text scale 自动化已通过，待设备截图 |
| Reduced Motion | 打开“减弱动态效果”后重复导航和面板操作 | 功能状态不丢失，无依赖动画才能完成的操作 | PENDING | motion token 自动化已通过，待设备操作记录 |

## Patrol 兼容性结论

`device_layout_test.dart` 保留真实账号登录、长 composer、设备尺寸和焦点优先返回回归，但不声称覆盖真实系统软键盘。重新评估 Patrol/Xcode 组合时，只有以下链路全部可重复通过，才能把软键盘场景改为自动化 PASS：

1. 原生点击 Flutter composer，而不是 `PatrolTester.enterText()`。
2. iOS native UI tree 能查询到 `IOSElementType.keyboard`。
3. `MediaQuery.viewInsets.bottom > 0`，且发送按钮位于键盘上方。
4. 首次系统返回只收键盘，第二次才退出聊天页。
