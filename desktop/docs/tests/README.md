# RedCode IM Desktop 测试指南

> 本目录包含桌面端的测试文档和测试清单。E2E 测试代码位于 `desktop/tests/e2e/`。

## 目录结构

```
desktop/
├── docs/tests/                   # 测试文档（本目录）
│   ├── README.md                 # 本文件 - 测试索引和使用说明
│   └── 多账号WebSocket测试.md    # 多账号 WebSocket 功能测试清单
│
└── tests/                        # 测试代码目录
    ├── e2e/                      # Playwright E2E 测试用例
    │   └── websocket/            # WebSocket 相关测试
    └── playwright.config.ts      # Playwright 配置文件
```

---

## 测试文档索引

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [多账号WebSocket测试](./多账号WebSocket测试.md) | 多账号 WebSocket 连接功能测试清单 | P0 |

---

## 快速开始

### 1. 安装测试依赖

```bash
cd desktop
bun add -D @playwright/test
bunx playwright install chromium
```

### 2. 启动开发服务器

```bash
# 终端 1：启动前端开发服务器
bun run dev
```

### 3. 运行测试

```bash
# 运行所有 E2E 测试
bun run test:e2e

# 运行特定测试文件
bunx playwright test tests/e2e/websocket/multi-account.spec.ts

# 带 UI 模式运行（可视化调试）
bunx playwright test --ui

# 生成测试报告
bunx playwright show-report
```

---

## Playwright 测试框架

### 为什么选择 Playwright

- **零侵入性**：不修改任何应用代码，测试文件独立存放
- **跨浏览器**：支持 Chromium、Firefox、WebKit
- **强大的等待机制**：自动等待元素可交互
- **截图和录屏**：失败时自动捕获现场
- **并行执行**：支持多 worker 并行运行测试

### 测试原理

```
┌─────────────────────────────────────────────────────────────┐
│                      Playwright 测试流程                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────────┐                    ┌──────────────────┐  │
│   │  测试脚本     │  ── HTTP/WS ──►   │  开发服务器       │  │
│   │  (*.spec.ts) │     浏览器协议      │  (bun run dev)   │  │
│   └──────────────┘                    └──────────────────┘  │
│          │                                    │             │
│          │ 模拟用户操作                         │ 提供页面     │
│          ▼                                    ▼             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                   Chromium 浏览器                     │  │
│   │   - 自动点击、输入、滚动                               │  │
│   │   - 验证页面状态和内容                                 │  │
│   │   - 捕获网络请求和 WebSocket 消息                      │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                             │
│   注意：不修改 src/ 目录下的任何代码                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 编写测试用例

```typescript
// desktop/tests/e2e/example.spec.ts
import { test, expect } from '@playwright/test';

test.describe('登录功能', () => {
  test('使用正确的账号密码登录', async ({ page }) => {
    // 1. 访问登录页
    await page.goto('http://localhost:5173/login');

    // 2. 填写表单
    await page.fill('input[placeholder="手机号"]', '13800138000');
    await page.fill('input[placeholder="密码"]', 'password123');

    // 3. 点击登录
    await page.click('button:has-text("登录")');

    // 4. 验证跳转到首页
    await expect(page).toHaveURL(/\/home/);
  });
});
```

---

## 测试环境要求

### 前置条件

1. **后端服务运行中** - WebSocket 和 API 需要后端支持
2. **测试账号准备** - 多账号测试需要至少 2 个测试账号
3. **Node.js 环境** - Playwright 需要 Node.js 运行时

### 环境变量

可在 `desktop/tests/.env.test` 中配置测试环境变量：

```bash
# 测试账号 A
TEST_USER_A_PHONE=13800000001
TEST_USER_A_PASSWORD=test123456

# 测试账号 B
TEST_USER_B_PHONE=13800000002
TEST_USER_B_PASSWORD=test123456

# 开发服务器地址
TEST_BASE_URL=http://localhost:5173
```

---

## 测试分类

### 1. 冒烟测试（Smoke Test）

快速验证核心功能是否正常：

```bash
bunx playwright test --grep @smoke
```

### 2. 回归测试（Regression Test）

完整的功能回归验证：

```bash
bunx playwright test --grep @regression
```

### 3. 特定功能测试

```bash
# WebSocket 相关
bunx playwright test tests/e2e/websocket/

# 多账号相关
bunx playwright test --grep "多账号"
```

---

## 调试技巧

### 1. 使用 UI 模式

```bash
bunx playwright test --ui
```

### 2. 使用 Debug 模式

```bash
# 设置断点调试
PWDEBUG=1 bunx playwright test
```

### 3. 查看测试报告

```bash
bunx playwright show-report
```

### 4. 截图和录屏

测试失败时自动保存到 `desktop/tests/test-results/` 目录。

---

## 常见问题

### Q: 测试连接不上开发服务器？

确保先启动开发服务器：
```bash
bun run dev
```

### Q: WebSocket 测试失败？

确保后端服务正在运行，且 WebSocket 地址配置正确。

### Q: 多账号测试如何切换账号？

参考 [多账号WebSocket测试](./多账号WebSocket测试.md) 中的详细步骤。

---

## 贡献指南

1. 新增测试文档请放在本目录（`docs/tests/`）
2. 新增测试代码请放在 `desktop/tests/e2e/` 目录
3. 更新本 README 的索引表格
4. 遵循项目的 Commit 规范

---

**文档版本**：v1.0
**最后更新**：2025-11-28
**维护者**：RedCode IM Team
