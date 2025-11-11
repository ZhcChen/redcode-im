# 登录后自动跳回登录页问题修复

## 问题描述

**现象**: 用户登录后，过 2-5 秒左右会自动跳回登录页面

**影响**: 用户无法正常使用应用，体验极差

## 根因分析

通过分析路由守卫、请求拦截器、WebSocket 逻辑和退出登录相关代码，发现了两个导致自动跳转的问题：

### 问题 1: HTTP 401 错误处理逻辑缺陷 ⭐ 主要原因

**位置**: `src/api/http.ts` - `handleUnauthorizedResponse` 方法

**问题代码**:
```typescript
const isInLoginGracePeriod = this.lastLoginTime && (Date.now() - this.lastLoginTime) < 30000;
const currentPath = typeof window !== 'undefined' ? window.location.pathname : '';
const isLoginRelated = currentPath === '/login' || currentPath === '/home' || Boolean(isInLoginGracePeriod);

if (isLoginRelated && isInLoginGracePeriod) {
  console.warn(`⚠️ [${requestId}] 登录后宽容期内的401错误，跳过自动登出处理`);
  throw new Error('登录验证中，请稍后重试');
}
```

**问题分析**:
1. 登录后 30 秒内为"宽容期"，理论上应该跳过 401 自动登出
2. 但条件判断 `isLoginRelated && isInLoginGracePeriod` 要求**同时满足**两个条件
3. `isLoginRelated` 包含了 `Boolean(isInLoginGracePeriod)`，导致逻辑冗余
4. 更关键的是，即使在宽容期内抛出错误，后续仍然会执行 3 秒延迟的自动登出逻辑
5. 实际执行流程：
   - 登录成功，设置 `lastLoginTime`
   - 某个请求返回 401（可能是 WebSocket 初始化或其他 API）
   - 虽然在宽容期内，但仍然设置了 `isLoggingOut = true`
   - 3 秒后执行 `store.dispatch('logout')`
   - token 被清除，触发 `App.vue` 的 token watch
   - 自动跳转到登录页

**修复方案**:
- 简化宽容期判断逻辑，只检查 `isInLoginGracePeriod`
- 在宽容期内直接 `throw Error`，不执行后续的自动登出逻辑
- 将宽容期从 30 秒延长到 60 秒，给登录过程更多时间

### 问题 2: main.ts 中的 Fallback 定时器

**位置**: `src/main.ts` - 应用启动后 5 秒的 fallback 定时器

**问题代码**:
```typescript
fallbackTimer = window.setTimeout(async () => {
  console.warn("[Main] Fallback: 强制隐藏加载蒙版并跳转登录页");
  // ... 无条件跳转到登录页
  if (router.currentRoute.value.name !== "Login") {
    await router.replace({ name: "Login" });
  }
}, 5000);
```

**问题分析**:
1. 这个定时器在应用启动后 5 秒无条件触发
2. 如果用户在 5 秒内完成登录，定时器仍然会触发
3. 导致已登录用户被强制跳回登录页

**修复方案**:
- 在 fallback 逻辑中检查登录状态
- 只在未登录且不在登录页时才执行跳转
- 已登录用户跳过 fallback 处理

## 修复内容

### 修复 1: 优化 401 错误处理逻辑

**文件**: `src/api/http.ts`

```typescript
private handleUnauthorizedResponse(
  requestId: string,
  fullUrl: string,
  method: string,
  requestHeaders: Record<string, string>,
  responseMessage?: string
): never {
  // ... 日志记录 ...

  // 登录后 60 秒宽容期，避免登录过程中的 401 导致自动登出
  const isInLoginGracePeriod = this.lastLoginTime && (Date.now() - this.lastLoginTime) < 60000;
  
  if (isInLoginGracePeriod) {
    console.warn(`⚠️ [${requestId}] 登录后宽容期内的401错误，跳过自动登出处理`);
    throw new Error('登录验证中，请稍后重试');
  }

  // ... 后续的自动登出逻辑 ...
}
```

**改进点**:
- ✅ 简化条件判断，只检查宽容期
- ✅ 宽容期延长到 60 秒
- ✅ 在宽容期内直接抛出错误，不执行自动登出

