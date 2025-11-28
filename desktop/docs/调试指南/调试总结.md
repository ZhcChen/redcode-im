# 自动跳转登录页问题 - 日志追踪总结

## 已完成的工作

### 1. 添加了详细的日志追踪

在所有可能导致跳转到登录页的关键位置添加了详细日志，每个日志都有唯一标识符和调用栈信息。

#### 修改的文件：
1. **src/App.vue** - Token watch 监听
2. **src/router/index.ts** - 路由守卫
3. **src/store/index.ts** - SET_TOKEN mutation 和 logout action
4. **src/api/http.ts** - 401 错误处理
5. **src/main.ts** - Fallback 定时器

### 2. 日志标识符说明

| 标识符 | 位置 | 说明 |
|--------|------|------|
| `[WATCH_xxxxx]` | App.vue | Token 变化监听 |
| `[GUARD_xxxxx]` | router/index.ts | 路由守卫 |
| `[MUTATION_xxxxx]` | store/index.ts | SET_TOKEN mutation |
| `[LOGOUT_xxxxx]` | store/index.ts | Logout action |
| `[401_xxxxx]` | api/http.ts | 401 错误处理 |
| `[FALLBACK_xxxxx]` | main.ts | Fallback 定时器 |

### 3. 可能的问题原因

根据代码分析，可能导致自动跳转的原因有：

#### 原因 1: 401 错误触发自动登出 ⭐ 最可能
- **位置**: `src/api/http.ts` - `handleUnauthorizedResponse`
- **触发条件**: 登录后某个请求返回 401
- **时间**: 登录后 2-5 秒（取决于请求时机）
- **日志特征**: 
  ```
  [401_xxxxx] 🚫 认证失败，准备自动登出
  [LOGOUT_xxxxx] 开始退出登录
  ```

#### 原因 2: Fallback 定时器误触发
- **位置**: `src/main.ts` - fallbackTimer
- **触发条件**: 应用启动 5 秒后，登录状态异常
- **时间**: 固定 5 秒
- **日志特征**:
  ```
  [FALLBACK_xxxxx] Fallback: 强制隐藏加载蒙版并跳转登录页
  ```

#### 原因 3: 登录状态不同步
- **位置**: 多处
- **触发条件**: token 已设置但 isLoggedIn 为 false
- **时间**: 不确定
- **日志特征**:
  ```
  [GUARD_xxxxx] 路由守卫 - 登录状态: { isLoggedIn: false, hasToken: true }
  [GUARD_xxxxx] ⚠️ 未登录用户试图访问受保护页面，重定向到登录页
  ```

#### 原因 4: Token 被意外清除
- **位置**: 未知（需要通过日志追踪）
- **触发条件**: 某处代码调用了 `SET_TOKEN(null)`
- **时间**: 不确定
- **日志特征**:
  ```
  [MUTATION_xxxxx] 新token: 无token
  [MUTATION_xxxxx] 调用栈: ...
  ```

## 测试流程

### 第一步：准备测试环境
```bash
# 1. 确保代码已更新
cd /Users/chen/code/redcode-im/desktop

# 2. 重新构建（如果需要）
npm run tauri build

# 3. 启动应用
npm run tauri dev
```

### 第二步：执行测试
1. 打开应用
2. 打开浏览器开发者工具（F12）
3. 切换到 Console 标签
4. 输入账号密码或验证码
5. 点击登录
6. **不要进行任何操作，等待 10 秒**
7. 观察是否自动跳回登录页

### 第三步：收集日志
1. 如果发生自动跳转，立即复制所有控制台日志
2. 保存到文本文件
3. 提供给我分析

### 第四步：分析日志

按照以下顺序查找关键日志：

1. **查找第一个 SET_TOKEN(null)**
   ```
   搜索: [MUTATION_ 且 新token: 无token
   ```

2. **查找第一个 LOGOUT**
   ```
   搜索: [LOGOUT_ 且 开始退出登录
   ```

3. **查找 401 错误**
   ```
   搜索: [401_ 且 401认证失败
   ```

