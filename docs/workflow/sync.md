# devflow-core 同步说明

## 目标

- 将 `devflow-core` 的流程文档与技能集同步到本仓库
- 保持 `docs/` 结构统一，避免覆盖本仓库已有 PRD/SPEC/DEV/REVIEW/TEST

## 同步方式

### 方式一：vendor 同步脚本（推荐）

脚本路径：

`/Users/chen/code/redcode-im/scripts/devflow/sync-devflow-core.sh`

默认行为：
- 同步 `docs/workflow|templates|conventions|requirements|development|reviews|tests|backlog|specs`
- 同步 `skills/` 下的 devflow skills
- 排除 `.env` 与 `PRD-*/SPEC-*/DEV-*/REVIEW-*/TEST-*` 示例文件

使用示例：

```bash
# 使用默认路径 /Users/chen/code/devflow-core
scripts/devflow/sync-devflow-core.sh

# 指定 devflow-core 路径
scripts/devflow/sync-devflow-core.sh --core /path/to/devflow-core

# 仅预览变更
scripts/devflow/sync-devflow-core.sh --dry-run

# 同步并删除目标多余文件（谨慎）
scripts/devflow/sync-devflow-core.sh --delete
```

适用场景：
- 不需要保留 devflow-core 历史
- 希望快速同步最新规范与模板

### 方式二：Git subtree（可选）

若希望保留 devflow-core 历史并可追踪来源，可使用 subtree：

```bash
# 添加 subtree（示例）
git subtree add --prefix=vendor/devflow-core /path/to/devflow-core main --squash

# 后续更新（示例）
git subtree pull --prefix=vendor/devflow-core /path/to/devflow-core main --squash
```

说明：
- subtree 需要额外维护 vendor 路径
- 仍需将 vendor 内容同步到 `docs/` 与 `skills/`（可复用 vendor 脚本改造）

## 注意事项

- `docs/index.md` 为唯一入口，不从 devflow-core 覆盖
- `docs/reference/` 为业务文档区，不参与同步
- 同步后建议运行文档链接巡检（见 `docs/reports/doc-link-audit-*.md`）