### 修复 2: 优化 Fallback 定时器逻辑

**文件**: `src/main.ts`

```typescript
fallbackTimer = window.setTimeout(async () => {
  console.warn("[Main] Fallback: 检查应用状态");
  
  // 只在未登录且不在登录页时才执行 fallback 逻辑
  const isLoggedIn = store.getters.isLoggedIn;
  const currentPath = router.currentRoute.value.path;
  
  if (isLoggedIn) {
    console.log("[Main] Fallback: 用户已登录，跳过 fallback 处理");
    return;
  }
  
  if (currentPath === '/login') {
    console.log("[Main] Fallback: 已在登录页，跳过 fallback 处理");
    return;
  }
  
  // ... 执行 fallback 逻辑 ...
}, 5000);
```

**改进点**:
- ✅ 检查登录状态，已登录用户跳过处理
- ✅ 检查当前路由，已在登录页跳过处理
- ✅ 避免误跳转

## 相关代码流程

### 登录流程
1. 用户输入账号密码/验证码
2. 调用登录 API (`/auth/login` 或 `/auth/login/sms`)
3. 登录成功，设置 token 和用户信息
4. 调用 `setLoginTime()` 记录登录时间
5. 初始化 WebSocket 连接
6. 跳转到主页

### Token Watch 流程 (App.vue)
```typescript
watch(token, async (val, oldVal) => {
  if (val) {
    // 有 token，跳转到主页
    if (router.currentRoute.value.path === '/login') {
      router.push('/home');
    }
  } else {
    // 无 token，跳转到登录页
    if (router.currentRoute.value.path !== '/login') {
      router.push('/login');
    }
  }
}, { immediate: true });
```

### 路由守卫流程 (router/index.ts)
```typescript
router.beforeEach(async (to, from, next) => {
  const isLoggedIn = store.getters.isLoggedIn;
  
  // 已登录访问登录页 → 重定向到主页
  if (isLoggedIn && to.name === 'Login') {
    next({ name: 'Home', replace: true });
    return;
  }
  
  // 未登录访问受保护页面 → 重定向到登录页
  if (!isLoggedIn && to.name !== 'Login') {
    next({ name: 'Login', replace: true });
    return;
  }
  
  next();
});
```

## 测试验证

### 测试场景 1: 正常登录
1. 打开应用
2. 输入账号密码/验证码
3. 点击登录
4. 验证：成功跳转到主页，不会自动跳回登录页

### 测试场景 2: 登录后立即操作
1. 登录成功
2. 立即进行操作（发送消息、查看联系人等）
3. 验证：操作正常，不会被强制登出

### 测试场景 3: 登录后等待
1. 登录成功
2. 等待 5-10 秒
3. 验证：仍然保持登录状态，不会自动跳回登录页

### 测试场景 4: 真实 401 错误
1. 登录成功
2. 等待 60 秒以上（超过宽容期）
3. 手动触发一个会返回 401 的请求
4. 验证：正确执行自动登出，跳转到登录页

## 注意事项

1. **宽容期时长**: 设置为 60 秒，可根据实际情况调整
2. **登录时间记录**: 确保在登录成功后调用 `setLoginTime()`
3. **401 错误处理**: 宽容期内的 401 错误会抛出异常，但不会触发自动登出
4. **Fallback 定时器**: 只在未登录状态下才会执行跳转逻辑

## 相关文件

- `src/api/http.ts` - HTTP 请求拦截器和 401 错误处理
- `src/main.ts` - 应用启动和 fallback 逻辑
- `src/App.vue` - Token 监听和路由跳转
- `src/router/index.ts` - 路由守卫
- `src/store/index.ts` - 登录和登出 action

## 后续优化建议

1. **优化 WebSocket 初始化时机**: 确保在 token 完全同步后再初始化 WebSocket
2. **添加登录状态同步机制**: 确保 token、用户信息、登录状态三者完全同步
3. **优化错误处理**: 区分不同类型的 401 错误（token 过期 vs token 无效）
4. **添加重试机制**: 对于宽容期内的 401 错误，可以考虑自动重试
