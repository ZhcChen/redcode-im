# 多账号 WebSocket 测试清单

> 本文档包含多账号 WebSocket 重构后的完整测试用例和验证步骤。

## 测试背景

### 重构目标
将单 WebSocket 连接架构改为多连接架构，每个登录账号维护独立的 WebSocket 连接。

### 相关文档
- [多账号WebSocket重构计划](../重构/多账号WebSocket重构.md)

### 测试环境要求
- 后端服务运行中
- 至少 2 个测试账号（A 和 B）
- 桌面端开发模式或生产包

---

## 测试用例

### 1. 基础功能测试

#### 1.1 单账号登录连接

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-001 |
| **优先级** | P0 |
| **前置条件** | 应用未登录任何账号 |

**测试步骤**：
1. 启动应用
2. 使用账号 A 登录
3. 等待登录成功

**预期结果**：
- [ ] 登录成功后自动建立 WebSocket 连接
- [ ] 控制台显示 `[WebSocket] 连接成功` 日志
- [ ] 网络状态指示器显示已连接（绿色）
- [ ] 能正常接收消息推送

**验证方法**：
```javascript
// 在开发者工具控制台执行
console.log('连接状态:', window.__VUEX_STORE__?.state?.networkState)
```

---

#### 1.2 多账号同时连接

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-002 |
| **优先级** | P0 |
| **前置条件** | 账号 A 已登录 |

**测试步骤**：
1. 点击添加账号
2. 使用账号 B 登录
3. 等待登录成功

**预期结果**：
- [ ] 账号 B 登录成功
- [ ] 账号 A 的 WebSocket 连接保持不断开
- [ ] 账号 B 建立新的 WebSocket 连接
- [ ] 账号 Tab 显示两个账号

**验证方法**：
```javascript
// 检查所有连接状态
const wsManager = window.__WS_MANAGER__;
console.log('已连接账号数:', wsManager?.getConnectedCount?.())
console.log('所有连接状态:', wsManager?.getAllConnectionStates?.())
```

---

#### 1.3 账号切换不断连

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-003 |
| **优先级** | P0 |
| **前置条件** | 账号 A 和 B 均已登录 |

**测试步骤**：
1. 当前为账号 A
2. 点击账号 B 的 Tab 切换
3. 再切换回账号 A

**预期结果**：
- [ ] 切换过程中两个账号的 WebSocket 连接均保持
- [ ] 切换后能立即看到对应账号的消息
- [ ] 无需等待重新连接

---

### 2. 消息推送测试

#### 2.1 当前账号收到消息

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-004 |
| **优先级** | P0 |
| **前置条件** | 账号 A 为当前账号，已登录 |

**测试步骤**：
1. 使用其他设备向账号 A 发送消息
2. 观察消息接收

**预期结果**：
- [ ] 消息实时显示在聊天窗口
- [ ] 消息内容正确
- [ ] 未读数正确更新
- [ ] 无消息重复

---

#### 2.2 非当前账号收到消息

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-005 |
| **优先级** | P0 |
| **前置条件** | 账号 A 和 B 均已登录，当前为账号 A |

**测试步骤**：
1. 使用其他设备向账号 B 发送消息
2. 观察账号 B 的 Tab

**预期结果**：
- [ ] 账号 B 的 Tab 显示未读闪烁/红点
- [ ] 账号 B 的未读数正确更新
- [ ] 切换到账号 B 后消息正确显示

---

#### 2.3 自己发送消息不重复

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-006 |
| **优先级** | P0 |
| **前置条件** | 已登录并打开聊天窗口 |

**测试步骤**：
1. 在聊天窗口发送一条消息
2. 观察消息列表

**预期结果**：
- [ ] 消息只显示一条（非两条重复）
- [ ] 消息状态从"发送中"变为"已发送"
- [ ] 无转圈加载的残留消息

---

### 3. 好友请求测试

#### 3.1 当前账号收到好友请求

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-007 |
| **优先级** | P1 |
| **前置条件** | 账号 A 为当前账号 |

**测试步骤**：
1. 使用其他账号向账号 A 发送好友请求
2. 观察通知

**预期结果**：
- [ ] 好友请求数实时更新
- [ ] 联系人页面显示新请求
- [ ] Tab 或菜单显示红点提示

---

#### 3.2 非当前账号收到好友请求

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-008 |
| **优先级** | P1 |
| **前置条件** | 账号 A 和 B 均已登录，当前为账号 A |

**测试步骤**：
1. 使用其他账号向账号 B 发送好友请求
2. 观察账号 B 的 Tab

**预期结果**：
- [ ] 账号 B 的 Tab 显示提示
- [ ] 账号 B 的好友请求数更新
- [ ] 切换到账号 B 后能看到请求

---

### 4. 边界情况测试

#### 4.1 网络断开后重连

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-009 |
| **优先级** | P1 |
| **前置条件** | 已登录并连接 |

**测试步骤**：
1. 断开网络连接（关闭 Wi-Fi 或拔网线）
2. 等待 10 秒
3. 恢复网络连接

**预期结果**：
- [ ] 断网时显示离线状态
- [ ] 恢复网络后自动重连
- [ ] 重连后能正常收发消息
- [ ] 多账号场景下所有账号都能重连

---

#### 4.2 单个账号连接失败

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-010 |
| **优先级** | P1 |
| **前置条件** | 账号 A 和 B 均已登录 |

