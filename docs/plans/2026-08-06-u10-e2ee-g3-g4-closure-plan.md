---
title: "security: U10 E2EE G3-G4 最终收口执行计划"
date: 2026-08-06
type: security
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code-and-operations
status: active
current_unit: G3
current_checkpoint: G3.2a
verdict: no-go
last_progress_update: 2026-08-06
supersedes: docs/plans/2026-08-06-u10-e2ee-release-gate-final-plan.md
---

# security: U10 E2EE G3-G4 最终收口执行计划

## 1. 唯一执行结论

本文是 U10 E2EE 剩余工作的**唯一 active 计划、进度总账和会话恢复入口**。
此前计划仅保留产品契约、实现过程与验收证据，不再派发任务。

- 唯一剩余链路：`G3.2a -> G3.2b -> G3.3 -> G4.1 -> G4.2 -> G4.3`。
- 当前 checkpoint：`G3.2a`，完成并提交 H5 path-prefix 候选部署支持。
- 当前裁决：生产 E2EE 保持 **No-Go**。
- 当前运行边界：保持 `content_audit_mode=plaintext`、`persist/plaintext` 和
  `security_review_approved=false`。
- 禁止扩展 E2EE API、修改已有 migration、触碰 `im-test-1` 旧主数据库，或把
  dev server 结果冒充真实候选部署证据。

## 2. 已完成事实

以下范围已经完成并推送，后续只在 G4 从干净基线重放门禁，禁止重做实现：

| 范围 | 状态 | 权威证据 |
| --- | --- | --- |
| N1-N7 原生双端接入与三端 E2EE live | 完成 | `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` |
| U7 P0-1 客户端主链 | 关闭 | 三端互解、附件、恢复、rekey、撤销与泄漏检查 |
| G1 / U7 P0-2 备份、灰度与回滚 | 关闭 | `docs/reviews/2026-08-05-u10-e2ee-backup-rollout-drill.md` |
| G2 / U7 P0-3 六端供应链门禁 | 关闭 | `docs/reviews/2026-08-06-u10-e2ee-supply-chain-review.md` |
| G3.1 H5 静态发布安全门禁 | 完成 | `docs/reviews/2026-08-06-u10-e2ee-h5-release-g3-1.md` |

G3.1 实现 commit 为 `cf05af8a`，文档 commit 为 `4a06f61b`。H5 type-check、
262 项 unit、release 正负场景、严格 CSP、11 个资源摘要和 9 个实际响应头均已
通过；独立复审为 P0=0、P1=0。

## 3. 当前工作区恢复点

`G3.2a` 已存在未提交实现，继续执行时必须保留并在当前源码基础上审查：

- `Makefile`
- `h5-app/vite.config.ts`
- `scripts/h5-release-security.ts`
- `scripts/h5-release-server.ts`
- `scripts/h5-release-http-check.ts`
- `tests/scripts/test-h5-release-security.ts`

该改动为真实测试域名的 `/h5-candidate/` path-prefix 部署增加
`VITE_BASE_PATH` / `H5_RELEASE_BASE_PATH` 绑定，并把 `base_path` 纳入 manifest、
资源路径、SPA fallback、私有文件阻断和负向测试。已知本地结果：

- `make h5-app.release.test`：18 个场景通过。
- `make h5-app.check`：通过。
- `/h5-candidate/` production build、finalize、HTTP check：通过。
- 候选绑定 commit：`4a06f61b48dd4a4e55ebfac4effb7a2008fa5912`。

上述结果必须在提交前重新核验；计划文档提交不得夹带这些实现文件。

## 4. 剩余执行队列

### G3.2a Path-prefix 候选支持

**输入：** 第 3 节列出的未提交实现。

**执行：** 审查 base path 的规范化、路径越界、SPA fallback、私有 artifact、根路径
404 与 manifest/构建产物绑定；修复发现的问题，不扩大到通用部署框架。

**验收：**

```bash
make h5-app.release.test
make h5-app.check
H5_RELEASE_BASE_PATH=/h5-candidate/ make h5-app.release.build
git diff --check
```

**提交边界：** 仅提交 path-prefix 实现与测试，使用独立 Conventional Commit 并
立即 push。完成后更新 `current_checkpoint` 为 `G3.2b`。

### G3.2b 真实 HTTPS 与浏览器安全验收

**候选地址：** `https://im-test-admin-1.codelib.cc/h5-candidate/`。

**部署：**

1. 通过 `ssh im-test-1` 备份 `/etc/caddy/Caddyfile`。
2. 上传已验证的 `h5-app/dist` 到临时目录 `/srv/redcode-h5-candidate`。
3. 仅在 Admin host 增加 `handle_path /h5-candidate/*`，响应头必须与候选
   `security-headers.json` 一致；先执行 `caddy validate`，再 reload。
