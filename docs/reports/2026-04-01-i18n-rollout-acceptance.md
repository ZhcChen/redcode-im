# 2026-04-01 i18n Rollout Acceptance

## 结论

截至 `codex/i18n-rollout` 当前状态：

- **Backend**：本轮计划内长尾基本收口完成，可进入合流评审。
- **Admin**：上一轮页面级多语言改造已完成并有验收记录。
- **Frontend / Desktop / Website**：**不在本轮正式落地范围内**，不能宣称“全仓库多语言已全部完成”。

## 证据链

### Backend

本轮连续提交：
- `b36594ec`
- `ccc7c2a8`
- `d8d9d9ff`
- `f9a655f9`

已覆盖域：
- auth / friend / user / message / group / room / version / admin
- upload / emoji / report / push / e2ee
- feedback / upload_policy
- storage audit / COS

验证：
- Rust i18n 单测通过
- Go locale contract 隔离栈回归通过

### Admin

参考既有验收：
- `docs/reports/2026-03-26-admin-i18n-acceptance.md`

### 非本轮范围

以下模块没有纳入本轮“完成态”口径：
- `frontend/`
- `desktop/`
- `website/`

## 对外口径建议

可以说：
- “Backend i18n 收尾已基本完成，Admin 已完成页面级多语言改造。”
- “当前分支已经补齐 locale contract 与主要错误协议。”

不要说：
- “整个仓库所有模块的多语言已经全部完成。”
- “Frontend / Desktop 已完成正式 i18n rollout。”

## 后续建议

1. 若要继续追求更高覆盖率，优先清理剩余零散中文 success message / 历史错误字符串。
2. 将本轮 locale contract 命令固化到 CI 或 nightly 回归。
3. 如要进入全仓库 i18n 阶段，需单独为 Frontend / Desktop / Website 建立新计划与验收文档。