**测试步骤**：
1. 后端强制断开账号 A 的连接（或 token 过期）
2. 观察应用行为

**预期结果**：
- [ ] 账号 A 显示离线/重连中状态
- [ ] 账号 B 的连接不受影响
- [ ] 账号 B 能正常收发消息

---

#### 4.3 移除账号时清理连接

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-011 |
| **优先级** | P1 |
| **前置条件** | 账号 A 和 B 均已登录 |

**测试步骤**：
1. 移除账号 B
2. 检查连接状态

**预期结果**：
- [ ] 账号 B 的 WebSocket 连接被关闭
- [ ] 账号 A 的连接不受影响
- [ ] 无内存泄漏（可通过 DevTools 检查）

---

#### 4.4 应用退出时清理所有连接

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-012 |
| **优先级** | P1 |
| **前置条件** | 多账号已登录 |

**测试步骤**：
1. 关闭应用窗口
2. 检查后端日志

**预期结果**：
- [ ] 所有 WebSocket 连接正确关闭
- [ ] 后端收到断开连接事件
- [ ] 无残留连接

---

### 5. 性能测试

#### 5.1 多连接内存占用

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-013 |
| **优先级** | P2 |
| **前置条件** | 可登录 3 个或更多账号 |

**测试步骤**：
1. 记录初始内存占用
2. 依次登录多个账号
3. 等待 5 分钟
4. 记录最终内存占用

**预期结果**：
- [ ] 每个账号增加的内存占用合理（< 10MB）
- [ ] 内存不持续增长
- [ ] 无内存泄漏

**验证方法**：
使用 Chrome DevTools 的 Memory 面板进行内存快照对比。

---

#### 5.2 心跳资源消耗

| 项目 | 内容 |
|------|------|
| **用例ID** | WS-014 |
| **优先级** | P2 |
| **前置条件** | 多账号已登录 |

**测试步骤**：
1. 打开 DevTools Network 面板
2. 观察 WebSocket 帧
3. 持续观察 10 分钟

**预期结果**：
- [ ] 心跳频率合理（约 30 秒一次）
- [ ] 心跳包大小较小
- [ ] CPU 占用稳定

---

## Playwright 自动化测试

### 测试文件位置
```
desktop/tests/e2e/websocket/
├── multi-account.spec.ts      # 多账号连接测试
├── message-push.spec.ts       # 消息推送测试
└── reconnect.spec.ts          # 重连测试
```

### 示例测试代码

```typescript
// tests/e2e/websocket/multi-account.spec.ts
import { test, expect } from '@playwright/test';

test.describe('多账号 WebSocket', () => {
  test('WS-002: 多账号同时连接', async ({ page }) => {
    // 1. 登录账号 A
    await page.goto('http://localhost:5173/login');
    await page.fill('input[placeholder="手机号"]', process.env.TEST_USER_A_PHONE!);
    await page.fill('input[placeholder="密码"]', process.env.TEST_USER_A_PASSWORD!);
    await page.click('button:has-text("登录")');
    await expect(page).toHaveURL(/\/home/);

    // 2. 验证 WebSocket 连接
    const wsConnected = await page.evaluate(() => {
      return (window as any).__VUEX_STORE__?.state?.networkState === true;
    });
    expect(wsConnected).toBe(true);

    // 3. 添加账号 B
    await page.click('[data-testid="add-account"]');
    await page.fill('input[placeholder="手机号"]', process.env.TEST_USER_B_PHONE!);
    await page.fill('input[placeholder="密码"]', process.env.TEST_USER_B_PASSWORD!);
    await page.click('button:has-text("登录")');

    // 4. 验证两个账号都已连接
    const connectedCount = await page.evaluate(() => {
      return (window as any).__WS_MANAGER__?.getConnectedCount?.() ?? 0;
    });
    expect(connectedCount).toBe(2);
  });

  test('WS-003: 账号切换不断连', async ({ page }) => {
    // ... 测试实现
  });
});
```

---

## 测试报告模板

### 测试执行记录

| 用例ID | 测试人 | 测试日期 | 结果 | 备注 |
|--------|--------|----------|------|------|
| WS-001 | | | Pass/Fail | |
| WS-002 | | | Pass/Fail | |
| WS-003 | | | Pass/Fail | |
| ... | | | | |

### 发现的问题

| 问题ID | 关联用例 | 问题描述 | 严重程度 | 状态 |
|--------|----------|----------|----------|------|
| | | | | |

---

## 附录

### 调试命令

```javascript
// 获取 WebSocket 管理器实例
const wsManager = window.__WS_MANAGER__;

// 查看所有连接状态
wsManager.getAllConnectionStates()

// 查看已连接账号数
wsManager.getConnectedCount()

// 查看当前用户 ID
wsManager.getCurrentUserId()

// 检查特定用户是否已连接
wsManager.isUserConnected('user-id-here')
```

### 相关代码位置

| 功能 | 文件 | 行号 |
|------|------|------|
| WebSocket 管理器 | `src/utils/websocket.ts` | 77 |
| 账号切换处理 | `src/App.vue` | 384 |
| 消息处理 | `src/views/Chat.vue` | 7501 |
| 事件分发 | `src/utils/websocket.ts` | 208 |

---

**文档版本**：v1.0
**最后更新**：2025-11-28
**维护者**：RedCode IM Team