4. 不替换 Admin 根路径、不新增域名或证书、不修改 API runtime gate。

**验收：**

- 真实 HTTPS/TLS、HTML、JS、SPA fallback 和 9 个响应头符合候选 manifest。
- `release-manifest.json`、`security-headers.json` 等私有 artifact 返回 404。
- 隔离浏览器 Console 无 CSP violation，Network/Console/log 无敏感 marker。
- IndexedDB wrapping key 为 AES-GCM 256 且 `extractable=false`。
- IndexedDB、OPFS、Cache Storage 不出现 plaintext marker。
- 状态损坏、身份变化、未知 epoch、解密失败均 fail closed，不回退 plaintext。

生产候选只证明真实部署、CSP、Network 和 Console；WebCrypto 与 fail-closed 可组合
现有真实实现的浏览器测试及单测证据，但禁止用 dev source dynamic import 冒充
production bundle 行为。

**强制清理：** 恢复原 Caddyfile并 reload，删除远端临时候选目录和本地隔离浏览器
profile；复核 Admin 根路径正常、候选路径不可访问、runtime 仍为
`persist/plaintext`。任一清理失败均停在 G3.2b。

### G3.3 关闭 U7 P0-4

新增 `docs/reviews/2026-08-06-u10-e2ee-h5-release-security-review.md`，记录候选
commit、资源摘要、部署窗口、实际响应头、浏览器证据、fail-closed 结果和清理
证据。同步 U7 review、任务总账和本文；只有独立复核无 P0/P1 时关闭 P0-4。

**提交边界：** 验收报告与状态文档独立 commit 并 push，然后进入 `G4.1`。

### G4.1 独立复审

分别从 correctness、security、reliability、testing 四个视角复审 G1-G3。报告必须
给出可定位证据；发现 P0/P1 时回到最早失败 checkpoint 修复并重新验收，不进入
G4.2。

### G4.2 干净基线全量重放

在无未提交源码改动的基线上依次执行：

```bash
make supply-chain.check
make api.test
make e2ee-core.check
make e2ee-core.check.targets
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make android-app.test
make ios-app.test
make h5-app.check
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.all
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home make test.live
```

结束后清理临时账号、容器、volume、浏览器 profile、候选静态目录、临时报告和
凭据；复核测试环境 runtime 回到 `persist/plaintext`。任何失败均保持 No-Go。

### G4.3 最终裁决

同步 U7 review、`docs/reports/task-list.md` 和本文，记录全部 P0、P1、门禁、环境
清理及 CI 状态。只有所有 DoD 均满足才可裁决 Go，否则明确保持 No-Go 并留下唯一
下一 checkpoint。最终文档使用独立 commit 并立即 push。

## 5. 停止与降级规则

- G3 任一静态、部署、浏览器或 fail-closed 验收失败：停在对应 checkpoint。
- 需要扩展服务端契约：返回产品契约计划评估，不在本计划直接修改 API。
- CRG、浏览器工具或 CI 不可用：降级到源码、`rg`、测试和运行时证据，但不得把
  缺失证据标记为通过。
- G4 存在未关闭 P0/P1、全量/live 失败或清理不完整：保持 No-Go。
- 测试候选窗口结束后必须恢复 `persist/plaintext` 和
  `security_review_approved=false`，无例外。

## 6. Definition of Done

- D1. 本文是唯一 active U10 计划，任务总账与 `current_checkpoint` 一致。
- D2. G3.2a path-prefix 候选支持已测试、独立提交并 push。
- D3. G3.2b 真实 HTTPS、响应头、浏览器存储和 fail-closed 验收全部通过且已清理。
- D4. U7 P0-4 有独立可复现报告并关闭。
- D5. G4 独立复审无未解决 P0/P1。
- D6. 干净基线全量与 live 门禁通过，临时资源和凭据已清理。
- D7. runtime 保持 `persist/plaintext`，`im-test-1` 旧主数据库未触碰。
- D8. 所有 checkpoint 均按最小闭环提交并 push；仅 D1-D7 全部满足才允许 Go。

## 7. 文档边界

| 文档 | 状态 | 用途 |
| --- | --- | --- |
| `2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | superseded | 产品契约与 API 边界 |
| `2026-08-05-u10-e2ee-native-clients-plan.md` 及收口计划 | complete/superseded | N1-N7 与原生验收历史 |
| `2026-08-06-u10-e2ee-release-gate-final-plan.md` | superseded | G2、G3.1 完成事实与设计历史 |
| 本文 | active | 唯一剩余任务派发、进度与恢复入口 |
