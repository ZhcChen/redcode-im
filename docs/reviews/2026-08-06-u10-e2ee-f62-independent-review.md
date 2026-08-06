# U10 E2EE F6.2 四视角独立重审

日期：2026-08-06

冻结候选：`1bedf20a8225257f7c01edac2bd02aee920dea16`

证据提交：`aca5af0941709e738b4b4bb2d7cf16984abbdb73`

## 结论

F6.2 未通过。四个全新独立上下文分别完成 correctness、security、reliability、
testing 审查；去重后为 `P0=0/P1=5/P2=0`。候选 `1bedf20a` 失效，不得进入 F7。
生产 E2EE 继续保持 **No-Go**。

## 独立结果

| Lens | P0 | P1 | P2 | Verdict |
| --- | ---: | ---: | ---: | --- |
| correctness | 0 | 2 | 0 | fail |
| security | 0 | 2 | 0 | fail |
| reliability | 0 | 2 | 0 | fail |
| testing | 0 | 2 | 0 | fail |

correctness、security、testing 对 provenance 两项得到独立一致结论；表中计数是各视角
原始结果，统一 finding 按根因去重后为 5 项。

## 阻断项

| ID | Severity | Finding | Evidence | Earliest rollback |
| --- | --- | --- | --- | --- |
| F62-P1-01 | P1 | 持久 evidence 只覆盖 H5 provenance，Android/API 其余 subjects 无法从干净 checkout 重放 | `docs/reviews/evidence/u10-e2ee/f5-release-workflow.json`、`scripts/e2ee-evidence/verify.ts` | F6.1-A |
| F62-P1-02 | P1 | verifier 只解析 DSSE payload，未验证签名、证书身份和透明日志证明；自洽伪造 bundle 可通过 | `scripts/e2ee-evidence/verify.ts`、`tests/scripts/test-e2ee-evidence.ts` | F6.1-A |
| F62-P1-03 | P1 | 正式发布与 Android signing 未绑定受保护 GitHub environment；普通 write 权限与生产权限未隔离 | `.github/workflows/release-artifacts.yml`；仓库 environments/branch protection live 查询 | F6.1-B |
| F62-P1-04 | P1 | `gh release create` 上传中途失败可留下不可重试的半成品 Release | `scripts/release/create-github-release.sh`、`tests/scripts/test-release-reliability.sh` | F6.1-D |
| F62-P1-05 | P1 | H5 lock 先建目录再写 owner，故障窗口可留下无 owner 且无法自动清理的孤儿锁 | `scripts/h5-release-candidate-window.sh`、`tests/scripts/test-h5-release-candidate-window.sh` | F6.1-D |

## 整改要求

1. 持久化三类资产可离线验签的最小 provenance subjects、bundles 和 trusted root；
   verifier 必须调用密码学验证器并校验证书 workflow/source identity，缺失任一必需
   subject、签名错误或身份错误均 fail closed。
2. Android signing 与 Publish job 使用受保护 `production-release` environment；候选
   构建不得取得 production signing secrets，并保存 live environment policy 证据。
3. Release 采用 draft -> 完整上传 -> publish；仅允许清理带当前 owner marker 的失败
   draft，覆盖部分上传失败、清理失败和同 tag 重试。
4. H5 owner lock 改为单文件系统原子操作，不保留“已建 lock、owner 尚未写入”的
   中间状态；增加故障注入与重试测试。
5. 任一实现、workflow 或测试门禁变更后重新执行 JDK21 `make test.all`、F5.4b
   全新 run 和四个新的 F6.2 独立上下文。

## 非阻断证据

- run `31071229063` 的必需 jobs 均成功，Publish skipped，tag/Release 零副作用。
- 未发现硬编码密钥、旧主写入路径或 F5.4b 部署动作。
- 当前问题是发布/证据门禁不足，不回退已验收的 E2EE 产品功能。
