---
title: "feat: U10 E2EE 原生双端接入专项执行计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: active
---

# feat: U10 E2EE 原生双端接入专项执行计划

## Goal Capsule

- **目标：** 把 E2EE 客户端能力接入 `android-app/` 与 `ios-app/`，复用
  `e2ee-core` 的 C ABI（不重写 MLS），对齐 H5 已验收的安全存储、设备生命
  周期、单聊/多设备/群聊/附件语义，形成原生双端 × H5 跨端互解，关闭
  `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` P0-1（原生双端
  E2EE 专项未完成）。
- **前置状态：** U0-U7 完成；服务端设备/KeyPackage/控制消息/epoch/门禁 API
  全部就绪；`e2ee-core` 已导出 `rc_e2ee_*` C 函数与 RCCQ/RCCR 命令协议；
  H5 侧 `h5-app/src/e2ee/` 十模块为可移植参考实现。
- **发布约束：** 本专项只关闭客户端侧 P0；生产 E2EE 仍需 U7 重审
  （备份/灰度演练、CI 漏洞扫描、许可证核验）通过后才可 Go；期间 runtime 保持
  `persist/plaintext`，测试环境仅允许 prepare。

## 关键设计决策

- K1. **两端统一走 e2ee-core C ABI。** Android 用 `staticlib` + JNI 封装，
  iOS 用 `staticlib` + C 桥 + Swift 封装；命令字节协议（RCCQ/RCCR）与 H5
  WASM 路径一致，envelope/state 字节级互操作。
- K2. **协议状态加密落盘。** RCST 状态 blob 用 AES-GCM 加密后写入本地存储；
  Android 包装密钥存 Keystore、iOS 存 Keychain；明文状态与私钥不进入普通
  Room/SQLite/日志（对齐 H5 `secure-state-storage` 语义）。
- K3. **设备生命周期两端独立实现，语义对齐 H5。** 低水位库存查询、批量
  补充、账号级互斥与退避在原生端各自实现，不嵌入聊天页面；未批准/已撤销
  设备不得发布或解密。
- K4. **按 U10 顺序推进客户端能力。** 单聊（第二个新会话、重启、离线、重复、
  损坏、runtime 切换）→ 多设备批准/撤销 → 群聊成员变化 → 附件与外围边界；
  任一场景 fail closed，不得自动改发明文。
- K5. **跨端验收复用 fixture。** `e2ee-core/interop` 的
  `cross_runtime_fixture` 与 H5 live 用例作为互操作基线，原生端复用同一组
  group_id/state/message 验证字节级一致。
- K6. **不扩展服务端契约。** 本专项只消费 U1-U7 已提供的 API；发现契约缺口
  时先回到 `docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
  评估，不绕过门禁改协议。

## Implementation Units

### N1. 原生 FFI 集成与命令封装

- Android：`e2ee-core` 构建 `aarch64-linux-android`/`arm64-v8a` staticlib，
  `android-app/app/src/main/jniLibs` 接入；`E2eeCore` JNI 单例封装
  `rc_e2ee_*`，Kotlin `E2eeCommandClient` 实现 RCCQ 编解码。
- iOS：`e2ee-core` 构建 `aarch64-apple-ios` staticlib 或 XCFramework；
  `RedCodeCore/E2eeCBridge` 暴露 C shim，Swift `E2eeCommandClient` 封装。
- 测试：两端对 protocol version、state new/validate、command execute 往返、
  错误响应（RC=1）做单测；`make e2ee-core.check.targets` 保持通过。

### N2. 安全状态存储

- Android：Keystore 生成/读取包装密钥；AES-GCM 加密 RCST 状态写 Room blob；
  包装密钥缺失、密文篡改、版本不匹配一律 fail closed 并提示重新初始化。
- iOS：Keychain 保存包装密钥；CryptoKit AES-GCM 加密状态写 GRDB blob；
  同 fail closed 语义。
- 测试：存储往返、篡改失败、密钥缺失、账号切换/注销清理（对齐
  `h5-app/test/e2ee-secure-state-storage.test.ts`）。

### N3. 设备生命周期与 KeyPackage 补充

- 注册设备（平台/版本/构建上报）→ 安全保存 device profile → 查询库存 →
  低水位批量发布 → 首次/前台/周期补充 → 未批准/撤销设备禁用。
- 测试：首次补充、领取后补充、并发不超上限、撤销后发布失败、退避恢复。

### N4. 单聊直接消息

- 创建/恢复 MLS group、领取对端 KeyPackage、encrypt/decrypt、commit/welcome
  处理、WS 与历史统一解密入口、按消息 ID 去重、身份变化阻断、无 KeyPackage/
  过期 epoch/损坏密文明确失败、runtime 切换保留草稿。
- 测试：双端互发、第二个新会话、重启恢复、离线补拉、重复帧、历史混排。

### N5. 多设备与群聊

- 第二设备批准/撤销、撤销后 rekey；add/remove member、成员变化 commit/welcome
  消费、epoch 缺口补拉、旧成员不可读、新成员不可读历史。
- 测试：同账号两设备、三成员群、移除/加入后状态一致性。

### N6. 附件与外围边界

- 每附件随机 DEK/nonce 加密上传、下载后内存解密、AAD 绑定 room/part/object
  key；Push 占位、搜索/转发/引用明确降级；本地搜索只索引解密内容。
- 测试：附件往返与篡改失败、重试不复用 nonce、外围边界断言。

### N7. 跨端 live 验收与发布证据

- Android × iOS × H5 三端互解；DB/Redis/log/Push marker 抽检；`make
  android-app.test`、`make ios-app.test`、`make h5-app.test.unit`、API 全量
  回归；更新 `docs/reviews/` 与 U7 重审材料（P0-1 关闭证据）。

## Definition of Done

- D1. N1：两端 FFI 单测通过，`e2ee-core.check.targets` 四目标构建通过。
- D2. N2：状态加密落盘，密钥缺失/篡改 fail closed 有自动化证据。
- D3. N3：设备注册与 KeyPackage 低水位补充闭环，未批准/撤销设备被禁用。
- D4. N4：单聊第二个新会话、重启、离线、重复、损坏、runtime 切换全部
  fail closed，与 H5 字节级互解。
- D5. N5：多设备批准/撤销与群聊成员变化符合 R5-R8，撤销设备不能解密新 epoch。
- D6. N6：附件互解、篡改失败、nonce 不复用，S3/DB/log/Push 无明文。
- D7. N7：原生双端 × H5 跨端 live 通过，marker 抽检为零，U7 P0-1 关闭证据
  提交重审；生产 E2EE 仍保持 No-Go 直至 U7 其余 P0 关闭。
