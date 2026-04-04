# CE 工作流迁移设计

**日期**：2026-04-04  
**状态**：待进入实施计划  
**范围**：AI 开发协作流程层（非业务代码架构）

## 1. 背景

RedCode IM 当前仓库默认采用 Superpowers 作为 AI 工作流架构，相关约定已经写入：

- `AGENTS.md`
- `README.md`
- `docs/index.md`
- `docs/plans/README.md`
- 多份 `docs/plans/*.md`
- 部分交接/迁移历史文档

用户希望将仓库**硬切**到 Compound Engineering（CE）工作流，并且：

1. 使用 `~/.codex/scripts/ce-init` 生成的 `CE_AGENTS.md` 作为 CE 基线；
2. 将 CE 规则整合进当前仓库的 `AGENTS.md`；
3. 接受新增并正式采用以下 CE 目录：
   - `docs/brainstorms/`
   - `docs/plans/`
   - `docs/solutions/`
   - `.context/compound-engineering/`
4. 批量修改现有 `docs/plans/*.md` 中的 Superpowers 执行说明；
5. 不接受“仅新增任务走 CE、旧文档不改”的渐进方案，而是要求主入口与活跃文档都完成迁移。

## 2. 目标

本次迁移完成后，仓库应满足以下目标：

1. **CE 成为唯一默认主流程**
   - 默认工作流为：
     - `ce:brainstorm`
     - `ce:plan`
     - `ce:work`
     - `ce:review`
     - `ce:compound`
2. **项目规则与 CE 规则融合**
   - 保留 RedCode IM 当前的运行、测试、提交、数据库与部署规范；
   - 替换掉“Superpowers 为默认工作流”的项目级表述。
3. **仓库入口统一改口径**
   - 所有现行入口文件统一指向 CE。
4. **CE 目录结构真实落地**
   - 新增或启用 `docs/brainstorms/`、`docs/solutions/`、`.context/compound-engineering/`。
5. **历史 Superpowers 文档不再作为当前规范**
   - 可保留历史事实，但必须降级为“历史说明/迁移记录”语境。

## 3. 非目标

本次迁移**不包括**以下内容：

- 业务代码架构调整；
- 后端/前端/桌面端实现逻辑改造；
- 测试框架重建；
- CI/CD 重构；
- 历史计划正文与技术结论的全面重写。

本次只处理**AI 开发协作流程层**与相关文档规范。

## 4. 当前状态分析

### 4.1 已有 CE 环境

本机 `~/.codex` 已存在 CE 相关资源：

- `~/.codex/CE_AGENTS.md`
- `~/.codex/scripts/ce-init`
- `~/.codex/prompts/ce-*.md`
- `~/.codex/skills/ce-*`

说明：**环境安装不是阻塞点**，迁移重点在仓库规范与文档整合。

### 4.2 当前仓库对 Superpowers 的耦合点

当前仓库中，Superpowers 相关口径集中在以下区域：

1. **主入口**
   - `AGENTS.md`
   - `README.md`
   - `docs/index.md`
   - `docs/plans/README.md`
2. **活跃计划文档**
   - 多份 `docs/plans/*.md` 头部带有：
     - `superpowers:executing-plans`
     - `superpowers:subagent-driven-development`
3. **历史与交接文档**
   - 如 `docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md`
   - 如 `docs/plans/2026-03-01-superpowers-workflow-refactor-design.md`

说明：这不是一次“替换几个提示词”的调整，而是一次**项目级流程入口迁移**。

## 5. 目标态设计

### 5.1 `AGENTS.md` 结构

迁移后的 `AGENTS.md` 应采用“项目规范 + CE 主流程”的融合结构：

1. 全局行为准则（保留项目原有规则）
2. AI 工作流（Compound Engineering, CE）
3. 核心入口
4. 技术栈速查

其中 CE 段需要明确：

- 当前仓库统一采用 CE；
- 默认流程为 `ce:brainstorm -> ce:plan -> ce:work -> ce:review -> ce:compound`；
- 同一任务默认不混用多套主流程；
- CE 产物目录约定；
- 仓库中若仍存在 Superpowers 文档，视为历史产物，不代表当前默认流程。

### 5.2 文档目录结构

迁移后的文档结构应明确分层：

- `docs/index.md`：总入口
- `docs/brainstorms/`：需求讨论/方向分析
- `docs/plans/`：实施计划
- `docs/solutions/`：问题解决沉淀 / compound 知识
- `docs/reference/`：长期参考资料
- `docs/reports/`：执行报告、验收、交接

