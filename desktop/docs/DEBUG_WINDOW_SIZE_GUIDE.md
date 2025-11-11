# 窗口尺寸累积增大问题 - 调试指南

## 已添加的日志追踪点

### 前端日志标识符

| 标识符 | 位置 | 说明 |
|--------|------|------|
| `[LOGIN_RESIZE_xxxxx]` | Login.vue - setLoginWindowSize | 登录页面设置窗口尺寸 |
| `[HOME_MOUNTED_xxxxx]` | Home.vue - onMounted | Home 组件挂载 |
| `[HOME_ACTIVATED_xxxxx]` | Home.vue - onActivated | Home 组件激活（keep-alive） |
| `[HOME_DEACTIVATED_xxxxx]` | Home.vue - onDeactivated | Home 组件失活（keep-alive） |
| `[HOME_UNMOUNTED_xxxxx]` | Home.vue - onUnmounted | Home 组件卸载 |
| `[HOME_PREPARE_xxxxx]` | Home.vue - prepareWindowOnLogin | 准备主窗口 |
| `[HOME_RESIZE_xxxxx]` | Home.vue - setMainWindowSize | 设置主窗口尺寸 |

### Rust 日志标识符

| 标识符 | 位置 | 说明 |
|--------|------|------|
| `[RUST_RESIZE]` | lib.rs - set_window_size_and_center | Rust 后端设置窗口尺寸 |

## 测试步骤

### 第一轮：应用启动（登录状态）

1. **启动应用**（假设已有登录状态）
2. **观察窗口尺寸**
3. **记录前端日志**：
   - 查找 `[HOME_MOUNTED_xxxxx]` 或 `[HOME_ACTIVATED_xxxxx]`
   - 查找 `[HOME_PREPARE_xxxxx]`
   - 查找 `[HOME_RESIZE_xxxxx]`
4. **记录 Rust 日志**：
   - 查找 `[RUST_RESIZE]`

### 第二轮：退出登录

1. **点击退出登录**
2. **观察窗口尺寸变化**
3. **记录前端日志**：
   - 查找 `[HOME_DEACTIVATED_xxxxx]`
   - 查找 `[LOGIN_RESIZE_xxxxx]`
4. **记录 Rust 日志**：
   - 查找 `[RUST_RESIZE]`

### 第三轮：重新登录

1. **输入账号密码**
2. **点击登录**
3. **观察窗口尺寸**（是否比第一轮大？）
4. **记录前端日志**：
   - 查找 `[HOME_ACTIVATED_xxxxx]`（注意：不是 MOUNTED，因为 keep-alive）
   - 查找 `[HOME_PREPARE_xxxxx]`
   - 查找 `[HOME_RESIZE_xxxxx]`
5. **记录 Rust 日志**：
   - 查找 `[RUST_RESIZE]`

### 第四轮：再次退出登录

1. **点击退出登录**
2. **观察窗口尺寸变化**
3. **记录日志**

### 第五轮：再次登录

1. **输入账号密码**
2. **点击登录**
3. **观察窗口尺寸**（是否比第三轮更大？）
4. **记录日志**

## 关键检查点

### 1. 窗口尺寸变化时间线

按照时间顺序记录每次窗口尺寸变化：

```
T0: 应用启动
  - 调整前: ?x?
  - 调整后: 1200x800

T1: 退出登录
  - 调整前: 1200x800
  - 调整后: 400x600

T2: 重新登录
  - 调整前: 400x600
  - 调整后: ?x? (应该是 1200x800，但可能更大)

T3: 再次退出
  - 调整前: ?x?
  - 调整后: 400x600

T4: 再次登录
  - 调整前: 400x600
  - 调整后: ?x? (可能更大)
```

### 2. 检查 originalSize 的保存

在 Login.vue 的日志中查找：
```
[LOGIN_RESIZE_xxxxx] 保存原始尺寸: WxH
```

这个尺寸是什么？是否正确？

### 3. 检查 Home.vue 的激活次数

- 第一次进入：应该看到 `[HOME_MOUNTED_xxxxx]`
- 后续进入：应该看到 `[HOME_ACTIVATED_xxxxx]`（不是 MOUNTED）

### 4. 检查 windowStateInitialized 的状态

在 `[HOME_PREPARE_xxxxx]` 日志中查找：
```
windowStateInitialized: true/false
```

- 第一次应该是 `false`
- 如果是 `true`，说明没有重置

### 5. 检查 Rust 后端的实际设置

在 Rust 日志中查找：
```
[RUST_RESIZE] 调整前尺寸: WxH
[RUST_RESIZE] 目标尺寸: WxH
[RUST_RESIZE] 调整后尺寸: WxH
```

对比目标尺寸和实际调整后的尺寸，是否一致？

## 可能的问题原因

### 原因 1: Login.vue 保存了错误的 originalSize

