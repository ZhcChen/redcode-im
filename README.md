# RedCode IM

项目文档入口：`docs/index.md`。

## AI 工作流

仓库当前默认采用 `agent-light-workflow` 风格的轻量五阶段工作流，并保留
Compound Engineering（CE）技能命名作为 Codex 兼容层。

- 工作流顺序：
  - `brainstorm`：需求不清、范围未定或方案分叉时才启用
  - `plan`：形成正式计划并落到 `docs/plans/`
  - `execute`：按计划小步执行并持续验证（Codex 中可映射为 `ce:work`）
  - `review`：对照计划检查结果、回归和偏差
  - `compound`：把可复用经验沉淀到 `docs/solutions/`
- 文档产物目录：
  - `docs/brainstorms/`
  - `docs/plans/`
  - `docs/reviews/`
  - `docs/solutions/`
  - `docs/prompts/`

## 快速开始

### 根目录统一命令

优先使用根目录 `Makefile`：

```bash
make help
make status
make api.up
make admin.up
make desktop.up
make h5-app.up
make website.up
make app.run
make test.all
```

### 环境要求
- Docker
- Docker Compose 插件（使用 `docker compose` 命令）
- Rust 1.75+
- Node.js 20.19+ 或 22.12+（h5-app 使用 Vite 8）
- Bun 1.0+
- Flutter 3.9+
- PostgreSQL 15+
- Redis 7+

### 启动后端（开发）
```bash
make api.up
```

查看日志：
```bash
make api.logs
```

### 启动管理后台（admin）
```bash
make admin.install
make admin.up
```

### 启动桌面端（desktop）
```bash
make desktop.install
make desktop.up
```

### 启动移动端（app）
```bash
make app.install
make app.run
```

### 启动 H5 App（h5-app）
```bash
make h5-app.install
make h5-app.up
```

### 启动官网（website）
```bash
make website.install
make website.up
```

### 运行测试（重构版）
```bash
make test.all
```

更多文档与规范请从 `docs/index.md` 开始阅读。
