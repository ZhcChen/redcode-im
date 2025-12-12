# RedCode IM Desktop API 文档

本目录是桌面端（Vue 3 + Tauri）访问后端的 API 封装层，主要通过 `rust-http`（Tauri 侧 Rust HTTP 客户端）发起请求，并在前端统一返回 `ApiResponse<T>`。

## 目录结构

```
api/
├── config.ts           # API/WS/版本/渠道配置
├── http.ts             # HTTP 客户端封装（Rust bridge + 重试/刷新令牌）
├── http.types.ts       # ApiResponse 类型
├── system.ts           # 登录/注册/当前用户/短信登录
├── user.ts             # 用户资料/头像直传等
├── friend.ts           # 好友/好友申请等
├── group.ts            # 会话/群聊/成员/群设置
├── message.ts          # 消息/附件直传/已读/置顶/删除等
├── file.ts             # 文件相关（上传/下载/预览等）
├── search.ts           # 消息搜索
├── version.ts          # 版本检查/下载链接
├── settings.ts         # 隐私政策/用户协议/通用设置
├── emoji-pack.ts       # 表情包
├── emoji-item.ts       # 表情项
├── notification.ts     # 桌面通知（Tauri commands）
├── rust-http.ts        # Rust HTTP bridge（Tauri）
├── rust-user.ts        # Rust bridge：用户相关
├── rust-system.ts      # Rust bridge：系统相关
├── websocket.ts        # WebSocket 辅助（握手/格式等）
├── index.ts            # 统一导出（api 对象）
└── examples/           # 示例代码
```

> 说明：历史文档中出现的 `account.ts / friendCircle.ts / chatgpt.ts / music.ts` 属于早期/其他项目遗留，本仓库当前桌面端不再提供这些 API 文件。

## 环境变量

桌面端默认读取 `desktop/.env.*`：
- `VITE_API_BASE_URL`：后端 HTTP 地址（开发常用 `http://localhost:8010`）
- `VITE_WS_URL`：后端 WebSocket 地址（开发常用 `ws://localhost:8010/ws`）
- `VITE_USE_RUST_BACKEND`：是否启用 Rust HTTP bridge（桌面端推荐启用）

## 使用方式

```ts
import { api } from '@/api'

// 登录
const loginRes = await api.system.login({ username: '153xxxxxxxx', password: 'Passw0rd!' })
if (!loginRes.success || !loginRes.data) {
  throw new Error(loginRes.message)
}

// 获取当前用户
const meRes = await api.system.getCurrentUser()
```

## 响应结构

前端统一使用 `ApiResponse<T>`：

```ts
export interface ApiResponse<T = any> {
  code: number
  message: string
  data: T | null
  success: boolean
}
```

> 注意：这是桌面端的“统一响应包装”，后端成功响应并不强制采用同一 envelope；包装与错误处理逻辑由 `api/http.ts` 负责。
