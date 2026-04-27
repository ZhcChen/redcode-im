---
title: CE 硬切时安全处理 main 脏工作区与选择性恢复
date: 2026-04-04
category: workflow-issues
module: repo-workflow-migration
problem_type: workflow_issue
component: development_workflow
severity: medium
applies_when:
  - 仓库正在做默认工作流硬切，但当前 main 仍有未提交本地改动
  - 迁移分支与本地脏工作区同时包含文档层和代码层改动
  - 需要恢复工作区内容，但不能回滚新的流程入口文档
  - backup 分支里的快照会与新工作流文档产生删除型冲突
tags:
  - ce-workflow
  - dirty-main
  - selective-checkout
  - backup-branch
  - workflow-migration
---

# CE 硬切时安全处理 main 脏工作区与选择性恢复

## Context

这次仓库统一到 Compound Engineering（CE）时，`main` 在合并前并不是干净状态，而是带着一批未提交的本地改动。问题不在于“是否要保留这些改动”，而在于这些改动与 CE 入口文档混在一起：如果直接 merge backup 分支或 cherry-pick 整个脏工作区快照，很容易把刚刚建立的 CE 入口文档和目录结构一起冲掉。

最终可行的做法不是“先 stash 再说”，也不是“整包恢复”，而是把脏工作区先冻结成独立备份，再在 CE 迁移合并完成后，按文件组做 **selective checkout** 和分批验证恢复。

## Guidance

推荐按下面的顺序处理：

1. **先把 main 的脏工作区冻结成独立备份分支**
   - 从 `main` 切出只用于留档的备份分支
   - 把当时的脏工作区提交成一个快照提交
   - 这个分支的职责只是“保留现场”，不是后续要 merge 回来的功能分支

2. **先完成工作流硬切，再处理恢复**
   - 先把 CE 迁移分支合并进 `main`
   - 验证 `AGENTS.md`、`README.md`、`docs/index.md`、`docs/brainstorms/`、`docs/solutions/` 等入口文件已经到位
   - 只有 CE 入口稳定后，才开始恢复工作区内容

3. **只做选择性恢复，不做整包 merge**
   - 对 backup 分支使用：

```bash
git checkout backup/main-pre-ce-merge-2026-04-04 -- <指定文件列表>
```

   - 先恢复与业务/脚本运行强相关的 A 组文件，例如：
     - `Makefile`
     - `backend/src/handlers/message.rs`
     - `backend/docker/dev/docker-compose.yml`
     - `frontend/scripts/*`
     - `tests/run.sh`
     - `website/build.sh`
   - 文档类与计划类改动分后续批次处理

4. **恢复后立即按真实依赖补最小闭环**
   - 这次 `backend/src/handlers/message.rs` 的恢复里，混进了未完全落地的 i18n 调用点
   - 不能机械地“按 backup 原样拿回”，而要根据当前 `main` 的错误模型补最小兼容层，先保证可编译可测试

5. **按主题分批提交**
   - 工作区恢复提交
   - 计划文档恢复提交
   - 运维/Compose 说明文档恢复提交
   - lockfile 或工具链补齐提交
   - 避免做一个难以审计的超大恢复提交

## Why This Matters

如果把“脏工作区快照分支”误当作一个可以直接 merge 的功能分支，会出现两个问题：

1. **删除型回退**
   - backup 分支比新 `main` 更旧，diff 里会把 `docs/brainstorms/README.md`、`docs/solutions/README.md` 等 CE 入口文件显示成“应删除”
   - 一旦整包 merge，新的流程入口会被旧快照覆盖

2. **语义混杂**
   - 脏工作区里往往同时包含代码、脚本、README、计划文档、历史说明
   - 真正需要恢复的，通常只是其中一部分
   - 如果不分组恢复，后续很难区分“这是原本就该保留的业务修改”还是“这是过期流程语境的残留”

这次做法之所以有效，是因为把“保留现场”和“恢复有效改动”拆成了两步：

- backup 分支负责保留现场
- 当前 `main` 负责只吸收仍然有效的那部分内容

## When to Apply

- 仓库正在做默认协作流程迁移（例如从一套 agent workflow 切到另一套）
- 迁移前的主分支不是干净状态
- 工作区快照里包含大量与新入口文档冲突的历史内容
- 你可以明确列出一批“必须先恢复的关键文件”
- 你需要保持主分支始终可验证，而不是一次性吞下所有历史脏改动

## Examples

### 推荐做法：先冻结，再选择性恢复

```bash
# 1) 冻结脏工作区
git checkout -b backup/main-pre-ce-merge-2026-04-04
git add -A
git commit -m "chore: snapshot main workspace before ce merge"

# 2) 回到 main，先完成 CE 硬切
git checkout main
git merge codex/ce-workflow-migration

# 3) 只恢复必须文件
git checkout backup/main-pre-ce-merge-2026-04-04 -- \
  Makefile \
  backend/src/handlers/message.rs \
  backend/docker/dev/docker-compose.yml \
  backend/docker/release/docker-compose.yml \
  frontend/scripts/run.sh \
  tests/run.sh
```

### 不推荐做法：直接 merge backup 分支

```bash
git merge backup/main-pre-ce-merge-2026-04-04
```

这会把“现场快照”当成功能分支处理，容易把已经迁入 `main` 的 CE 文档与目录一起冲乱。

### 这次实际恢复的分批思路

- 第 1 批：脚本、Compose、`Makefile`、`message.rs`
- 第 2 批：补回缺失但仍有价值的 plan 文档，并把头部改成 CE 口径
- 第 3 批：同步当前仓库真实 Compose 布局到后端/运维说明文档
- 第 4 批：补齐辅助说明文档、测试默认真机、`admin/bun.lock`
- 第 5 批：重写已经明显过时的 Redis 架构文档，而不是机械回放旧内容

## Related

- `backup/main-pre-ce-merge-2026-04-04`
- 快照提交：`370f463d` `chore: snapshot main workspace before ce merge`
