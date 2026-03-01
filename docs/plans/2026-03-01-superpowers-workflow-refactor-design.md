# Superpowers Workflow Refactor Design

**日期**: 2026-03-01

## 目标

将仓库 AI 工作流从旧 `devflow` 架构切换为 `obra/superpowers`，并移除旧流程目录与技能，避免双轨并存。

## 迁移范围

- 删除旧流程目录：
  - `docs/workflow/`
  - `docs/templates/`
  - `docs/conventions/`
  - `docs/requirements/`
  - `docs/specs/`
  - `docs/development/`
  - `docs/reviews/`
  - `docs/tests/`
  - `docs/testing/`
  - `docs/backlog/`
- 删除旧技能目录：
  - `skills/devflow-*`
- 引入 superpowers 核心结构：
  - `skills/*`（superpowers 全量技能）
  - `commands/*`（`brainstorm` / `write-plan` / `execute-plan`）
  - `docs/plans/`（新流程产出目录）
  - `docs/README.codex.md`（Codex 使用说明）
  - `.codex/INSTALL.md`（安装说明）

## 入口改造

- 重写 `AGENTS.md`：
  - 明确统一使用 superpowers
  - 移除 devflow 角色流转与 `devflow-notifier` 依赖
- 重写 `docs/index.md`：
  - 删除 devflow 导航
  - 新增 superpowers 工作流、命令入口与 plans 目录入口
- 更新 `README.md`：
  - 增加 AI 工作流章节，声明已切换 superpowers

## 兼容策略

- 保留业务参考文档与测试/运维文档（`docs/reference/**`、`docs/reports/**`）。
- 清理对已删除流程目录的直接链接。

## 验证策略

- 全局检索关键字：`devflow`、`docs/workflow`、`skills/devflow`。
- 期望结果：仅在“迁移声明语句”中出现 devflow 字样，不再出现旧目录引用。
