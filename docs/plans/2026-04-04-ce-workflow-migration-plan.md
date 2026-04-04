# CE Workflow Migration Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If requirement interpretation changes, update the design via `ce:brainstorm` and refresh the implementation path via `ce:plan`. When implementation is ready, run `ce:review`; once the migration is stable, consider capturing durable lessons with `ce:compound`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 RedCode IM 仓库从 Superpowers 默认协作流程硬切到 Compound Engineering（CE），并统一入口文档、目录约定与活跃计划文档口径。

**Architecture:** 本次迁移只处理仓库协作流程层，不改业务代码。迁移分为四个面：导入并融合 CE 基线、重写仓库入口与目录约定、批量替换活跃 plan 头部、将仍保留 Superpowers 描述的文档降级为历史语境。所有验证采用 grep/目录检查/git diff，不依赖业务测试套件。

**Tech Stack:** Markdown、Git、Shell、ripgrep、`~/.codex/scripts/ce-init`

---

## File Structure / Responsibility Map

- `AGENTS.md` — 仓库唯一权威项目规则文件；合并项目运行规范与 CE 主流程。
- `README.md` — 仓库根入口，说明当前默认工作流与快速开始。
- `docs/index.md` — `docs/` 总索引，给出 CE 目录与使用入口。
- `docs/plans/README.md` — 计划目录说明，改成 CE 语义。
- `docs/brainstorms/README.md` — 解释 brainstorm 文档用途与命名方式。
- `docs/solutions/README.md` — 解释 solution / compound 文档用途与命名方式。
- `.context/compound-engineering/.gitkeep` — 固化 CE 运行期目录。
- `docs/plans/*-plan.md` — 活跃实施计划；仅统一头部执行说明，不改正文技术内容。
- `docs/plans/2026-03-01-superpowers-workflow-refactor-design.md` — 历史迁移设计；需明确其历史属性。
- `docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md` — 历史交接文档；需去除“当前仓库仍采用 Superpowers”的歧义。
- `docs/brainstorms/2026-04-04-ce-workflow-migration-design.md` — 本次实施的设计依据，只读参考，不在本计划中修改。
- `CE_AGENTS.md`（临时）— 由 `ce-init` 生成，仅作为人工合并 AGENTS 的 CE 基线；合并后删除，避免双权威文件并存。

### Task 1: 导入 CE 基线并重写 `AGENTS.md`

**Files:**
- Create (temporary): `CE_AGENTS.md`
- Modify: `AGENTS.md`
- Reference: `docs/brainstorms/2026-04-04-ce-workflow-migration-design.md`

- [ ] **Step 1: 运行 `ce-init` 生成仓库内 CE 基线文件**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
~/.codex/scripts/ce-init "$PWD"
```
Expected: 输出包含 `Created CE_AGENTS.md for manual merge`。

- [ ] **Step 2: 对比 `CE_AGENTS.md` 与 `AGENTS.md`，提取需要合并的 CE 规则块**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
diff -u CE_AGENTS.md AGENTS.md | sed -n '1,220p'
```
Expected: 能看到 CE 模板中的工作模式、默认工作流、产物目录与不混流规则。

- [ ] **Step 3: 最小化重写 `AGENTS.md` 的 AI 工作流段**

需要写入的核心内容：
```md
## 2. AI 工作流（Compound Engineering, CE）
- 当前仓库统一采用 **Compound Engineering (CE)** 作为默认主流程。
- 默认工作流：`ce:brainstorm` -> `ce:plan` -> `ce:work` -> `ce:review` -> `ce:compound`
- 同一任务默认不混用多套主流程；除非用户明确要求，否则不要把 CE 与 Superpowers 并行混用。
- 产物目录：`docs/brainstorms/`、`docs/plans/`、`docs/solutions/`、`.context/compound-engineering/`
- 仓库内若仍存在 Superpowers 文档，视为历史产物，不代表当前默认流程。
```
同时保留现有项目规则：语言、提交、数据库、测试、Compose、Backend/Admin 启停、技术栈速查。

- [ ] **Step 4: 删除临时 `CE_AGENTS.md`，避免与 `AGENTS.md` 形成双权威**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rm CE_AGENTS.md
```
Expected: `git status --short` 中不再出现 `CE_AGENTS.md`。

- [ ] **Step 5: 验证 `AGENTS.md` 已切换为 CE 主流程**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rg -n "Superpowers|using-superpowers|brainstorming|writing-plans|subagent-driven-development|executing-plans" AGENTS.md || true
```
Expected: 不再出现把 Superpowers 当作当前默认流程的命中；若保留历史说明，应只出现在显式“历史”语境中。

