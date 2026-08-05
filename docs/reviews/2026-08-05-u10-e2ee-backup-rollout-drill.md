---
title: U10 E2EE G1 备份恢复与灰度回滚演练
date: 2026-08-05
status: complete
scope: api,deploy,h5-app,android-app,ios-app,rustfs,postgresql,redis
verdict: pass
production_verdict: no-go
---

# U10 E2EE G1 备份恢复与灰度回滚演练

## 结论

本文首轮 G1 结论曾判定通过并关闭 U7 P0-2；2026-08-06 的 G4.1 独立复审重新
打开恢复实例真实性和证据完整性。E1（原 U4.3）经两轮 E2 复核退回后已完成
E1.3 整改、真实重放、预审、提交与推送，但
U7 P0-2 仍等待 E2 四视角独立复核，不在本文提前重新关闭。

所有演练均在 `im-test-1` 的独立候选 PostgreSQL/Redis/API 栈执行，只复用 RustFS
网络和 bucket，未升级、清空或写入旧主库。生产 E2EE 仍为 **No-Go**。

## G4 整改 E1 验收（2026-08-06）

E1.3 最终成功 run `e1fix20260806g` 使用候选镜像
`redcode-im-api:g1-74d1231e`。candidate 新数据集经 custom-format backup 恢复到
独立 PostgreSQL 17/Redis/API 后，在同一 `127.0.0.1:18010` 窗口完成恢复与三端
full suite。

| 检查 | 结果 |
| --- | --- |
| candidate/restore 关键表 snapshot | 完整行计数与 digest `2c34ac950bee5a780988321a518d589d` 完全一致 |
| H5 同一协议状态跨恢复 | 历史密文可解密，恢复后新密文可发送并解密 |
| Android/iOS/H5 full suite | `6 passed | 1 skipped` |
| evidence | 恢复连续性 + 三端共 4 个房间、9 条加密消息、1 个加密附件；逐条绑定 room/message/marker/object |
| post-live snapshot | identities=18、devices=19、KeyPackages=379、epochs=12、messages=21、attachment commits=1 |
| DB | message-room-ciphertext 与 attachment commit/object-room 归属一致；可信 H5 runtime 的临时 HMAC 绑定 message/object/ciphertext；所有持久面 marker 为零 |
| Redis | 每个 evidence room 均有精确 `PUBLISH room:<uuid>`；SUBSCRIBE/payload 不计入；启动与末端 probe 均被捕获，MONITOR 与持久键无 plaintext marker |
| API log | plaintext/sensitive marker 为零 |
| Push | 本轮无 push queue 记录，明确记为 `not-observed-live`，未冒充占位验证 |
| RustFS | object 为 ciphertext-only，SHA-256 `98a5247b56dcf90bcc8acbb9f491f82a2974aa570e8d0e305813d37c1846d206` |
| source isolation | restore API 精确接入 restore-internal、run-scoped internal storage 与独立 ingress；不接入 `im-test-1-network`；owner/Internal/成员均运行时校验 |
| 退出清理 | candidate/restore container、volume、network、state、HMAC key、MONITOR、tunnel、18010 全部清零 |
| 旧主终态 | `persist/plaintext`；旧主未升级、停止或写入，因保持旧 schema 不存在候选审批表，无法进入 active |

Redis MONITOR 初次整改暴露了二进制采集缺陷：停止宿主 `docker exec` 会破坏重定向
日志，且含 protobuf/NUL 的输出不能安全装入 Bash 变量。最终实现先复制 run-scoped
不可变二进制快照，再停止采集，room/marker/sensitive 扫描全部直接针对文件执行；
probe、run id、缺 room 和 plaintext marker 均 fail closed。

