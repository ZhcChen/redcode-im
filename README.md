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

### 环境要求
- Docker
- Docker Compose 插件（使用 `docker compose` 命令）
- Rust 1.75+
- Node.js 18+（管理后台使用 pnpm；桌面端/官网使用 bun）
- Flutter 3.9+
- PostgreSQL 15+
- Redis 7+

### 启动后端（开发）
```bash
cd backend
cp .env.example .env
docker compose -f docker/dev/docker-compose.yml up -d backend
```

查看日志：
```bash
cd backend
docker compose -f docker/dev/docker-compose.yml logs -f backend
```

### 启动管理后台（admin）
```bash
cd admin
pnpm install
pnpm dev
```

### 启动桌面端（desktop）
```bash
cd desktop
bun install
bun run tauri dev
```

### 启动移动端（frontend）
```bash
cd frontend
flutter pub get
flutter run
```

### 启动官网（website）
```bash
cd website
bun install
bun run dev
```

### 运行测试（重构版）
```bash
# 统一回归入口（Rust 单元 + Rust 集成 + Go 黑盒）
./tests/run.sh
```

更多文档与规范请从 `docs/index.md` 开始阅读。
