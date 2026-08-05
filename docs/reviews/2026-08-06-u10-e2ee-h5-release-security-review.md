---
title: U10 E2EE H5 发布安全最终验收
date: 2026-08-06
status: complete
scope: h5-app,caddy,release,webcrypto
verdict: pass
candidate_commit: a22b65e26d7ee28c407e2146275e24907358ae6c
---

# U10 E2EE H5 发布安全最终验收

## 结论

G3.2/G3.3 已完成，U7 P0-4 正式关闭。H5 production candidate 在真实 HTTPS、
Caddy path-prefix、严格 CSP、资源完整性、浏览器 WebCrypto、存储 marker、
fail-closed 组合证据及失败清理方面全部通过；最终 correctness、security、
reliability、testing 四视角复审均为 P0=0、P1=0、P2=0。

本报告只关闭 H5 发布安全阻断项，不构成生产 E2EE Go。生产继续保持 **No-Go**，
测试环境保持 `persist/plaintext`，最终裁决由 G4 完成。

## 候选身份

| 字段 | 值 |
| --- | --- |
| source commit | `a22b65e26d7ee28c407e2146275e24907358ae6c` |
| candidate URL | `https://im-test-admin-1.codelib.cc/h5-candidate/` |
| base path | `/h5-candidate/` |
| API / WS | `https://im-test-1.codelib.cc` / `wss://im-test-1.codelib.cc/ws` |
| manifest SHA-256 | `393d9efdac67e206728cea79cb33929848d6ef5e776b5faeb054e89aaa70c8a2` |
| headers SHA-256 | `c7fc863d8c0914b33edfa5378ee1d612a6deaf9800c374d2f5a45a6ad1caee6a` |
| browser evidence SHA-256 | `e75e9e79f38733244c723526a08f504ecd1499ad5312178ec7e0f1a882143eea` |
| Supply Chain Gate | run `31038235334`，success |

候选包含 11 个 manifest 文件。上传后在远端 staging 目录逐文件执行 SHA-256
校验并核对文件总数，通过后才原子切换为候选目录；浏览器审计又通过真实 HTTP
响应逐项核验所有公开资源的 bytes、SHA-256 和安全响应头。

## 实现与缺陷闭环

1. `da11a6c2` 增加 path-prefix manifest、构建、server 与负向门禁。
2. 首轮真实部署发现 Vue Router 未绑定 Vite base，页面空白；恢复环境后由
   `fb88ee9b` 改为 `createWebHistory(import.meta.env.BASE_URL)`。
3. 独立复审发现点路径段、单向 base 绑定、静态资源 SPA fallback、部署恢复和
   远端完整性证据缺口；`87f6c5e5` 增加 21 个正负门禁、受控 Caddy route、
   Chrome audit、远端逐文件摘要与失败自动清理。
4. `a22b65e2` 将入口、deep-link、全部公开资源和 404 响应纳入真实 Caddy headers
   检查，枚举全部 IndexedDB object store，并让审计数据库删除失败时 fail closed。

未向 production bundle 加入测试后门，也未使用 dev source dynamic import 作为
production 证据。

## 真实部署与浏览器证据

- TLS：HTTPS 校验成功，`ssl_verify_result=0`，浏览器 `isSecureContext=true`。
- 路由：入口加载后到达 `/h5-candidate/login`，deep-link reload 正常；Admin 根路径
  仍为“IM 管理后台 - 实时通讯运营中台”。
- Headers：入口、deep-link、全部公开 manifest 资源、私有 GET/HEAD 404 和缺失
  asset 404 均匹配 9 项 reviewed headers。
- CSP：无 `unsafe-inline` / 通用 `unsafe-eval`；仅保留 WebAssembly 所需
  `'wasm-unsafe-eval'`。DOM 中 inline style attribute/style element 均为 0。
- Console / Network：`console_messages=[]`、`page_errors=[]`；请求只包含候选入口、
  deep-link 与同 prefix 的 JS/CSS，无 plaintext marker。
- 私有文件：`release-manifest.json`、`security-headers.json` 的 GET/HEAD 均为 404；
  `assets/missing.js` 为 404，不进入 SPA fallback。
- WebCrypto：AES-GCM 256，key usages 为 encrypt/decrypt，`extractable=false`，
  `exportKey` 被拒绝。
- 存储：枚举全部 IndexedDB database/object store，并扫描 IndexedDB、localStorage、
  sessionStorage、Cache Storage、OPFS；plaintext marker 命中均为 false。
- 清理：browser context、cookie、审计数据库、远端 candidate/staging、Caddy backup
  和 `/tmp` 配置均删除；Caddy active，候选 route 与候选页面标识均消失。

机器证据位于本地忽略目录
`.artifacts/h5-release/a22b65e26d7ee28c407e2146275e24907358ae6c-browser.json`；
其中不保存 plaintext marker、token、凭据、密钥或消息内容。

## Fail-closed 组合证据

计划明确约定 production candidate 证明部署、CSP、Network、Console 和浏览器能力；
E2EE 实现故障由真实实现测试证明，禁止为验收向 production bundle 注入测试接口。

- 4 个定向测试文件、34 项测试通过：安全状态损坏、无 IndexedDB/WebCrypto 时不
  fallback、身份变化阻断、stale/unknown epoch、损坏密文与显式重试。
- H5 全量 unit：47 files passed、4 skipped；262 passed、12 skipped。
- `make h5-app.release.test`：21 个正负场景通过，覆盖双向 base mismatch、点路径
  段、公开 source map、CSP 弱化、endpoint/lock/commit/attestation 篡改。
- `make h5-app.check`：通过。

## 失败恢复证据

`scripts/h5-release-candidate-window.sh` 在 `EXIT/INT/TERM` 统一恢复原 Caddyfile，
重新 validate/reload，删除所有临时目录和配置，并复核 Admin 页面与 runtime。

- 故意执行失败 command 返回非零，随后 Caddy、候选目录、backup 与 runtime 清理
  全部通过。
- 一次 SSH 连接中断同样进入 cleanup；复核无远端残留，随后重跑成功。
- 最终公开 runtime 为 `server_storage_mode=persist`、
  `content_audit_mode=plaintext`；本验收未修改 API runtime gate 或旧主数据库。

## 独立复审

最终四视角复审结果：

| 视角 | P0 | P1 | P2 | 结论 |
| --- | ---: | ---: | ---: | --- |
| correctness | 0 | 0 | 0 | PASS |
| security | 0 | 0 | 0 | PASS |
| reliability | 0 | 0 | 0 | PASS |
| testing | 0 | 0 | 0 | PASS |

此前 findings 已逐条关闭：真实 Caddy 私有文件与静态 404、失败恢复、远端摘要、
双向 base 绑定、点路径段、全响应 headers、全 IndexedDB store 扫描和审计数据库
删除 fail-closed 均已有代码与运行证据。

## 后续门禁

- U7 P0-1、P0-2、P0-3、P0-4 现均已关闭。
- 生产 E2EE 仍为 **No-Go**，不得因本报告切换 runtime。
- 下一 checkpoint 为 `G4.1`：独立复审 G1-G3；随后从干净基线执行 G4.2 全量与
  live 重放，最后由 G4.3 作唯一 Go/No-Go 裁决。