### 5.3 历史文档处理原则

历史 Superpowers 文档允许保留，但需满足：

- 不再作为当前规范入口；
- 如果保留 Superpowers 描述，必须明确是历史背景或历史迁移阶段；
- 不批量重写历史正文业务内容，只修正其“当前适用性”口径。

## 6. 迁移策略

本次采用**硬切但受控**的迁移策略：

### 6.1 必改文件（主入口）

- `AGENTS.md`
- `README.md`
- `docs/index.md`
- `docs/plans/README.md`

这组文件必须完成 CE 硬切，否则仓库主口径不会统一。

### 6.2 必改文件（活跃计划头部）

- `docs/plans/*.md`

仅修改这些文档头部的执行说明，不修改正文任务拆解与技术步骤。

### 6.3 建议改文件（交接/迁移说明）

例如：

- `docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md`
- `docs/plans/2026-03-01-superpowers-workflow-refactor-design.md`

处理方式：

- 将“当前仓库采用 Superpowers”的口径改为 CE；
- 或明确标注为历史迁移记录，不再代表当前仓库默认流程。

### 6.4 新增目录骨架

需要新增：

- `docs/brainstorms/`
- `docs/solutions/`
- `.context/compound-engineering/`

可选补充：

- `docs/brainstorms/README.md`
- `docs/solutions/README.md`
- `.context/compound-engineering/.gitkeep`

## 7. 具体迁移顺序

推荐执行顺序如下：

1. 运行 `ce-init` 生成仓库内 `CE_AGENTS.md` 基线；
2. 重写 `AGENTS.md`，整合 CE 规则与项目规则；
3. 修改 `README.md`、`docs/index.md`、`docs/plans/README.md`；
4. 新增 CE 目录骨架；
5. 批量修改 `docs/plans/*.md` 头部的 Superpowers 执行说明；
6. 清理历史交接/迁移文档中的“现行规范”误导；
7. 全仓检索验证残留；
8. 分批提交。

## 8. 风险与控制

### 风险 1：`AGENTS.md` 被模板冲掉项目规则

控制方式：

- 不直接覆盖 `AGENTS.md`；
- 先生成 `CE_AGENTS.md`；
- 手工融合到现有 `AGENTS.md`。

### 风险 2：批量修改 `docs/plans/*.md` 时误伤正文

控制方式：

- 仅替换文档头部流程说明；
- 不改正文业务步骤与命令。

### 风险 3：迁移后仍然 CE / Superpowers 混流

控制方式：

- 统一修改主入口；
- 最后用关键词全仓检索；
- 仅允许在历史文档语境保留少量 Superpowers 词汇。

### 风险 4：历史文档被“伪装成现在”

控制方式：

- 保留历史事实；
- 但清楚标注其历史性质。

## 9. 验收标准

迁移完成后，需满足以下标准：

1. 以下入口文件默认口径已切到 CE：
   - `AGENTS.md`
   - `README.md`
   - `docs/index.md`
   - `docs/plans/README.md`
2. 仓库存在并采用：
   - `docs/brainstorms/`
   - `docs/plans/`
   - `docs/solutions/`
   - `.context/compound-engineering/`
3. `docs/plans/*.md` 中不再以现行指令方式出现：
   - `superpowers:executing-plans`
   - `superpowers:subagent-driven-development`
4. 历史文档中的 Superpowers 表述已降级为历史说明；
5. 全仓检索以下关键词时，现行规范中不再把 Superpowers 作为默认流程：
   - `Superpowers`
   - `using-superpowers`
   - `brainstorming`
   - `writing-plans`
   - `executing-plans`
   - `subagent-driven-development`

## 10. 推荐提交拆分

建议至少拆成以下提交：

1. `chore(workflow): migrate project guidance to compound engineering`
   - 主入口与 CE 目录骨架
2. `chore(docs): migrate plan headers to ce workflow`
   - `docs/plans/*.md`
3. `chore(docs): mark superpowers workflow docs as historical`
   - 交接/迁移说明类文档

## 11. 结论

RedCode IM 切换到 CE 工作流是**可行且必要**的。当前本机 CE 环境已经具备，真正需要治理的是仓库层面的默认规范、入口文档和活跃计划文档。

本次应采用“**硬切主入口与活跃计划，历史正文最小改**”的策略，以避免：

- CE 与 Superpowers 混流；
- 旧文档继续误导新 agent；
- 迁移工作被放大成无边界的文档重写工程。

下一步应基于本设计文档生成实施计划，然后按计划执行迁移。
