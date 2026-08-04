---
title: U10 E2EE U5 Flutter/H5 跨端单聊联调验收
date: 2026-08-04
status: partial
scope: app,h5-app,api
---

# U10 E2EE U5 Flutter/H5 跨端单聊联调验收

## 结论

Flutter 与 H5 的单房间、双向真实 E2EE 消息链通过联调门禁。Flutter 和 H5 均使用各自正式协议状态、正式发送接口和正式消息解密链，没有使用离线 fixture、共享协议状态或明文回退。

本记录只证明 U5 的基础跨端单聊闭环，不代表 U5 整体完成。双方各两设备、离线补拉、重复 WebSocket、身份变化和模式切换等场景尚未全部通过，生产 E2EE 继续 No-Go，Admin 不得开启 E2EE。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| Flutter -> H5 | Flutter `MessageService.sendTextMessage` -> API 密文 -> H5 WebSocket -> `mapWebSocketMessage` -> `messageService.resolveEncryptedMessage` | 按服务端消息 ID 关联并互解通过 |
| H5 -> Flutter | H5 `E2eeDirectMessageCoordinator.sendText` -> API 密文 -> Flutter `MessageService.loadMessages` | 按服务端消息 ID 关联并互解通过 |
| H5 历史复核 | `messageService.loadMessages` | WebSocket 解密结果与正式历史链一致 |
| Flutter 历史复核 | `MessageService.loadMessages` | H5 发送消息可由 Flutter 正式链解密 |
| 服务端原始历史 | `/rooms/{room_id}/messages` | 两条跨端消息均只有 MLS v1 `encrypted_content`，不含双方明文标记 |
| H5 回归 | `bun run type-check && bun run test` | type-check 通过；218 项通过，7 项按配置跳过 |
| Flutter 回归 | `flutter test` | 382 项通过 |
| 跨端 live | 临时切换 `persist/e2ee` 后执行 `make h5-app.test.e2ee.live` | 通过；测试后恢复 `persist/plaintext` |

## 实现边界

- H5 live 测试在 `127.0.0.1` 随机端口启动临时协调服务，只允许随机 Bearer secret 访问。
- token、明文标记和协调 secret 不进入子进程参数；Flutter 通过进程环境和本机协调服务读取夹具。
- Flutter 子进程保持存活，直到 H5 回发消息完成正式历史加载和解密。
- 子进程失败输出会脱敏协调 secret 和双方明文标记。
- live 入口仍要求服务端已显式启用 E2EE，不在测试内部修改 Admin runtime。

## 新发现风险

- 当前设备生命周期只在首次初始化时发布一个 KeyPackage。该 KeyPackage 被一个房间 bootstrap 消费后，同一设备无法为第二个新会话自动补充 KeyPackage，API 会返回“没有可领取的 KeyPackage”。
- 本轮使用独立首设备账号隔离跨端单房间场景，没有绕过 API 门禁。进入多会话、多设备验收前必须实现可观测的 KeyPackage 库存补充策略，并增加并发领取和耗尽恢复测试。
- live 用例仍会在 dev 数据库创建随机测试账号、好友关系和密文记录，暂未自动清理。

## 保持阻断

- 双方各两设备与设备批准/撤销链未完成。
- 离线补拉、重复 WebSocket、历史明文/新密文混排、身份变化、损坏密文和 runtime 切换矩阵未全部完成。
- KeyPackage 自动补充与耗尽恢复未完成。
- U5 其余门禁、U6-U9 和独立安全审查完成前，生产发布保持 No-Go。
