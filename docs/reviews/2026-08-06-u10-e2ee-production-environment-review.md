# U10 E2EE production-release environment 验证

日期：2026-08-06

## 结论

F62-P1-03 的实现与 live policy 已建立：Android candidate job 不再引用任何 signing
secret；正式 Android signing 和 Publish job 均绑定 GitHub `production-release`
environment。该 environment 配置 required reviewer，并仅允许 `main` 分支部署。

生产 E2EE 仍为 **No-Go**。本记录只关闭 environment 绑定缺口，不替代后续全新
Release workflow、四视角复审和最终发布裁决。

## 决定性证据

- Candidate：`android-app-check` 固定 `PUBLISH_RELEASE=false`，只生成 unsigned APK。
- Signing：`android-app-sign` 仅在 `workflow_dispatch && publish_release=true` 时运行，
  secrets 仅注入该 job，且 job 绑定 `production-release`。
- Publish：`publish-release` 依赖 signed Android artifact，并绑定同一 environment。
- Live policy：required reviewer 为 `ZhcChen`；custom deployment branch policy 仅允许
  `main`。规范化证据见
  `docs/reviews/evidence/u10-e2ee/production-release-environment.json`。
- 执行型门禁：缺 reviewer、错误分支或 GitHub API 失败均 fail closed。

## 残余风险

仓库当前只有 `ZhcChen` 一位 collaborator，且其权限为 admin。现有 policy 能阻止普通
write collaborator 直接取得 production secrets 或执行 Publish，但无法形成独立双人
审批，且 GitHub 报告 `can_admins_bypass=true`、`prevent_self_review=false`。增加第二位
可信 release reviewer 后，应启用 `prevent_self_review=true` 并重新取证；在此之前最终
裁决必须显式保留该运维风险。

## 验证

```text
make release.environment.test
make supply-chain.workflow.test
scripts/release/capture-production-environment.sh
```

以上命令均通过，live 查询未触发 deployment 或 Release。
