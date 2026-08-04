---
title: U10 E2EE U1 OpenMLS 隔离 PoC 验收
date: 2026-08-04
status: passed
scope: e2ee-core
---

# U10 E2EE U1 OpenMLS 隔离 PoC 验收

## 结论

OpenMLS 0.8.1 协议候选通过 U1，可进入 U2 协议 envelope 与 API contract 设计。
该结论只解除协议候选的 PoC 门禁，不代表生产 E2EE 可以启用；正式消息链、数据库 schema 和 Admin 开关仍保持隔离，生产发布继续 No-Go。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| 固定依赖 | `e2ee-core/Cargo.toml`、`Cargo.lock` | OpenMLS 0.8.1 及 0.5.x provider 精确锁定 |
| Host 协议行为 | `make e2ee-core.test` | Alice/Bob 双向互解、重启恢复、重复拒绝、乱序 Commit 恢复、三成员增删均通过 |
| 成员移除 | `removed_member_cannot_decrypt_messages_from_the_new_epoch` | 被移除成员不能处理新 epoch 密文 |
| 目标构建 | `make e2ee-core.check.targets` | `aarch64-apple-ios`、`aarch64-linux-android`、`wasm32-unknown-unknown` 通过 |
| Flutter FFI | `make e2ee-core.test.flutter` | Flutter test 实际加载 Rust 动态库并读取协议版本 |
| Browser WASM | `make e2ee-core.test.wasm CHROMEDRIVER=<matching-driver>` | Chrome 内创建 MLS group 并完成 application message 加解密 |
| 状态互导 | 同一 WASM 门禁 | Native state -> WASM 解密并推进 -> Native 恢复并继续解密 |
| 日志约束 | WASM 门禁输出扫描 | 浏览器状态经随机 localhost 端口写入临时文件，日志无私钥状态 |

## 可重放说明

- `make e2ee-core.fixture.generate` 显式重新生成 Native fixture；普通测试不会改写 fixture。
- `make e2ee-core.test.wasm` 默认由 `wasm-pack` 获取驱动；本机存在多个 Chrome 时，应通过 `CHROMEDRIVER` 指定与实际优先 Chrome 完全匹配的驱动。
- 本机验收使用 Chrome for Testing 147.0.7727.57 与 ChromeDriver 147.0.7727.57。
- 状态 receiver 绑定 `127.0.0.1:0` 随机端口，测试结束后清理进程与临时文件，不向网络或测试日志暴露 provider state。

## 保持阻断

- 未接入 API、Flutter/H5 正式消息发送链或 Admin E2EE 开关。
- 未完成设备身份、KeyPackage、epoch 数据模型、安全存储、附件加密及发布灰度。
- U2-U9 与独立安全审查完成前，`content_audit_mode=e2ee` 仍为 No-Go。