**现象**：
- Login.vue 保存的 originalSize 不是主窗口尺寸
- 而是上一次的某个中间状态

**日志特征**：
```
[LOGIN_RESIZE_xxxxx] 保存原始尺寸: 1400x900 (不是 1200x800)
```

### 原因 2: Home.vue 的 windowStateInitialized 没有重置

**现象**：
- `onActivated` 没有被调用
- 或者 `windowStateInitialized` 没有被重置为 `false`

**日志特征**：
```
[HOME_PREPARE_xxxxx] windowStateInitialized: true (应该是 false)
```

### 原因 3: 窗口尺寸设置被多次调用

**现象**：
- 同一个生命周期内，窗口尺寸被设置多次
- 每次设置都基于当前尺寸进行调整

**日志特征**：
```
[HOME_RESIZE_xxxxx] 调整前尺寸: 1200x800
[HOME_RESIZE_xxxxx] 调整后尺寸: 1200x800
[HOME_RESIZE_xxxxx] 调整前尺寸: 1200x800 (又被调用了)
[HOME_RESIZE_xxxxx] 调整后尺寸: 1400x900 (变大了)
```

### 原因 4: Rust 后端设置尺寸有问题

**现象**：
- 前端请求设置 1200x800
- 但 Rust 实际设置了更大的尺寸

**日志特征**：
```
[RUST_RESIZE] 目标尺寸: 1200x800
[RUST_RESIZE] 调整后尺寸: 1400x900 (不一致)
```

## 日志分析模板

### 第一轮（应用启动）

```
前端日志：
[HOME_MOUNTED_xxxxx] ========== Home 组件挂载 ==========
[HOME_PREPARE_xxxxx] ========== 准备主窗口 ==========
[HOME_PREPARE_xxxxx] windowStateInitialized: false
[HOME_PREPARE_xxxxx] 当前状态: { isMaximized: false, currentSize: "?x?" }
[HOME_RESIZE_xxxxx] ========== 设置主窗口尺寸 ==========
[HOME_RESIZE_xxxxx] 调整前尺寸: ?x?
[HOME_RESIZE_xxxxx] 目标尺寸: 1200x800
[HOME_RESIZE_xxxxx] 调整后尺寸: ?x?

Rust 日志：
[RUST_RESIZE] ========== 设置窗口尺寸 ==========
[RUST_RESIZE] 调整前尺寸: ?x?
[RUST_RESIZE] 目标尺寸: 1200x800
[RUST_RESIZE] 调整后尺寸: ?x?
```

### 第二轮（退出登录）

```
前端日志：
[HOME_DEACTIVATED_xxxxx] ========== Home 组件失活 ==========
[LOGIN_RESIZE_xxxxx] ========== 设置登录窗口尺寸 ==========
[LOGIN_RESIZE_xxxxx] 调整前尺寸: ?x?
[LOGIN_RESIZE_xxxxx] 保存原始尺寸: ?x?
[LOGIN_RESIZE_xxxxx] 目标尺寸: 400x600
[LOGIN_RESIZE_xxxxx] 调整后尺寸: ?x?

Rust 日志：
[RUST_RESIZE] ========== 设置窗口尺寸 ==========
[RUST_RESIZE] 调整前尺寸: ?x?
[RUST_RESIZE] 目标尺寸: 400x600
[RUST_RESIZE] 调整后尺寸: ?x?
```

### 第三轮（重新登录）

```
前端日志：
[HOME_ACTIVATED_xxxxx] ========== Home 组件激活 ==========
[HOME_ACTIVATED_xxxxx] 重置 windowStateInitialized
[HOME_PREPARE_xxxxx] ========== 准备主窗口 ==========
[HOME_PREPARE_xxxxx] windowStateInitialized: false (应该是 false)
[HOME_PREPARE_xxxxx] 当前状态: { isMaximized: false, currentSize: "?x?" }
[HOME_RESIZE_xxxxx] ========== 设置主窗口尺寸 ==========
[HOME_RESIZE_xxxxx] 调整前尺寸: ?x?
[HOME_RESIZE_xxxxx] 目标尺寸: 1200x800
[HOME_RESIZE_xxxxx] 调整后尺寸: ?x? (关键：是否比第一轮大？)

Rust 日志：
[RUST_RESIZE] ========== 设置窗口尺寸 ==========
[RUST_RESIZE] 调整前尺寸: ?x?
[RUST_RESIZE] 目标尺寸: 1200x800
[RUST_RESIZE] 调整后尺寸: ?x?
```

## 下一步

1. **执行完整的测试流程**（5 轮）
2. **收集所有前端控制台日志**
3. **收集 Rust 日志**（在应用数据目录）
4. **填写日志分析模板**
5. **提供给我分析**

重点关注：
- 每次 `调整前尺寸` 和 `调整后尺寸` 的值
- `windowStateInitialized` 的状态
- `originalSize` 保存的值
- 是否有重复调用
