# U10 E2EE R4 第三轮四视角独立复审

日期：2026-08-06

实现候选：`a0b90719976f1847feeb54a2c5a857dbc09b53fe`

Release workflow：`31115034686`

Evidence commit：`63b78a02d82ad03ab3ca419fc901509e128ef22d`

## 结论

第三轮复审未通过。四个全新独立上下文分别完成 correctness、security、reliability、
testing 审查；去重后为 `P0=0/P1=1`。候选 `a0b90719` 失效，不得进入最终干净基线与
live 裁决。生产 E2EE 继续保持 **No-Go**。

## 独立结果

| Lens | P0 | P1 | Verdict |
| --- | ---: | ---: | --- |
| correctness | 0 | 0 | pass |
| security | 0 | 0 | pass |
| reliability | 0 | 1 | fail |
| testing | 0 | 0 | pass |

## 阻断项

### REL-P1-01：owned draft 删除失败后无法跨执行恢复

`scripts/release/create-github-release.sh` 在入口处发现任意既存 Release 即按 immutable
退出。若部分上传失败后的 cleanup 尝试删除本次 owned draft，但 `gh release delete`
发生瞬时失败，draft 会保留；后续同 tag、同 candidate 执行无法读取并验证原 draft 的
owner/candidate marker，因此也不能再次清理和重建，必须人工介入。

当前 `tests/scripts/test-release-reliability.sh` 只证明 cleanup delete 失败时 draft 会被
保留，没有覆盖后续同 tag、同 candidate 自动恢复。

## 关闭条件

1. 已发布 Release、foreign draft 与不同 candidate draft 始终 immutable/fail closed。
2. 同 tag、同 candidate 的 orphan owned draft 可被后续执行安全识别、删除并重建。
3. 删除使用有界重试，重试耗尽时不 create、upload 或 publish。
4. 增加“上传失败 -> cleanup delete 失败 -> 后续执行恢复 -> 发布成功”的端到端测试。
5. 在隔离 GitHub 环境补真实 API rehearsal；正式候选 run 继续保持零发布副作用。
6. 修复后重新执行全量回归、全新 Release workflow、四类 evidence 和四视角独立复审。

## 恢复入口

唯一恢复入口：
`docs/plans/2026-08-06-u10-e2ee-release-final-closure-plan.md` 的 C1。
