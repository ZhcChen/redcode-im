---
title: U10 E2EE 六端供应链门禁独立审查
date: 2026-08-06
status: complete
scope: api,e2ee-core,android-app,ios-app,h5-app,admin,ci
verdict: pass
commit: e6287df1360d807a1bf6263d7764760b4dddca87
ci_run: 31032243630
---

# U10 E2EE 六端供应链门禁独立审查

## 结论

G2 六端供应链门禁通过独立 correctness、security、reliability、testing 与项目规范
复审，当前未发现未关闭 P0/P1。U7 P0-3 可以关闭；该结论不改变生产 E2EE 的
**No-Go** 状态，剩余阻断项为 U7 P0-4 H5 发布安全。

## 审查范围

- 六端 lockfile、CycloneDX SBOM、漏洞报告、许可证策略和限时精确例外。
- PR/main/release workflow 的受信 gate、不可信 source checkout 与发布依赖关系。
- report、SBOM、lockfile identity 完整一致性和 source commit 绑定。
- scanner、下载、报告损坏、例外错误和敏感数据泄漏的 fail-closed 行为。

## 关键证据

- CI run `31032243630` 对 commit
  `e6287df1360d807a1bf6263d7764760b4dddca87` 完整通过。
- API 432、e2ee-core 193、Android 119、iOS 1、H5 217、Admin 811 个组件均满足
  lockfile/report/SBOM 三方 identity 完整一致。
- `make supply-chain.test` 的 23 个正负场景通过；同步截断 report 与 SBOM 仍会因
  独立 lockfile 解析结果不一致而 fail closed。
- `make supply-chain.workflow.test` 通过；PR 使用受信 base gate，PR head 仅提供
  不可信 lockfile source，且不持久化 credentials。
- 29 个例外均为精确匹配、具备 owner/reason/到期日，统一于 2026-09-05 到期；
  当前 0 个未处理阻断项。

## 已关闭发现

- 扫描失败时上传可能含敏感内容的报告。
- PR 修改门禁后使用自身门禁自证通过。
- 供应链 evidence 混入 GitHub Release 正式资产。
- 活跃发布路径使用 mutable Action tag。
- iOS SBOM、summary/index commit 与完整 lockfile 覆盖未校验。
- scanner exit 1、缺失/空/错误 SBOM、report/SBOM 同步截断等负向测试缺口。

## 剩余风险

- 29 个限时例外不是“零 advisory”；其中可达的 libcrux 风险需要在到期前完成稳定
  依赖迁移或重新裁决。
- 尚未通过真实 tag/manual release 重放完整发布流程，该项并入 G4 最终门禁。
- 停用的 desktop job 仍存在 mutable Action，但不位于当前活跃发布路径；恢复前必须
  固定 SHA 并重新审查。

## 裁决

- G2：完成。
- U7 P0-3：关闭。
- 下一 checkpoint：`G3.1`。
- 生产 E2EE：No-Go。
