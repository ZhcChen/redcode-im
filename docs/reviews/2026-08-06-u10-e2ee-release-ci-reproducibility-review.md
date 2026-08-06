# U10 E2EE Release CI 可复现性验收

日期：2026-08-06

对应计划：`docs/plans/2026-08-06-u10-e2ee-final-closure-execution-plan.md`

验收单元：F5.2、F5.3a、F5.3b

实现修复：`e652aaa1`、`2495a2df`、`caefedf5`

## 结论

F5.2、F5.3a、F5.3b 已关闭。三次真实 Release workflow 暴露的 repository variables、Android host cdylib、Rust 工具链、artifact workspace 路径和 H5 WASM 生成环境问题，均已形成确定性归因与本地回归门禁。

生产 E2EE 仍为 **No-Go**。本验收只允许进入 F5.4 全新候选 workflow，不代表 Release、F6 或 F7 已通过。

## Workflow 证据

| Run | Subject | 结论 | 决定性结果 |
| --- | --- | --- | --- |
| `31061331555` | `32d065af1b5114a8bd61115df09574da7b8519f0` | failure | H5 repository variables 缺失；Android Linux host cdylib 缺失；API 与供应链通过 |
| `31063363938` | `615888f1f26d1f20c3bb3d4908cc24af8ea4a3f5` | cancelled | H5 Rust 未固定导致 tracked WASM 改变；Android artifact workspace 路径错误 |
| `31063965919` | `2495a2dfbdba75d3cf85972f954026c99cac5c1d` | cancelled | H5 pinned Rust/wasm-pack 成功，但 Linux 重建仍改变 tracked WASM；Android、API tests、API arm64 成功；API x86_64 在已确定 H5 失败后取消 |

run `31063965919` 中 H5 package、attestation 和 upload 在 clean-source gate 失败后正确跳过；Publish job 未执行发布动作。该 run 于 H5 根因和其余关键 job 结论明确后手工取消，避免继续占用 concurrency group。

## 根因与决策

原 checked-in WASM 包含本机构建路径 `/Users/chen/...`，固定 Rust `1.94.0` 与 `wasm-pack 0.15.0` 后仍不能跨 host 复现。加入 `--remap-path-prefix` 后绝对路径被规范化，但 macOS arm64 与 Linux x86_64 的 Rust/`wasm-opt` codegen 仍产生不同字节：

- macOS remapped SHA-256：`47f6ee02da02d668de5cc81d62d46778f73bff039cc634c68a40f3aefaa936fa`
- Linux x86_64 remapped SHA-256：`5a6bdfd021fce5dcd49be7df907f4a09b158129d410dd400d2033efb2e71507c`

因此采用单一 canonical builder，而不是宣称跨 host 字节可复现：

1. 只有 Linux x86_64、Rust `1.94.0`、`wasm-pack 0.15.0` 可以生成 tracked WASM。
2. workspace、Cargo registry 和 Rust sysroot 均映射到稳定路径。
3. Release workflow 先执行 canonical WASM 重建，再执行 clean-worktree H5 candidate build。
4. 普通 H5 build 只消费 checked-in WASM，不在 macOS 隐式重生成。
5. 非 canonical builder 调用生成脚本立即 fail closed。

## 验证结果

| 验证 | 结果 |
| --- | --- |
| `make supply-chain.workflow.test` | pass |
| `make h5-app.check h5-app.release.test` | pass；21 个 release 正负场景与 browser audit 通过 |
| canonical `linux/amd64` 连续重建 | pass；前后 SHA-256 均为 `5a6bdfd...` |
| macOS 直接调用 `scripts/build-e2ee-wasm.sh` | fail closed；提示必须使用 canonical Linux x86_64 builder |
| 干净 detached candidate `h5-app.release.build` | pass；11 个 assets、9 个 response headers 和 source commit 绑定通过 |
| `git diff --check` / `git diff --cached --check` | pass |
| 临时 worktree 与 Docker volumes | 已清理 |

canonical optimized WASM 大小为 1,551,016 bytes，保留 `wasm-opt` 后的 release 包体；未采用会扩大约 30% 的 `--no-opt` 方案。

## 发布副作用

三次 `publish_release=false` 验收前后集合摘要保持一致：

- tags SHA-256：`e023f4b370a568468175d424a832b14e99a2052f6eebc630a1df065961f08cb8`
- Releases SHA-256：`b9b1303f61ac70002c80585c3b55fa3ab1d0e1c6f463b13b39f6233f52a8fe4f`

未新增或修改 tag/Release。`im-test-1` 旧主未被停止、升级或写入，继续保持 `persist/plaintext`。

## 下一步

从已 push 且工作区干净的新 HEAD 冻结 tag/Release 前态，以 `publish_release=false` 触发 F5.4 全新 workflow。只有该 run 全部必需 jobs、artifact、attestation、subject 绑定和零副作用通过后，才冻结 `implementation_candidate_sha` 并进入 F6。
