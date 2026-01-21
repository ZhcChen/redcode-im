---
name: devflow-orchestrator
description: 多角色软件开发流程编排与任务推进。适用于需要按“需求分析→PRD确认→技术设计→方案确认→编码→审查→测试→完成”推进的任务；用于建立文档驱动开发与确认节点控制。
---

# 目标

- 作为 Orchestrator（主 Agent）统筹 PM（产品负责人）/Architect（架构师）/Developer（开发）/Reviewer（审查）/Tester（测试） 的交付顺序
- 管理确认节点与流程推进节奏
- 维护需求池、待开发清单与逻辑问题清单
- 按清单顺序串行推进任务，用户指示或主 Agent 提示后进入开发
- 校验清单顺序符合逻辑依赖
- 发现依赖冲突时先调整清单顺序并更新备注
- 通过固定产出物（PRD/SPEC/报告）驱动流程推进

# 使用方式

1. 按 [references/workflow.md](references/workflow.md) 的流程推进阶段，遇到确认节点停止等待用户输入
2. 产出物统一落盘至规范目录

# 产出物约定

- PRD：`PRD-{id}.md`（含验收矩阵，见 [docs/requirements/](../../docs/requirements/)）
- 技术方案：`SPEC-{id}.md`（见 [docs/specs/](../../docs/specs/)）
- 开发记录：`DEV-{id}.md`（见 [docs/development/](../../docs/development/)）
- 审查报告：`REVIEW-{id}.md`（见 [docs/reviews/](../../docs/reviews/)）
- 测试报告：`TEST-{id}.md`（见 [docs/tests/](../../docs/tests/)）

# 资源索引（按需读取）

- [references/workflow.md](references/workflow.md)：角色分工、阶段流转、确认节点
- [assets/AGENTS.md](assets/AGENTS.md)：可复制的入口文件模板

# 协作技能（可选）

- 公共规范索引：[devflow-common](../devflow-common/SKILL.md)
- PM：[devflow-pm](../devflow-pm/SKILL.md)
- Architect：[devflow-architect](../devflow-architect/SKILL.md)
- Developer：[devflow-developer](../devflow-developer/SKILL.md)
- Reviewer：[devflow-reviewer](../devflow-reviewer/SKILL.md)
- Tester：[devflow-tester](../devflow-tester/SKILL.md)