- [ ] **Step 6: 提交并推送 `AGENTS.md` 重写**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git add AGENTS.md
git commit -m "chore(workflow): migrate repository instructions to ce"
git push origin codex/ce-workflow-migration
```
Expected: commit 成功并推送到远端分支。

### Task 2: 更新仓库入口文档并落地 CE 目录骨架

**Files:**
- Modify: `README.md`
- Modify: `docs/index.md`
- Modify: `docs/plans/README.md`
- Create: `docs/brainstorms/README.md`
- Create: `docs/solutions/README.md`
- Create: `.context/compound-engineering/.gitkeep`

- [ ] **Step 1: 重写 `README.md` 的 AI 工作流段**

需要替换为类似内容：
```md
## AI 工作流

仓库当前默认采用 **Compound Engineering (CE)** 工作流。
- `ce:brainstorm`
- `ce:plan`
- `ce:work`
- `ce:review`
- `ce:compound`
```
保留现有快速开始、环境要求与测试命令。

- [ ] **Step 2: 重写 `docs/index.md` 的工作流入口与目录说明**

需要新增或改写的要点：
- `docs/brainstorms/` 作为需求/问题讨论目录
- `docs/plans/` 作为技术计划目录
- `docs/solutions/` 作为知识沉淀目录
- CE 默认工作流顺序
- 不再提 `using-superpowers` / `brainstorming` / `writing-plans`

- [ ] **Step 3: 重写 `docs/plans/README.md`，改成 CE 计划目录说明**

至少包含：
```md
本目录用于存放 CE 工作流生成的实施计划文档。
- `ce:brainstorm` 产出需求/方向文档（位于 `docs/brainstorms/`）
- `ce:plan` 产出实施计划（位于 `docs/plans/`）
```

- [ ] **Step 4: 创建 CE 目录骨架说明文件**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
mkdir -p docs/solutions .context/compound-engineering
printf '# Brainstorms\n\n本目录用于存放 CE 工作流的需求讨论与方向分析文档。\n' > docs/brainstorms/README.md
printf '# Solutions\n\n本目录用于存放 CE `ce:compound` 沉淀的问题解决方案与经验文档。\n' > docs/solutions/README.md
touch .context/compound-engineering/.gitkeep
```
Expected: 三个路径都存在，且 `git status --short` 能看到新增文件。

- [ ] **Step 5: 验证入口文档与 CE 目录已落地**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
ls docs/brainstorms docs/plans docs/solutions .context/compound-engineering
rg -n "Superpowers|using-superpowers|brainstorming|writing-plans|subagent-driven-development|executing-plans" README.md docs/index.md docs/plans/README.md || true
```
Expected: 目录存在；入口文档中不再把 Superpowers 当作当前默认流程。

- [ ] **Step 6: 提交并推送入口文档与目录骨架变更**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git add README.md docs/index.md docs/plans/README.md docs/brainstorms/README.md docs/solutions/README.md .context/compound-engineering/.gitkeep
git commit -m "chore(workflow): add compound engineering docs structure"
git push origin codex/ce-workflow-migration
```
Expected: commit 成功并推送到远端分支。

### Task 3: 批量迁移活跃计划文档头部到 CE 口径

**Files:**
- Modify: `docs/plans/2026-03-05-admin-auth-resilience-plan.md`
- Modify: `docs/plans/2026-03-05-admin-full-route-smoke-plan.md`
- Modify: `docs/plans/2026-03-05-backend-retention-cost-plan.md`
- Modify: `docs/plans/2026-03-05-backend-wave-a-plan.md`
- Modify: `docs/plans/2026-03-05-backend-wave-b-plan.md`
- Modify: `docs/plans/2026-03-05-backend-wave-c-plan.md`
- Modify: `docs/plans/2026-03-05-backend-wave-d-plan.md`
- Modify: `docs/plans/2026-03-05-cross-module-test-expansion-plan.md`
- Modify: `docs/plans/2026-03-05-frontend-test-architecture-plan.md`
- Modify: `docs/plans/2026-03-26-i18n-admin-plan.md`
- Modify: `docs/plans/2026-03-26-i18n-backend-plan.md`
- Modify: `docs/plans/2026-03-26-i18n-desktop-plan.md`
- Modify: `docs/plans/2026-03-26-i18n-frontend-plan.md`
- Modify: `docs/plans/2026-03-26-i18n-rollout-plan.md`

