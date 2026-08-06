---
title: U10 E2EE E3 H5 production 安全存储验收
date: 2026-08-06
status: complete
scope: h5-app,release-browser-audit,restore-isolation,caddy
verdict: pass
candidate_commit: f6944a70fd314a90b82abf065649b3e679b1750b
run_id: e3prod20260806f
---

# U10 E2EE E3 H5 Production 安全存储验收

## 结论

E3 已完成。真实 production candidate 使用应用自身 `E2eeSecureStateStorage`、
IndexedDB `redcode-h5-e2ee-state` 和 production MLS runtime，在两个独立 Chrome
BrowserContext 中完成 UI 登录、不同 device identity 初始化、单聊加密发送和对端
解密。wrapping key 不可导出，AAD 篡改后 fail closed，未调用 encrypted endpoint，
也未降级到 plaintext endpoint。

本报告只关闭 E3，不构成生产 E2EE Go。E4 持久 evidence 已在后续提交关闭，唯一
active 计划当前位于 E5.1；生产继续保持 **No-Go**，`im-test-1` 旧主保持
`persist/plaintext`。

## 候选与运行身份

| 字段 | 值 |
| --- | --- |
| source commit | `f6944a70fd314a90b82abf065649b3e679b1750b` |
| run id | `e3prod20260806f` |
| candidate URL | `https://im-test-admin-1.codelib.cc/h5-candidate/` |
| API / WS | `/h5-candidate-api` / `/h5-candidate-api/ws`（同源隔离代理） |
| base path | `/h5-candidate/` |
| candidate files | 11 |
| manifest SHA-256 | `38765a36966b71497f26c965836a388e4d4d45564d0c6a353984daa540fa03d0` |
| browser evidence SHA-256 | `f55474d82afc9ba39ffa02904eb8b8f15e4c479b95f642065f82e0f433ba70` |

机器 evidence 位于忽略目录
`.artifacts/h5-release/f6944a70fd314a90b82abf065649b3e679b1750b-browser.json`。
文件只保存布尔断言、计数、路径、摘要和候选身份，不保存 marker、token、凭据、
CryptoKey 或原始 Console/Network 内容。

## Production 路径证据

- 两个独立 BrowserContext 通过真实候选 UI 登录，使用不同 device identity。
- 登录 bootstrap 初始化 MLS identity、device profile 和 KeyPackage，未使用测试后门。
- Alice 通过真实聊天 UI 发送加密消息，Bob 在真实 UI 解密并显示原文。
- production database 为 `redcode-h5-e2ee-state`；wrapping key 位于
  `wrapping-keys`，协议密文位于 `encrypted-states`。
- wrapping key `extractable=false`，`exportKey` 被拒绝，usages 仅含
  `encrypt/decrypt`。
- encrypted state 记录结构有效，secure state、IndexedDB、local/session storage、
  Cache Storage、OPFS 均未出现禁止值。
- 使用 device-profile 密文覆盖 protocol-state 制造真实 AAD mismatch；发送显示精确
  损坏提示并恢复草稿，encrypted/plaintext endpoint 调用计数均未增长。
- WebSocket 捕获 20 帧；Network URL、request/response body 和 WebSocket frame 扫描
  未发现 plaintext marker、密码或 token；page error 为 0。
- 首次 identity bootstrap 的两个精确 404 会产生 Chrome resource error；审计只在
  pathname 精确匹配两个动态审计用户且真实 response status 为 404 时识别为预期。
  同路径 500、其他路径、JS `console.error` 或任何敏感值仍 fail closed。

## 缺陷闭环

1. `e3prod20260806a` 在创建资源前发现远端路径默认值错误；`3faccae6` 改为真实
   `/root/redcode-im` 来源路径。
2. `e3prod20260806b` 在 API force recreate 后返回 plaintext。根因是空白库没有两个
   message runtime setting，`UPDATE` 命中 0 行；`1306da0c` 改为
   `INSERT ... ON CONFLICT DO UPDATE`，并增加重启后从持久状态恢复的合同测试。
3. `e3prod20260806c` 发现预期 identity 404 被泛化 Console error 门禁阻断，同时
   cleanup 将恢复后的 Admin 200 fallback 误判为候选残留；`e6711f3a` 增加脱敏
   console 诊断并按候选页面标识校验 cleanup。
4. `e3prod20260806d` 证明 error 仅来自两个精确 identity bootstrap 404；
   `ea03a917` 将豁免绑定到动态用户 pathname 和实际 404 response，不放宽其他错误。
5. `e3prod20260806e` 的 Chrome 审计通过，但 PostgreSQL 17 `pg_dump` 每次生成随机
   `\restrict/\unrestrict` token，导致旧主 schema digest 假漂移；`f6944a70` 仅在
   哈希前移除这两条会话控制行。三份连续 dump 的规范化摘要一致。
6. `e3prod20260806f` 从新 HEAD 重建候选并完整重放，所有行为、泄漏、冻结和 cleanup
   门禁同时通过。

## 自动化验证

- `make e2ee.restore-control.test`：13 个 control/network 场景与 snapshot 合同通过。
- `make e2ee.restore-compose.test e2ee.restore-window.test e2ee.restore-boundary.test`：
  restore 隔离、7 类 window cleanup、22 个 proof/bytea/PUBLISH/Push/MONITOR 场景通过。
- `make h5-app.release.candidate.test`：17 个 cleanup/recover 正负场景通过。
- `make h5-app.release.test`：21 个 release security 场景、25 个 browser contract
  mutation 和替代加密/数据库拒绝场景通过。
- `cd h5-app && bun run type-check`：通过。
- candidate build/finalize/check：11 个文件与 source commit 绑定，9 项 HTTP header
  检查通过。
- `git diff --check`、Bash syntax：通过。

## 环境终验

- run-scoped API/PostgreSQL/Redis container、volume、storage/ingress/internal network、
  state、远端临时目录和端口 `18010` 全部清零。
- candidate dist、upload staging、Caddy backup/temp config 与候选 route 全部清零；
  `/h5-candidate/` 已恢复为 Admin 页面，不再返回候选 H5 标识。
- 旧主公开 runtime 为 `persist/plaintext`，`e2ee_runtime_gate` table 仍 absent。
- 旧主规范化 schema digest 在审计窗口前后相同；脚本未停止、升级或写入旧主数据库。

## 下一步

E4 已完成。G3/E3 的持久脱敏机器证据已提交至
`docs/reviews/evidence/u10-e2ee/g3-h5-release.json`：subject commit 为
`f6944a70fd314a90b82abf065649b3e679b1750b`，evidence commit 为
`a383f788ee310211c60b137d16a4d75858520785`，文件 SHA-256 为
`415a311af78879396451ca95ef0e06f9bde1710b08dcf9ee198588f47e1a2d1a`。
该文件可在干净 checkout 中通过 `make e2ee.evidence.verify` 离线验证。

当前按唯一 active 计划进入 E5.1 真实 release workflow 证明；生产 E2EE 保持
**No-Go**。