4. **查找 Fallback 触发**
   ```
   搜索: [FALLBACK_ 且 Fallback 定时器触发
   ```

5. **查找路由守卫拦截**
   ```
   搜索: [GUARD_ 且 重定向到登录页
   ```

## 日志分析要点

### 关键信息
1. **时间线**: 按照时间戳排序，找出事件发生的先后顺序
2. **调用栈**: 每个关键日志都包含调用栈，可以追溯到源头
3. **状态快照**: 每个日志都包含当时的状态信息（token、isLoggedIn 等）

### 分析步骤
1. 找到第一个异常日志（SET_TOKEN(null) 或 LOGOUT）
2. 查看该日志的调用栈
3. 向上追溯，找到触发源
4. 分析为什么会触发

### 预期的正常日志流程
```
[MUTATION_xxxxx] SET_TOKEN 被调用 (新token: eyJhbGciOi...)
[WATCH_xxxxx] TOKEN WATCH 触发 (newToken: eyJhbGciOi..., isLoggedIn: true)
[GUARD_xxxxx] 路由守卫触发 (从: /login 到: /home, isLoggedIn: true)
[GUARD_xxxxx] ✅ 路由守卫通过
[FALLBACK_xxxxx] Fallback 定时器触发
[FALLBACK_xxxxx] Fallback: 用户已登录，跳过 fallback 处理
... 用户正常使用 ...
```

### 异常日志示例 1: 401 触发登出
```
[MUTATION_xxxxx] SET_TOKEN 被调用 (新token: eyJhbGciOi...)
[WATCH_xxxxx] TOKEN WATCH 触发 (newToken: eyJhbGciOi..., isLoggedIn: true)
... 登录成功 ...
[401_xxxxx] 401 错误处理开始
[401_xxxxx] 🚫 认证失败，准备自动登出
[LOGOUT_xxxxx] 开始退出登录
[MUTATION_xxxxx] SET_TOKEN 被调用 (新token: 无token)
[WATCH_xxxxx] TOKEN WATCH 触发 (newToken: 无token)
[WATCH_xxxxx] ⚡ 检测到token清除，立即执行退出操作
[WATCH_xxxxx] 🔄 准备跳转到登录页面
```

### 异常日志示例 2: 状态不同步
```
[MUTATION_xxxxx] SET_TOKEN 被调用 (新token: eyJhbGciOi...)
[WATCH_xxxxx] TOKEN WATCH 触发 (newToken: eyJhbGciOi..., isLoggedIn: false)
... 注意：有 token 但 isLoggedIn 为 false ...
[GUARD_xxxxx] 路由守卫触发 (isLoggedIn: false, hasToken: true)
[GUARD_xxxxx] ⚠️ 未登录用户试图访问受保护页面，重定向到登录页
```

## Rust 日志位置

Rust 后端的日志应该会写入到应用数据目录：
```
macOS: ~/Library/Application Support/com.redcode.im/logs/
```

如果需要查看 Rust 日志，可以在该目录下找到最新的日志文件。

## 下一步

1. **执行测试**: 按照上述流程进行测试
2. **收集日志**: 完整复制控制台日志
3. **提供日志**: 将日志文本提供给我
4. **分析问题**: 我会根据日志分析具体原因
5. **修复问题**: 根据分析结果进行针对性修复

## 注意事项

1. **完整日志**: 请提供从应用启动到问题发生的完整日志，不要只提供部分
2. **时间戳**: 注意日志的时间戳，可以帮助确定事件发生的顺序
3. **调用栈**: 调用栈信息非常重要，可以追溯到问题源头
4. **多次测试**: 如果可能，多测试几次，看问题是否稳定复现
5. **不同场景**: 可以尝试不同的登录方式（密码登录 vs 验证码登录）

## 预期结果

通过这些详细的日志，我们应该能够：
1. 准确定位是哪个代码路径导致的跳转
2. 找到触发跳转的根本原因
3. 进行针对性的修复
4. 验证修复是否有效
