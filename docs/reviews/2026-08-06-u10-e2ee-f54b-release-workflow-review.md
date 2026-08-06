# U10 E2EE F5.4b Release Workflow 验收

日期：2026-08-06

对应计划：`docs/plans/2026-08-06-u10-e2ee-final-closure-execution-plan.md`

## 结论

F5.4b 已关闭。整改后候选 `1bedf20a8225257f7c01edac2bd02aee920dea16`
通过全新 `Build Release Artifacts` workflow run `31071229063`。所有必需 jobs
成功，Publish 正确 skipped，tag/Release 前后集合逐字节一致。

本验收只允许进入 F6.2 四视角独立重审，不代表 F6.2 或 F7 已通过。生产 E2EE
继续保持 **No-Go**。

## Run 证据

- Event：`workflow_dispatch`
- Head SHA：`1bedf20a8225257f7c01edac2bd02aee920dea16`
- Created：`2026-08-06T04:25:56Z`
- Completed：`2026-08-06T05:03:50Z`
- Conclusion：`success`
- 必需 jobs：输入校验、供应链、H5、Android、API test、API x86_64、API arm64
  均为 `success`
- 非发布验收：`Publish GitHub release=skipped`
- Artifacts：5 个，均未过期且带 GitHub artifact SHA-256 digest

## 资产与 Provenance

使用 `gh attestation verify` 验证 H5、Android 和 API 两个架构的 10 个 subjects。
每项均满足：

- Predicate：`https://slsa.dev/provenance/v1`
- Signer workflow：`ZhcChen/redcode-im/.github/workflows/release-artifacts.yml`
- Trigger：`workflow_dispatch`
- Workflow SHA / source digest：`1bedf20a8225257f7c01edac2bd02aee920dea16`
- Runner：GitHub-hosted

关键资产摘要：

| Asset | SHA-256 |
| --- | --- |
| H5 archive | `144112ea5484e4cf796739e0c592f2c32e5e69e021648e70f445b496527d80b4` |
| Android unsigned release APK | `99574af70abc49d677fe564f6ab02b94c7f096a3710d8865569612bdee8ec235` |
| API arm64 binary archive | `3e1e1c1f55e169c622583b7099b35d7585261b4d67517cdce8ee733446afcd60` |
| API arm64 image archive | `4963b51d7288391e1616291bbf82d877b4d714a6a169a70ebd6d4cb853a93e18` |
| API x86_64 binary archive | `c28b6b2391de1303c8c6d2352d83bc068784e2e063bc038ee7839dc2a7ac5a88` |
| API x86_64 image archive | `33722dd5257603cef36479e7c248e1bb80fba9c5d3b82383aa580fa0de9a02c5` |
| H5 manifest | `76387863c12927fc173754ad1cbe3d07897a8ea3da6a3bee988dcb7a719de173` |
| E2EE WASM | `5a6bdfd021fce5dcd49be7df907f4a09b158129d410dd400d2033efb2e71507c` |

H5 manifest 的 `source_commit`、API/WS endpoints、11 个 asset inventory 和外部
attestation 一致。API 两个架构各自的 `.sha256` 文件与下载产物实测匹配。

## 零发布副作用

本次在触发前后使用同一规范化命令保存完整集合，再执行 `cmp`：

| Collection | Count | Before/after SHA-256 |
| --- | ---: | --- |
| Git tags | 17 | `fc43c088c63e8b1cb9a286604f49c8ac5cf2f81e5014dd6b56d169786458a473` |
| GitHub Releases | 12 | `e52aee07f3094e06619c9ed03e5a484802553b809a64cb693e10b6d51ea4d54c` |

两组 before/after 文件逐字节相同，未新增、删除或修改 tag/Release。

## 持久证据

- `docs/reviews/evidence/u10-e2ee/f5-release-workflow.json`
- `docs/reviews/evidence/u10-e2ee/f5-h5-slsa-bundle.jsonl`
- `make e2ee.evidence.verify e2ee.evidence.test` 必须在提交前再次通过

`im-test-1` 旧主未被停止、升级或写入，继续保持 `persist/plaintext`。
