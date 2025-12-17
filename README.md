# RedCode IM

项目文档入口：`docs/README.md`。

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

更多文档与规范请从 `docs/README.md` 开始阅读。
