# RedCode IM

项目文档入口：`docs/index.md`。

## AI 工作流

仓库已切换到 **Superpowers** 工作流，旧 `devflow` 架构已移除。

- Superpowers 使用全局安装：`~/.codex/superpowers`
- 技能发现路径：`~/.agents/skills/superpowers -> ~/.codex/superpowers/skills`
- 规划文档：`docs/plans/`
- 安装说明：`https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md`

## 快速开始

### 环境要求
- Rust 1.75+
- Node.js 18+（管理后台使用 pnpm；桌面端/官网使用 bun）
- Flutter 3.9+
- PostgreSQL 15+
- Redis 7+

### 启动后端（开发）
```bash
cd backend
docker compose up -d postgres redis-session redis-cache
RUST_LOG=debug cargo run
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

### 启动新桌面端骨架（desktop-el）
```bash
cd desktop-el
bun install
bun run dev
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

### 统一命令入口（Makefile）
```bash
# 查看全部入口（含 api/admin/desktop/website/tests/desktop-el）
make help
```

更多文档与规范请从 `docs/index.md` 开始阅读。
