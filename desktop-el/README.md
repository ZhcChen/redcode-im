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
bun run smoke
```

`bun run smoke` 会先构建 renderer，再以 `vite preview` 提供静态页面，并通过 Playwright 在浏览器里注入 `window.desktopEl` mock，覆盖“登录页启动 -> 模拟登录成功 -> 进入 HomeShell”的最小主链路。当前 smoke 走 Playwright `channel: "chrome"`，默认复用本机安装的 Chrome，不额外为桌面业务启动本地 HTTP 服务端口。

`bun run verify` 仍保持轻量固定验收，只串联 Go core 测试、Bun 测试与构建；浏览器级 smoke 作为独立入口按需执行。

在仓库根目录也可以直接通过 `Makefile` 调用：

```bash
make desktop-el-test
make desktop-el-core-test
make desktop-el-build
make desktop-el-verify
make desktop-el-smoke
```
