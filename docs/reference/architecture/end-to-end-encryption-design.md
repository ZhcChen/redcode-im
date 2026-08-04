# RedCode IM 端到端加密架构

## 文档状态

- 协议候选：OpenMLS 0.8.1，实现 RFC 9420（MLS 1.0）。
- U1 隔离 PoC：已通过，证据见 `docs/reviews/2026-08-04-u10-e2ee-u1-openmls-poc.md`。
- U4 安全存储与身份信任：H5 侧已独立验收（`docs/reviews/2026-08-05-u10-e2ee-u4-acceptance.md`）；
  原生双端待原生 E2EE 专项接入后补齐，整体保持 partial。
- 生产发布：No-Go。U2-U9 与独立安全审查完成前，不得启用 E2EE 生产模式。
- 实施计划：`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
  （承接 `2026-08-04-001` 完整契约与 U1-U3 基线）。

本文替代旧版手写 X3DH、Double Ratchet 和 Sender Keys 设计。RedCode IM 不自行实现密码协议、密钥日程或密码原语，也不使用无法在原生双端（JNI / xcframework）与 H5 浏览器共享的独立协议实现。

## 安全目标与边界

### 保护内容

- 文本、富消息业务内容与附件内容。
- 每台设备的 MLS 私有状态、签名私钥和本地身份信任记录。
- 新设备批准与身份变化确认所依赖的本地凭据。

### 不隐藏的元数据

服务端仍可观察账号、房间、设备、成员关系、时间、消息大小、对象 key、在线状态和投递结果。E2EE 不等于匿名通信，也不隐藏流量特征。

### H5 威胁模型

H5 E2EE 不抵抗已攻陷的同源 Origin、运行时 XSS 或恶意浏览器扩展。这些攻击可以读取 WASM 内存中的明文。H5 发布前必须具备严格 CSP、依赖锁定、完整性检查，以及用 WebCrypto 非导出 wrapping key 加密的 IndexedDB 状态；条件不足时 H5 保持 No-Go。

### 服务端职责

服务端负责认证、设备归属、房间成员事实、协议版本、membership revision、epoch、幂等、控制消息队列和密文投递。服务端不得生成客户端 MLS 私钥、伪造设备凭据、解密消息或静默把失败请求改发明文。

## 协议与共享核心

### 单一实现

`e2ee-core/` 是唯一协议核心：

- Android 通过稳定 C ABI / JNI 调用 `.so`，iOS 通过 `xcframework` 调用。
- H5 通过 `wasm-bindgen` 调用同一 Rust 核心。
- API 只独立解析 RCML envelope 头与非敏感路由 metadata，不运行 OpenMLS，也不持有群密钥。
- OpenMLS 与 provider 版本必须精确锁定，不跟随 RC 或 `main`。

单聊按“两名账号的所有已批准设备组成的 MLS group”处理，群聊按“房间内所有成员账号的已批准设备组成的 MLS group”处理。每台设备对应独立 leaf，不按账号共享协议私钥。

### RCML v1 envelope

所有 Welcome、Commit 和 application message 使用相同二进制外层：

```text
magic           4 bytes   "RCML"
version         u16 BE    1
kind            u8        1=application, 2=commit, 3=welcome
payload_length  u32 BE    最大 16 MiB
payload         bytes     OpenMLS TLS serialized message
```

解析规则：

- magic、version、kind 和长度必须严格匹配。
- 未知版本、未知 kind、截断、尾随字节和超限 payload 均 fail closed。
- API metadata 的 `version` 与 `content_type` 必须和 envelope 头一致。
- 不允许通过 metadata 选择自定义算法、nonce、Ratchet 或密码套件。

## 身份与设备信任

### 账号根身份

- 首台设备建立账号根身份，并产生可展示的安全码/二维码指纹。
- 新设备必须由现有可信设备或独立恢复凭据批准。
- 普通登录 token 不能静默替换账号根身份。
- 联系人首次身份采用 TOFU；后续根身份变化必须阻断发送，直到用户核验或明确重新信任。

### 设备生命周期

目标设备状态至少包括：

```text
pending_approval -> active -> revoked
```

- `pending_approval` 不能发布 KeyPackage 或接收新控制消息。
- `active` 才能作为 MLS leaf 参与房间。
- `revoked` 立即停止领取 KeyPackage 和控制消息，并触发相关房间推进 epoch。
- 撤销不承诺删除设备已持有的历史密钥，但撤销设备不得解密后续 epoch。

### KeyPackage

- KeyPackage 由设备本地生成并签名，服务端只保存公开材料。
- 发布、领取和消费均带协议版本、有效期和幂等键。
- 领取使用事务和 `FOR UPDATE SKIP LOCKED`，同一个一次性 KeyPackage 不能被并发重复消费。
- 服务端必须校验设备归属、批准状态、撤销状态和大小限制。

旧 `e2ee_identity_keys`、`e2ee_signed_pre_keys`、`e2ee_one_time_pre_keys` 属于 X3DH 假设，不作为 MLS 事实源。U3 使用新增 migration 建立新模型，不修改历史 migration。

## 消息契约

### 加密发送请求

`POST /rooms/:room_id/messages/encrypted` 的当前 RCML v1 请求：

```json
{
  "encrypted_content": "<base64 RCML envelope>",
  "encryption_metadata": {
    "protocol": "mls",
    "version": 1,
    "epoch": 1,
    "sender_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "content_type": "application",
    "control_message_id": "018f5be3-3277-7d45-a6f3-bd2ebc89f321"
  }
}
```

约束：

- 请求体与 metadata 拒绝未知字段。
- 客户端不得提交 `content_summary`；数据库、响应、WebSocket、会话列表和 Push 只使用固定 `[加密消息]` 占位。
- `sender_device_id` 必须是非 nil UUID；U3 接入后还必须属于当前账号且状态为 `active`。
- `epoch` 必须大于零；U3 接入后 application 只接受房间当前 active epoch。
- `control_message_id` 是可选的控制消息引用，不包含明文摘要或密钥。
- API 只存储和透传完整 RCML bytes，不解包 OpenMLS payload。

### 历史共存

历史明文消息与新密文消息可以共存。客户端必须根据每条消息是否存在合法 RCML envelope 判断渲染方式，不能根据当前全局开关猜测历史消息格式。关闭 E2EE 只影响新发送，不删除密文或密钥状态。

## 核心流程

### 设备初始化

1. 客户端本地生成账号/设备凭据和 KeyPackage。
2. 私有状态由平台安全边界加密保存。
3. 设备提交公开凭据、协议版本和 KeyPackage。
4. 服务端完成归属与批准校验后发布公开材料。

### 首次会话

1. 发送设备读取房间成员事实和所有 active 设备。
2. 为缺失 leaf 的设备原子领取 KeyPackage。
3. 核心生成 Welcome/Commit，服务端按 membership revision 排序投递。
4. 合法设备处理控制消息并确认 epoch ready。
5. 发送端才生成 application message；任一步失败均保留草稿且不改发明文。

### 离线恢复

- 接收端按服务端序号处理 Welcome、Commit、application。
- 重复消息必须幂等，不重复展示。
- 收到未来 epoch 时先失败并补拉缺失 Commit，补齐后重试。
- 状态损坏、未知版本或无法补齐时显示可恢复错误，不清空密文，不降级明文。

### 成员和设备变化

- 房间成员变化产生新的 `membership_revision`，不直接伪装成加密状态已就绪。
- 合法成员设备提交绑定该 revision 的 Commit。
- Commit 激活前，UI 显示 rekey pending，新 application 发送被阻断。
- 新成员默认不能解密加入前历史；若产品需要共享历史，必须另行设计显式标准流程。
- 成员退出、管理员移除或设备撤销后必须推进 epoch，旧 leaf 不能读取新消息。

## 平台状态存储

### 原生双端（Android / iOS）

- MLS provider state 作为不透明 bytes 保存。
- iOS 使用 Keychain 保护 wrapping key；Android 使用 Keystore 保护 wrapping key。
- 普通 SQLite（GRDB）、SharedPreferences、日志和崩溃上报不得出现私钥或未包装状态。
- 账号切换按账号和设备命名空间隔离；注销销毁对应句柄与本地状态。

### H5

- IndexedDB 只保存加密后的 provider state。
- wrapping key 由 WebCrypto 生成且 `extractable=false`。
- 禁止把私钥、原始 state 或明文写入 localStorage、sessionStorage、普通日志或 Cache Storage。
- WebCrypto 或 IndexedDB 不可用时明确报告 E2EE 不可用。

## 附件

- 每个附件生成独立随机 DEK 和 nonce。
- 客户端先流式加密临时文件/Blob，再上传 S3-compatible 对象存储。
- AEAD associated data 绑定 room、message、object key 和内容类型。
- 对象存储只接收密文；DEK 与必要参数放入 MLS application payload。
- 重试不得复用 nonce；下载后先校验再解密。

## 运行模式与产品降级

生产启用采用 `prepare -> active` 状态机，不允许一个立即生效的布尔开关：

- `prepare` 检查最低客户端版本、active 设备覆盖、KeyPackage 库存、协议版本和房间 rekey 状态。
- 只有预检全部通过才原子进入 `active`。
- `plaintext` 模式拒绝加密发送，`active e2ee` 模式拒绝普通发送；冲突返回 `40902`。
- 回滚到 plaintext 只改变新发送，支持客户端仍可读取历史密文。

E2EE active 时：

- 服务端搜索与内容审核禁用。
- Push 不包含正文或附件预览。
- 服务端引用摘要和转发摘要禁用；客户端重新加密内容。
- 举报只上传用户明确选择的明文证据，并给出可见确认。
- `relay_only + e2ee` 不保存历史或离线 Push 内容快照。

## 失败语义

以下情况必须 fail closed：

- 未知 RCML/OpenMLS 版本或 kind。
- sender device 不属于当前账号、未批准或已撤销。
- 房间成员权限失效、membership revision 冲突或 epoch 过期。
- KeyPackage 缺失、重复消费或签名无效。
- 身份指纹变化未确认。
- 本地状态损坏、控制消息缺口无法补齐或安全存储不可用。
- E2EE 模式与发送端点不一致。

错误处理必须保留草稿和原始密文以便重试，但不得记录私钥、provider state、明文 marker 或附件 DEK。

## 验证与发布门禁

最低验证包括：

- Host、iOS、Android、WASM 构建。
- 原生双端 JNI/xcframework 和 Chrome WASM runtime。
- Native/WASM 双向状态接续。
- 双向单聊、双方多设备、三成员群聊、重启、重复、乱序和离线恢复。
- 成员移除和设备撤销后的新 epoch 拒绝。
- 数据库、Redis、日志、Push、WebSocket 和对象存储泄漏扫描。
- 依赖许可证、SBOM、漏洞扫描及独立安全审查。
- prepare/active 灰度、最低版本阻断、混合 API 版本和回滚演练。

U9 独立安全审查给出 Go 前，生产 E2EE 始终保持 No-Go。