- [ ] **Step 1: 记录当前计划头部中的 Superpowers 命中列表**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rg -n "superpowers:|executing-plans|subagent-driven-development" docs/plans/*-plan.md
```
Expected: 命中上面列出的 14 个 plan 文件头部。

- [ ] **Step 2: 为所有受影响 plan 统一替换头部说明**

统一替换成类似下面的 CE 头部：
```md
> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If execution发现需求或范围变化，先回到 `ce:brainstorm` / `ce:plan` 更新文档；变更完成后使用 `ce:review` 审查。Steps use checkbox (`- [ ]`) syntax for tracking.
```
要求：
- 只改标题下的流程说明块；
- 不修改正文的任务步骤、命令和技术结论；
- 不对 plan 内容做无关重构。

- [ ] **Step 3: 检查 diff，确认只动了头部块**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git diff -- docs/plans/*-plan.md | sed -n '1,260p'
```
Expected: diff 主要集中在每个 plan 开头几行的工作流说明。

- [ ] **Step 4: 验证活跃 plan 文件已不再残留旧执行指令**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rg -n "superpowers:|executing-plans|subagent-driven-development" docs/plans/*-plan.md || true
```
Expected: 无输出。

- [ ] **Step 5: 提交并推送 plan 头部批量替换**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git add docs/plans/*-plan.md
git commit -m "chore(docs): migrate plan headers to ce workflow"
git push origin codex/ce-workflow-migration
```
Expected: commit 成功并推送到远端分支。

### Task 4: 将 Superpowers 文档降级为历史语境

**Files:**
- Modify: `docs/plans/2026-03-01-superpowers-workflow-refactor-design.md`
- Modify: `docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md`

- [ ] **Step 1: 给 `docs/plans/2026-03-01-superpowers-workflow-refactor-design.md` 加历史标记**

建议最小改法：
```md
> 历史说明：本文记录仓库在 2026-03-01 从 devflow 切换到 Superpowers 的迁移设计；当前仓库默认工作流已切换为 Compound Engineering (CE)。
```
可选：将标题改为 `Superpowers Workflow Refactor Design (Historical)`。

- [ ] **Step 2: 修正 `docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md` 中的现行口径**

将类似：
- `当前仓库工作流架构采用 Superpowers`
- `需遵循 ... Superpowers 工作流骨架执行`
- `当前仓库统一采用 Superpowers`

改为历史或现状并存的表述，例如：
```md
说明：本文成文时仓库仍处于 Superpowers 阶段；当前仓库默认工作流已切换为 CE。
```
要求：保留交接内容本身，不重写整篇文档。

- [ ] **Step 3: 验证历史文件已不会再误导为“当前默认流程”**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rg -n "当前仓库.*Superpowers|统一采用 Superpowers|工作流架构采用 \*\*Superpowers\*\*" docs/plans/2026-03-01-superpowers-workflow-refactor-design.md docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md || true
```
Expected: 若仍有命中，也应明确处在“历史说明”语境中。

- [ ] **Step 4: 提交并推送历史文档口径修正**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git add docs/plans/2026-03-01-superpowers-workflow-refactor-design.md docs/reports/2026-03-06-ai-handoff-full-test-rebuild.md
git commit -m "chore(docs): mark superpowers workflow docs as historical"
git push origin codex/ce-workflow-migration
```
Expected: commit 成功并推送到远端分支。

### Task 5: 全仓验证并准备执行收尾

**Files:**
- Verify only: `AGENTS.md`, `README.md`, `docs/**/*.md`, `.context/compound-engineering/.gitkeep`

- [ ] **Step 1: 运行最终全仓检索，确认现行规范已切到 CE**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
rg -n "Superpowers|using-superpowers|brainstorming|writing-plans|executing-plans|subagent-driven-development" AGENTS.md README.md docs -g '*.md' \
  | grep -Ev 'docs/brainstorms/2026-04-04-ce-workflow-migration-(design|plan)\.md|docs/plans/2026-03-01-superpowers-workflow-refactor-design\.md|docs/reports/2026-03-06-ai-handoff-full-test-rebuild\.md'
```
Expected: 无输出。

- [ ] **Step 2: 检查目录与文件状态**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
find docs -maxdepth 2 -type d | sort
find .context -maxdepth 2 -type d | sort
git status --short
```
Expected: 只剩本次迁移涉及的受控改动，没有意外文件。

- [ ] **Step 3: 复查完整 diff，确认没有误改业务代码或正文技术内容**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git diff --stat origin/main...HEAD
git diff -- AGENTS.md README.md docs .context | sed -n '1,320p'
```
Expected: 变更集中在项目规范、文档入口、plan 头部与历史说明文件，不涉及业务源码。

- [ ] **Step 4: 执行最终收尾提交（若前面任务有零散未提交）并推送**

Run:
```bash
cd /Users/chen/code/redcode-im/.worktrees/ce-workflow-migration
git status --short
# 若还有未提交变更，则补一次收尾提交
git add AGENTS.md README.md docs .context
git commit -m "chore(workflow): finalize ce migration verification" || true
git push origin codex/ce-workflow-migration
```
Expected: 工作树干净，远端分支包含完整迁移结果。

- [ ] **Step 5: 执行人工审阅与后续 workflow 交接**

检查清单：
- `AGENTS.md` 是否只保留 CE 为默认流程；
- `README.md` / `docs/index.md` 是否成为新的 CE 入口；
- `docs/plans/*.md` 是否只改了头部；
- 历史文档是否仍可读且不会误导；
- 如用户要求继续，可在代码与文档稳定后运行 `ce:review` 做质量审阅。
