# desktop-el

`desktop-el` 是与现有 `desktop`（Tauri）并行的新桌面模块骨架，当前仅初始化：

- Electron Main / Preload
- Vue 3 Renderer（Vite）
- Go 1.25 Core (`go-core`)

## 本地开发

```bash
cd desktop-el
bun install
bun run dev
```

可拆分启动：

```bash
bun run dev:renderer
bun run dev:core
bun run dev:electron
```

## 构建与校验

```bash
bun run test
bun run test:core
bun run build
bun run verify
```

在仓库根目录也可以直接通过 `Makefile` 调用：

```bash
make desktop-el-test
make desktop-el-core-test
make desktop-el-build
make desktop-el-verify
```