E2 首轮四视角复核发现 snapshot 字段遗漏、观测启动过晚、证据可拼接、bytea
扫描失效、Redis 子串假阳性和顶层报告校验不足。实现提交 `cab9cbd6` 统一改为
完整行 digest、四场景九消息 proof、原始 bytea 全局扫描、精确 PUBLISH、持续 source
isolation watcher，并补齐归属错配、重复 proof、非法 run id/Push 和窗口中途连接等
负例。首次真实重放 `e1fix20260806a` 在 SQL expression 引号缺失处 fail closed，
cleanup 与旧主终验通过；修正后使用全新 run id 完成 `e1fix20260806b`。

E2 第二轮复核又发现附件 proof 可拼接、marker 可替换、离散 source 采样、Push
混合行和 MONITOR 旧日志问题。E1.3 提交 `d385c88b` 改为：

- 每 run 随机 HMAC key 绑定 message id、marker、ciphertext SHA-256、kind 与 object key；key 仅以 `0600` 临时文件在 H5/scanner 间传递并在 cleanup 删除。
- restore API 不再连接旧主网络；storage network 为 run-scoped internal 且仅含 API/RustFS，ingress 仅含 API，owner/Internal/成员集合均 fail closed 校验。
- Push 使用 `COALESCE` 逐行验证占位，缺字段、JSON null 与混合正文均拒绝。
- Redis MONITOR 在扫描前检查 PID，并发送/捕获末端 probe 后才复制不可变快照。

真实 run `e1fix20260806e` 因错误假设 E2EE 消息会把 object key 写入
`message_parts` 而 fail closed；协议核对确认 `/messages/encrypted` 使用
`deny_unknown_fields` 且只持久化占位 text part，object key 位于 MLS 密文内。
修正为可信 H5 runtime tuple + HMAC 与两个服务端可见归属面的组合证明后，run
`e1fix20260806f` 通过。补齐 Push null、末端 MONITOR probe 和网络属性/成员校验后，
使用全新 run `e1fix20260806g` 完成当前提交的最终重放。

第二轮复核的 P2（candidate 恢复前消息未处于 restore MONITOR/API log 窗口）按
证据边界关闭：该消息以密文进入 candidate snapshot，并在 restore snapshot、恢复后
history 解密和 restore DB marker 扫描中复验；restore MONITOR/API log 从 restore API
启动后覆盖恢复连续性后半段及 full suite。本文不把 restore 窗口表述为对已停止
candidate 瞬时流量的追溯，也不为此扩展第二套运行合同。

定向验证：

- `make e2ee.restore-compose.test e2ee.restore-control.test e2ee.restore-window.test e2ee.restore-boundary.test e2ee.restore-live.test e2ee.cross-client.isolated.test`：通过。
- `cd h5-app && bun run type-check`：通过。
- `bash -n`、`git diff --check`：通过。
- E1.3 control 9 个网络/cleanup 场景、boundary 22 个 proof/归属/Push/MONITOR 场景：通过。
- `shellcheck`：本机未安装，本轮未执行。

## 候选构建

| 项目 | 证据 |
| --- | --- |
| S3 presign 修复 | `ff830a4b` |
| 系统 provider 启动同步 | `9ee1285f` |
| RustFS typed NotFound | `74d1231e` |
| 最终镜像标签 | `redcode-im-api:g1-74d1231e` |
| 平台 | `linux/amd64` |
| 本地 image ID | `sha256:672fe0f171b2ae0fe7fb2c418092eb3fa961e19bef92418ba27fe27ca12d05dd` |
| 远端 image ID | `sha256:290a773a4d12ace10c7fa4bc11d0548efd3608c3d5f8a0b43379c1b325938b92` |
| 归档 SHA-256 | `c972c20118ce7177ad07bf039d990d75dd28fb0c5ec079e170aad6e00d72ea21` |

归档本地与远端 SHA-256 一致。最终候选 health/readiness 通过，系统 default
provider 为 `http://rustfs:9000`；随机缺失对象返回 `success=true/exists=false`。

## 三端 live

run `g1c-9ee1285f`：H5 驱动的 Android × iOS × H5 完整 live 6/6 通过，覆盖
双向文本、附件、恢复、撤销和 epoch 场景。

