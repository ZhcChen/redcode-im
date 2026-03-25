# Desktop EL Tray / Window 接通 Plan

> **For agentic workers:** 继续坚持 Electron 只做宿主壳；renderer 只通过 `window.desktopEl.*` 调宿主 IPC，不额外开放 HTTP 端口。

**Goal:** 补齐 `desktop-el` 对 tray / window 的业务侧显式控制，让 renderer 能真实驱动“隐藏到托盘、请求注意力、窗口标题同步”这类旧桌面端已有语义。

**Scope:**
- 在 Electron `window` namespace 补 `requestAttention`
- renderer 消息通知链路接入宿主 attention
- renderer 主壳提供“隐藏到托盘”显式入口
- renderer 根据登录态同步窗口标题

**Verification:**
- `cd desktop-el && bun test electron/preload/api.test.ts renderer/src/utils/chat-notification.test.ts renderer/src/utils/desktop-window-title.test.ts`
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`
