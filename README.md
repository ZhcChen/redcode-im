# RedCode IM

项目文档入口：`docs/index.md`。

## AI 工作流

仓库当前默认采用 **Compound Engineering (CE)** 工作流。

- 工作流顺序：
  - `ce:brainstorm`
  - `ce:plan`
  - `ce:work`
  - `ce:review`
  - `ce:compound`
- 全局资源位置：
  - `~/.codex/prompts/ce-*.md`
  - `~/.codex/skills/ce-*`
  - `~/.codex/scripts/ce-init`
- 文档产物目录：
  - `docs/brainstorms/`
  - `docs/plans/`
  - `docs/solutions/`
  - `.context/compound-engineering/`

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
