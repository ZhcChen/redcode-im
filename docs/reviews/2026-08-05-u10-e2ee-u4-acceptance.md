---
title: U10 E2EE U4 安全存储与身份信任独立验收
date: 2026-08-05
status: partial
scope: h5-app,e2ee-core,android-app,ios-app
---

# U10 E2EE U4 安全存储与身份信任独立验收

## 结论

H5 侧 U4 安全存储与身份信任门禁通过独立验收：账号隔离、注销销毁、损坏状态
fail closed、身份 TOFU/变化阻断与跨端安全码均有自动化证据，且不依赖已废弃的
Flutter 实现。原生双端（`android-app/` / `ios-app/`）当前尚未接入 E2EE 协议
状态与安全存储，按
`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 边界交由后续
原生 E2EE 专项落地；因此 U4 整体保持 `partial`，生产 E2EE 继续 No-Go。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| H5 安全存储 | `h5-app/test/e2ee-secure-state-storage.test.ts` | 14 项 E2EE 存储/信任测试全通过 |
| 账号隔离 | 同测试文件 | `account-a` 状态不可被 `account-b` 读到，localStorage 零写入 |
| 注销销毁 | 同测试文件 | `delete()` 后密文与 wrapping key 均不可恢复；设备 profile、pending operation 随账号清理 |
| 损坏状态 fail closed | 同测试文件 | 密文/信任记录篡改后抛 `E2eeStateCorruptedError`，不返回明文 |
| 包装密钥 | 同测试文件 | wrapping key `extractable=false`，`exportKey('raw')` 被拒绝 |
| 能力缺失 | 同测试文件 | 无 IndexedDB / 无 WebCrypto 时抛 `E2eeStorageUnavailableError`，不降级普通存储 |
| 身份 TOFU/变化阻断 | `h5-app/test/e2ee-identity-trust.test.ts` | 首次信任、重复信任、身份变化阻断、显式重信任、未信任发送拒绝均通过 |
| 跨端安全码 | 同测试文件 | H5 安全码与 Flutter 对称向量一致（`C05E 7601 ...`），账号顺序无关 |
| 共享核心 | `make e2ee-core.test` | host 4 项（空状态往返、C ABI 校验、未知版本/截断拒绝、确定性导出）通过 |
| H5 全量回归 | `make h5-app.test.unit` | 218 项通过、7 项跳过 |
| 浏览器 smoke | `make h5-app.test.e2e` | 9 项全通过，含 e2ee-core WASM 初始化与损坏状态校验 |
| iOS 回归 | `make ios-app.test` | 154 项通过、7 项跳过（当前无 E2EE 协议用例） |
| Android 回归 | `JAVA_HOME=zulu-21 make android-app.test.unit` | 通过（仓库 Gradle 8.12 不支持 JDK 26，需 JDK 21 运行） |

## 实现边界

- 原生双端当前仅有基础安全存储设施（Android Keystore KeyValueStore、
  iOS Keychain 基础设施），没有 MLS provider state、设备身份、KeyPackage 或
  加密消息链；U4 原生侧验收在原生 E2EE 专项接入后补齐，本记录不虚报完成。
- H5 威胁模型保持受限：不抵抗已攻陷同源 Origin、运行时 XSS 或恶意扩展；
  发布前必须满足严格 CSP、依赖锁定与完整性检查，条件不足时 H5 保持 No-Go。
- 历史 Flutter 证据（`app/test/core/e2ee_secure_state_storage_test.dart` 等）
  随 `app/` 下线不可复跑，仅作协议基线参考；U4 独立证据以 H5 自动化测试为准。

## 环境说明

- Android 测试命令在默认 `java` 为 JDK 26 的本机会失败（Gradle 8.12 不支持），
  需显式 `JAVA_HOME=<zulu-21>` 后执行 `make android-app.test.unit`。

## 保持阻断

- 原生双端 E2EE 安全存储与身份信任验收未完成（待原生专项）。
- KeyPackage 低水位库存、单聊剩余矩阵、多设备、群聊、附件、Admin 门禁与
  独立安全审查均未完成；U4 结论不改变生产 No-Go 状态。
