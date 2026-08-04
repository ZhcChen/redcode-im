---
title: U10 E2EE U5 单聊剩余状态机收口验收
date: 2026-08-05
status: partial
scope: h5-app,api
---

# U10 E2EE U5 单聊剩余状态机收口验收

## 结论

H5 单聊矩阵（U2 单元）收口完成并通过单元级验收：重启恢复、WebSocket 重复、
历史明文/新密文混排、根身份变化阻断、无 KeyPackage、过期 epoch、损坏密文和
runtime 切换均已 fail closed，无明文回退路径。新增 live 场景覆盖“同一设备连续
创建新私聊 -> 对端 KeyPackage 耗尽明确失败 -> 低水位补充后恢复”，待测试环境
显式切换 `persist/e2ee` 后执行。原生双端尚未接入 E2EE 协议链，按
`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 边界交由原生
E2EE 专项落地；因此 U5 整体保持 `partial`，生产 E2EE 继续 No-Go。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| 同消息 id 只解密一次 | `h5-app/test/e2ee-message-service.test.ts` | 同一密文帧连续 resolve 两次仅调用一次 `decryptText` |
| 历史明文/新密文混排 | 同测试文件 | 明文消息原样返回且不进入解密入口，密文消息正常解密 |
| 损坏密文 fail closed | 同测试文件 | 解密抛错后标记 `[无法解密的消息]`/`failed`，不缓存失败结果，`retryEncryptedMessage` 可重试 |
| 未知协议/版本 fail closed | 同测试文件 | `mls/v1/application` 之外的元数据不调用解密 |
| 根身份变化阻断 | `h5-app/test/e2ee-direct-message-coordinator.test.ts` | 身份变化后发送拒绝，`claimKeyPackage`/`submitControlMessage`/`sendEncryptedMessage` 均未调用，不写 pending |
| 对端无设备 | 同测试文件 | bootstrap 明确失败“联系人没有可用的 E2EE 设备”，不发任何控制消息 |
| 无 KeyPackage / 领取失败 | 同测试文件 | claim 失败向上明确抛出，不写 pending、不进入半提交状态，可安全重试 |
| 过期 epoch | 同测试文件 | 本地 epoch 与服务端 active epoch 不一致时拒绝发送，不持久化 pending application 状态 |
| bootstrap/控制消息恢复 | 同测试文件 | 中断后重放 commit/welcome 并 ack，`lastControlSequences`/`lastCommitMessageIds` 正确推进 |
| WS 重复展示 | `h5-app/test/chat-detail-store.test.ts` | 同一密文 WS 帧两次只解密/展示一次 |
| runtime 冲突不自动重发 | 同测试文件 | `40902` 冲突仅刷新 runtime，消息保持 failed，不自动转明文端点重发 |
| E2EE 发送链路 | 同测试文件 | `prepareText` 先于乐观消息，`retryPendingSend` 使用加密端点 |
| 同设备连续新会话 live | `h5-app/test/e2ee-live-backend.test.ts` | 新增场景：同一设备两个新会话成功；第三个会话因对端 KeyPackage 耗尽明确失败（epoch 保持 0）；`topUpKeyPackages` 补充后恢复双向互解，服务端原始历史无明文 marker |
| H5 全量回归 | `make h5-app.test.unit` | 232 项通过、8 项跳过 |
| 类型检查 | `make h5-app.check`（`vue-tsc --noEmit`） | 通过 |

## 实现边界

- 本次未修改生产协议代码：U2 依赖的 pending operation 三态、按消息 ID
  双重去重、`mls/v1/application` fail closed 和 runtime 冲突处理在
  `h5-app/src/e2ee/direct-message-coordinator.ts`、
  `h5-app/src/services/message-service.ts`、`h5-app/src/stores/chat-detail.ts`
  已具备，本单元以自动化测试把 R3/R4 矩阵固化为回归门禁。
- `topUpKeyPackages` 是设备生命周期能力（KTD2），本次在 live 场景显式调用以
  验证“补充后第二个新会话可建立”；进入前台/周期自动触发尚未在产品代码接线，
  与原生 E2EE 专项一并落地，不改变“页面只消费库存状态”的设计边界。
- H5 威胁模型保持受限；WS 去重由消费方（chat-detail store + message-service
  缓存）保证，websocket-service 仅做连接与事件分发。
- 历史 Flutter 跨端联调证据随 `app/` 下线不可复跑，仅作协议基线参考。

## 环境说明

- live 场景默认跳过（`H5_APP_E2EE_LIVE_ENABLED !== true`）；执行前必须显式
  切换 `persist/e2ee`，结束后读取 `/settings/general` 恢复 `persist/plaintext`，
  不得把 runtime 切换嵌入默认测试链。
- Android 测试需 `JAVA_HOME=<zulu-21>`（仓库默认 JDK 26 与 Gradle 8.12 不兼容）。

## 保持阻断

- 原生双端 E2EE 单聊协议链未接入（待原生专项）。
- 多设备、群聊、附件、Admin 门禁与独立安全审查未完成；U5 结论不改变生产
  No-Go 状态，开发 runtime 保持 `persist/plaintext`。
