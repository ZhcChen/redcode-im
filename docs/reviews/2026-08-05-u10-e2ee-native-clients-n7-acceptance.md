---
title: U10 E2EE 原生客户端 N7 验收记录
date: 2026-08-05
status: partial
scope: android-app,ios-app,h5-app,e2ee-core,api
verdict: no-go
---

# U10 E2EE 原生客户端 N7 验收记录

## 结论

N1-N6 的原生双端协议能力、状态存储、设备生命周期、单聊协调、多设备与群
成员变化、附件与外围边界已经实现并通过平台单测。N7 尚未达到 D7：当前
Android/iOS 聊天主链没有挂载新协调器，仓库也没有 Android x iOS x H5 三端
真实 E2EE live 驱动，因此不能用单测、共享核心 fixture 或普通明文 live 替代
三端互解证据。

U7 P0-1 保持打开，生产 E2EE 继续 **No-Go**。runtime 保持
`persist/plaintext`，本轮没有为验收临时启用 `active`。

## 实现证据

| 单元 | Android | iOS | 状态 |
| --- | --- | --- | --- |
| N1 FFI 与命令封装 | `1b4c49b0`、`c06c4056` | `29f75d47` | 已实现 |
| N2 安全状态存储 | `801d0bc7` | `71fa0f76` | 已实现 |
| N3 设备生命周期 | `9695150b` | `dbd879cb` | 已实现 |
| N4 单聊协调器 | `b51f2315` | `6d66e830` | 协调边界已实现，未挂聊天主链 |
| N5 多设备与群成员变化 | `2ba81b95` | `19d73b61` | 已实现并有平台单测 |
| N6 附件与外围边界 | `94a62c05` | `565432ab` | 已实现并有平台单测 |

## 2026-08-05 验收结果

| 门禁 | 结果 | 说明 |
| --- | --- | --- |
| `make e2ee-core.check` | 通过 | 共享核心检查通过 |
| `make e2ee-core.check.targets` | 通过 | host/Android/iOS/WASM 四目标构建通过 |
| Android JVM 单测（JDK 21） | 通过 | N4-N6 纳入全量测试；Gradle 构建成功 |
| `cd ios-app && swift test` | 通过 | 183 项通过，7 项 live 按配置跳过 |
| `make h5-app.test.unit` | 通过 | 261 项通过，8 项按配置跳过 |
| API E2EE marker scan | 通过 | DB/Redis/Push marker 集成测试通过 |
| `scripts/scan-e2ee-log-denylist.sh` | 通过 | 419 条日志调用，敏感字段命中 0 |
| `make test.all` | 未通过 | E2EE/API/Android/iOS 已通过；既有 Desktop 下载目录测试 1 项失败 |
| `make test.live` | 未通过 | Android 与 iOS 普通 live 通过；Admin 登录页 404 console error 阻断后续 |
| `make e2ee-core.test.wasm` | 未通过 | wasm-pack ChromeDriver 148 启动后返回 HTTP 404 |
| Android x iOS x H5 E2EE live | 未执行 | 仓库缺少三端驱动，且原生聊天主链尚未挂载协调器 |

## 已确认的非 E2EE live 证据

- Android 真实后端聊天/好友 smoke 通过。
- iOS 认证、WebSocket、聊天、好友、群管理、媒体 smoke 全部通过。
- 这些用例走普通消息链，只能证明 API 与原生客户端基础联调，不计入 D7 的
  E2EE 三端互解证据。

## 阻断与后续

1. 将 `E2eeDirectMessageCoordinator` 接入 Android/iOS 的发送、历史加载与
   WebSocket 入站主链，并保持 runtime fail closed。
2. 新增可重放的 Android x iOS x H5 三端 live 驱动，覆盖双向互解、重启恢复、
   离线补拉、重复帧、损坏密文、设备撤销和 epoch 推进。
3. 修复或锁定 Chrome/ChromeDriver 版本后重跑 Native-WASM fixture；fixture
   仅作为字节级互操作补充，不能替代真实三端 live。
4. 处理 Desktop 下载目录测试隔离问题与 Admin live 的 404，再重跑
   `make test.all` 和 `make test.live`。
5. 三端 E2EE live 与 marker 抽检同时通过后，才能提交 U7 P0-1 关闭重审。
