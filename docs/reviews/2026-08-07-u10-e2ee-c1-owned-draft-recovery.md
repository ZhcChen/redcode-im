# U10 E2EE C1 owned draft 跨执行恢复验收

日期：2026-08-07

## 结论

C1 通过。`REL-P1-01` 已关闭，correctness、security、reliability 三个独立上下文最终
复验均为 `P0=0/P1=0`。生产 E2EE 仍保持 **No-Go**，后续进入 C2 新候选、全量回归与
Release evidence。

## 实现证据

- draft 稳定身份绑定 repository、tag、candidate SHA、candidate marker 与 transaction
  marker；单次 owner 只用于当前事务 cleanup 和审计。
- Release 状态通过 GitHub REST 读取并校验 database ID、ETag、draft、tag、target 与
  body；仅明确 HTTP 404 允许进入 create，其他查询错误 fail closed。
- DELETE 绑定 database ID 和 `If-Match`；仅 `408/429/5xx` 有界重试，`400/409/412`
  及其他错误立即停止。
- create/upload/edit 均显式绑定 `GITHUB_REPOSITORY`；非 GitHub Actions 直接调用必须
  显式提供 `RELEASE_OWNER_TOKEN`。
- publish 服务端成功但客户端超时时，重新读取同一 transaction；仅已发布且完整身份
  匹配时确认成功。

## 自动化验证

```text
bash tests/scripts/test-release-reliability.sh  PASS（17 个场景）
make supply-chain.workflow.test                 PASS
make tests.tooling                              PASS
bash -n                                         PASS
git diff --check                                PASS
```

覆盖正常发布、即时 cleanup、跨 run orphan 恢复、foreign/published/different candidate
拒绝、API 500、瞬时 DELETE、重试耗尽、publish race、draft ETag race 和 ambiguous
publish。

## 隔离 GitHub API rehearsal

隔离私有仓库：`ZhcChen/redcode-im-release-rehearsal`

测试源 SHA：`7e70a7b910f224f53e0fcc60c92e6d53a2411c26`

一次性 tag 前缀：`v0.0.0-recover-20260807002708`、
`v0.0.0-race-20260807002708`

结果：

- 手工建立同 candidate orphan draft 后，当前脚本成功识别、删除、重建、上传 1 个
  fixture asset 并发布；服务端状态为 `draft=false`，target SHA 完全一致。
- 对同一 release ID 读取旧 ETag 后发布，再携带 stale `If-Match` 执行 DELETE；GitHub
  返回 `HTTP/2.0 400 Bad Request`，命令非零，published Release 保留。
- 实现和 mock 已按真实 `400` 语义调整为立即 fail closed，而不是重试。
- rehearsal 结束后复核 `release_count=0`、`tag_count=0`。专用私有仓库保留供 C2/C4
  重放，不承载正式资产。

## 独立审查

| Lens | P0 | P1 | P2 | 结论 |
| --- | ---: | ---: | ---: | --- |
| correctness | 0 | 0 | 0 | pass |
| security | 0 | 0 | 0 | pass |
| reliability | 0 | 0 | 2 | pass；P2 为直接调用需外部串行化、live rehearsal 需持久化 |

reliability 的两个 P2 不阻断 C1：正式 workflow 已按 repository/tag 串行，真实 rehearsal
已执行并由本文持久化；脱离 workflow 的调用仍按 KTD-2 限定为测试或人工单实例恢复。
