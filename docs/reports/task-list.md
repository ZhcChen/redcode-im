# 任务清单

> 本文件用于记录 **RedCode IM** 的当前待办事项与优先级，供后续迭代与 AI 代理快速对齐上下文。

**最后更新**: 2026-01-17

---

## P0（阻塞/高优先级）

1. **一键回归入口稳定**
   - 统一入口：`docs/testing/README.md`、`tests/run.sh`（自动起测试栈并跑 Rust+Go 回归）。
2. **补齐 API 路由测试覆盖**
   - 覆盖数据：`docs/reports/api-test-coverage.json`（生成：`go -C tests/go run ./cmd/route_coverage`；Dashboard 读取）
   - 目标：持续减少 “无测试覆盖” 路由数量（优先 admin/版本/emoji/存储等高回归接口）。

---

## P1（重要）

1. **E2EE（端到端加密）落地实现**
   - 设计文档：`docs/architecture/end-to-end-encryption-design.md`（设计完成，待实现）
   - 当前状态：无数据库迁移、无 API、无端侧实现
   - 备注：当前阶段可暂缓（优先保证现有功能测试覆盖与回归稳定）。

---

## P2（维护/持续改进）

1. **测试与 CI**
   - 后端 `cargo test` 常态化执行；数据库相关测试需明确运行前置条件（PostgreSQL/环境变量）。
2. **文档完善与一致性**
   - `docs/` 作为统一文档入口；避免多个目录重复维护同主题文档。
3. **清理工作区未提交改动**
   - 合并/拆分改动并按模块整理，确保每次变更可回溯、可回滚。

---

## 已完成（可忽略历史待办）

- ✅ 文档入口引用修复：`docs/reports/*`、`backend/README.md` 已补齐