- evidence 共 3 个房间、7 条加密消息、1 个 RustFS 附件。
- attachment commit=1，pending device=0，33 台 active device 的可用
  KeyPackage 均不低于 10。
- DB/Push、120 个 Redis 持久键、API log、RustFS 4 个对象分片均未命中正文
  marker、DEK、nonce 或 RCST 等敏感字段。
- live 结束后通过 Admin API rollback，runtime 恢复 `persist/plaintext`，审批
  恢复 `false`。

## 备份恢复与灰度

最终 run `g1-full7-9ee1285f`，脱敏报告 SHA-256：
`3fe23bdb5ea8341daca0bfb20bca49003e714fc54ca6fe3d53388d0eba9cf982`。

| 检查 | 结果 |
| --- | --- |
| preflight migration/runtime/引用完整性 | 通过 |
| custom-format 归档可读 | 通过 |
| 1 KiB 损坏归档拒绝 | 通过 |
| 独立 PostgreSQL 17 恢复 | 通过 |
| 源库/恢复库计数、密文摘要、门禁和引用快照 | 完全一致 |
| `prepare -> active` readiness | 通过 |
| active 状态 API recreate | gate/audit mode 保持 E2EE |
| rollback | 恢复 `persist/plaintext` |
| 备份恢复耗时 | 7 秒 |
| rollout/rollback 耗时 | 13 秒 |
| API 停止窗口发送 `TERM` | 退出 143，API/plaintext 恢复，无 dump/临时资源 |

报告不包含 token、密码、私钥、DEK、nonce、正文或数据库/Redis 连接串。

## 故障注入与修复

真实演练在形成最终成功 run 前暴露并修复以下问题：

1. 旧候选将 `https://rustfs:9000` 物化到系统 provider；启动同步现只幂等更新
   `system-s3-runtime`，绝不覆盖管理员自定义 default。
2. `pg_restore -l /dev/stdin` 在 PostgreSQL 17 Alpine 不能读取 custom archive；
   改为隐式 stdin，并通过损坏归档反例验证。
3. 临时 PostgreSQL entrypoint 存在临时 server 窗口；readiness、restore 和 psql
   统一使用 `127.0.0.1` TCP，只连接最终实例。
4. command substitution 使 cleanup 状态停留在子 shell；备份/rollout 改为当前
   shell 执行，失败 trap 能看到 API、容器和 volume 状态。
5. gate 布尔值 `t/f` 不能直接拼 SQL；恢复时显式映射为 `TRUE/FALSE`，SQL 失败
   会向上返回。
6. 失败路径现在等待 API health 后 rollback，并默认删除 dump、损坏归档、临时
   恢复容器和 volume。

前三次失败演练均保持数据库 gate `plaintext`；发现审批恢复缺陷后立即强制恢复
为 `false`，再完成 `full7` 成功验证。

## 清理与边界

- live 夹具清理脚本使用 psql 变量和单事务；`%`/空前缀均 fail closed。
- 候选库真实清理后 users/devices/KeyPackages/rooms/attachment commits 均为 0，
  gate/provider 各保留 1 行。
- live RustFS object 通过 S3 DELETE 删除，物理分片为 0。
- 候选 Compose 栈、独立 PostgreSQL volume、恢复容器/volume、dump、报告、镜像
  归档、临时 token 和 SSH tunnel 已删除。
- 旧主环境未变更，清理后公网 `/healthz` 返回 `ok`。

## 验证

- `make api.test`：unit 188/188，全部 integration tests 通过。
- `rustfmt --check`：本轮 Rust 文件通过；全仓仍有与本轮无关的既有格式差异。
- `bash -n`：演练与夹具清理脚本通过。
- 远端 `docker compose config`：通过。
- `git diff --check`：通过。

## 后续门禁

进入 E2 restore 整改四视角全新独立复核。E2-E7 完成并给出最终裁决前，不得在生产
启用 E2EE。
