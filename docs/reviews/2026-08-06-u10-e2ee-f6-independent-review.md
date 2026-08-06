# U10 E2EE F6 最终独立复审

日期：2026-08-06

实现候选：`eff9e9fd10e1fb7b2b7615571ab8f5f993f72a68`

审查范围：`aa605931..eff9e9fd`、F1-F5 reviews/evidence、候选当前源码与 run `31065710816`

## 裁决

F6 首轮复审 **不通过**。生产 E2EE 保持 **No-Go**，禁止进入 F7。

| 视角 | P0 | P1 | P2 | 结论 |
| --- | ---: | ---: | ---: | --- |
| correctness | 0 | 1 | 1 | fail |
| security | 0 | 3 | 0 | fail |
| reliability | 0 | 3 | 1 | fail |
| testing | 0 | 2 | 1 | fail |

correctness 与 security 各有额外独立上下文复核，结论与主视角 finding 一致。去重后共 9 个 P1、3 个 P2。

## P1 Findings

| ID | 视角 | Finding | 最早回退点 |
| --- | --- | --- | --- |
| F6-P1-01 | correctness | `scripts/e2ee-evidence/sanitize.ts` 仍要求旧 `source_*` 字段，无法消费 restore 当前 `isolation` identity | F4 |
| F6-P1-02 | testing | F5.4 只有 Markdown 摘要，没有可由干净 checkout 验证的 machine evidence 与 attestation bundle | F5.4 |
| F6-P1-03 | testing | canonical WASM 与 H5 endpoint 的错误平台/版本/空值分支只做源码正则匹配，未执行 fail-closed 测试 | F5.3b |
| F6-P1-04 | security | `workflow_dispatch` 可从任意 ref 创建不存在的新 tag 与正式 Release | F5.3/F5.4 |
| F6-P1-05 | security | 正式 Release 发布 Android debug APK，没有受控 release signing 边界 | F5.3/F5.4 |
| F6-P1-06 | security | Android/API assets 缺少 candidate-bound provenance；API base images 与最终 Cargo build 输入可漂移 | F5.3/F5.4 |
| F6-P1-07 | reliability | 已有 Release 先删旧 assets 再上传，失败会留下残缺 Release | F5.3/F5.4 |
| F6-P1-08 | reliability | concurrency group 使用 dispatch ref 而不是目标 `release_tag`，同一 Release 可被不同 ref 并发修改 | F5.3/F5.4 |
| F6-P1-09 | reliability | H5 candidate window 使用共享远端路径但无原子锁和 owner 校验，并发实例会互相清理 | F3/F5.3 |

## P2 Findings

- F6-P2-01. evidence verifier 只检查 `subject_committed_at` 格式，没有与 `git show <subject> --format=%cI` 比较。
- F6-P2-02. API artifact 导出在 `docker cp` 失败后没有 trap 清理临时 container。
- F6-P2-03. `make test.all` 未纳入新增 release、evidence、candidate cleanup 等专项门禁。

P2 不单独阻断 F7，但与本轮 P1 位于同一代码路径，纳入 F6.1 一并关闭。

## 整改决策

1. evidence producer、schema、verifier 和 fixture 统一到当前 `isolation` 契约；新增 F5 machine evidence 与脱敏 SLSA bundle。
2. 手工正式发布只允许 `main`，目标 tag 必须预先存在并指向候选；Release 采用 immutable create-only，不更新或删除既有资产。
3. concurrency 绑定目标 release tag；API 导出使用 trap 清理。
4. Android 验收构建使用 release variant；正式发布必须具备完整 signing secrets，否则 fail closed；不再发布 debug APK。
5. H5、Android、API 每类发布资产生成 provenance；API base image 使用 digest，最终 Cargo build 使用 `--locked`。
6. H5 candidate window 使用远端原子 lock directory 与 owner token，cleanup 只处理本实例资源。
7. 关键负向分支改为执行测试，并把必要专项门禁纳入 `test.all`。

## 退出条件

完成 F6.1 全部整改和定向测试后，原 `implementation_candidate_sha` 失效。必须重新执行 F5.4，冻结新候选，再用四个全新独立上下文执行 F6.2；只有 `P0=0/P1=0` 才允许进入 F7。
