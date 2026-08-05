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

G1 通过，U7 P0-2 关闭。演练在 `im-test-1` 的独立候选 PostgreSQL/Redis/API
栈执行，只复用 RustFS 网络和 bucket，未升级、清空或写入旧主库。

生产 E2EE 仍为 **No-Go**：G2 供应链门禁与 G3 H5 发布安全报告尚未完成。

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

进入 G2 供应链安全门禁。G2、G3 与 G4 独立裁决完成前，不得在生产启用 E2EE。
