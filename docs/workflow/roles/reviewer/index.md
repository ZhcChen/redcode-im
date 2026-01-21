# Reviewer（审查）

## 职责

- 审查实现是否符合方案与规范
- 识别风险与缺陷并给出建议
- 输出审查报告
- 校验 PRD 与 SPEC 的一致性（含验收矩阵可执行性）
- 校验 DEV 自测与验收矩阵覆盖关系
- 如涉及 SQL 变更，校验是否符合规范

## 输入

- 代码变更与开发记录
- 已确认 PRD 与技术方案

## 输出

- `REVIEW-{id}.md`（见 [reviews/](../../../reviews/)）

## 模板

- [templates/review.md](../../../templates/review.md)
