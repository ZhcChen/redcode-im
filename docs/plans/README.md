# 规划文档目录

本目录用于存放轻工作流 `plan` 阶段生成的正式实施计划文档。
在 Codex 中也可通过 `ce:plan` 进入该阶段。

## 约定

- 实施计划：`YYYY-MM-DD-<feature-name>.md`
- `TEMPLATE.md` 只作结构参考，不写入真实任务内容
- 非微小任务开始前，优先确认已有正式 plan；缺少 plan 时先补本目录文档
- 大任务必须拆成阶段和可独立验证的执行单元

## 来源

- `brainstorm` / `ce:brainstorm` 负责产出需求/方向文档（位于 `docs/brainstorms/`）
- `plan` / `ce:plan` 负责产出实施计划（位于 `docs/plans/`）
- `execute` / `ce:work` 按计划落地实施
- `review` / `ce:review` 对照计划复核结果（必要时写入 `docs/reviews/`）
