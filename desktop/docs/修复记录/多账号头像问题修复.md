# 多账号切换与头像持久化问题修复

## 问题描述

测试账号：alice  
登录方式：验证码 (666666)

### 问题 1: 多账号切换标签导致主内容高度问题
- **现象**: 当有多个账号时，顶部显示账号切换标签，导致底部内容被遮挡
- **原因**: `AccountTabs` 组件添加在 `App.vue` 顶部，但子视图使用 `height: 100vh`，未考虑标签高度

### 问题 2: 头像更新后重新登录恢复默认头像
- **现象**: 头像成功上传到腾讯 COS 并保存到数据库，但重新登录后显示默认头像
- **原因**: 账号切换和重新登录时，未调用 `syncAvatarCache` 恢复本地缓存的头像文件

## 修复方案

### 修复 1: 高度计算问题

#### 文件: `src/App.vue`
```scss
.account-tabs-wrapper {
  flex-shrink: 0;
  height: 42px;  // 明确设置高度
  z-index: 100;
  border-bottom: 1px solid rgba(148, 163, 184, 0.35);
  background: var(--bg-color, #fff);
}

.app-main {
  flex: 1;
  min-height: 0;
  height: calc(100vh - 42px);  // 减去标签高度
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
```

#### 文件: `src/views/Home.vue`
```scss
.home {
  width: 100%;
  height: 100%;  // 改为 100% 而不是 100vh
  overflow: hidden;
}
```

**说明**: 
- `AccountTabs` 高度固定为 42px
- `app-main` 使用 `calc(100vh - 42px)` 计算可用高度
- 子视图使用相对高度 `100%` 而不是绝对高度 `100vh`

### 修复 2: 头像持久化问题

#### 文件: `src/App.vue` - `handleAccountSwitch` 函数
```typescript
async function handleAccountSwitch(accountId: string) {
  console.log('切换账号:', accountId);

  try {
    // 1. 切换当前账号
    await store.dispatch('accounts/switchAccount', accountId);

    // 2. 切换 Vuex store 中的 token 和用户信息
    const account = store.getters['accounts/getAccountById'](accountId);
    if (account) {
      store.commit('SET_TOKEN', account.token);
      store.commit('SET_USER', account.userInfo);

      // 3. 同步 Rust 后端 token
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(account.token);

      // 4. 同步头像缓存 ⭐ 新增
      const { UserApi } = await import('./api/user');
      await UserApi.syncAvatarCache(false);

      // 5. 重新初始化 WebSocket 连接
      await initWebSocketConnection();

      // 6. 刷新数据（联系人、聊天列表等）
      store.dispatch('loadChatList', { forceRefresh: true });
      store.dispatch('loadContacts', { forceRefresh: true });

      console.log('✅ 账号切换成功');
    }
  } catch (error) {
    console.error('❌ 账号切换失败:', error);
    toast.error('账号切换失败');
  }
}
```

#### 文件: `src/store/modules/accounts.ts` - `loadAccountsFromStorage` 函数
```typescript
async loadAccountsFromStorage({ commit }) {
  try {
    // 初始化账号管理器
    await invoke('account_init')

    // 加载所有账号
    const accounts = await loadAccountsFromRust()
    const currentAccountId = await loadCurrentAccountFromRust()

    accounts.forEach(account => {
      commit('ADD_ACCOUNT', account)
    })

    if (currentAccountId && accounts.some(acc => acc.id === currentAccountId)) {
      commit('SET_CURRENT_ACCOUNT', currentAccountId)
    }

    // 如果有当前账号，同步头像缓存 ⭐ 新增
    if (currentAccountId) {
      try {
        const { UserApi } = await import('../../api/user')
        await UserApi.syncAvatarCache(false)
      } catch (error) {
        console.warn('同步头像缓存失败:', error)
      }
    }
  } catch (error) {
    console.error('加载账号列表失败:', error)
  }
}
```

**说明**:
- 账号切换时调用 `UserApi.syncAvatarCache(false)` 恢复头像缓存
- 从 SQLite 加载账号后，如果有当前账号，也调用 `syncAvatarCache` 恢复头像
- `syncAvatarCache` 会检查本地缓存，如果存在且 `avatarObjectKey` 匹配则直接使用，否则从服务器下载

## 技术细节

### 头像缓存机制
1. **上传流程**: 
   - 用户选择头像 → 上传到 COS → 获取 `avatarObjectKey` 和 `avatarUrl`
   - 保存到本地缓存 (`AvatarCache.save`) → 更新 store (`avatarLocalPath`)
   - 同步到 SQLite (`syncAccountProfile`)

2. **恢复流程**:
   - 从 SQLite 加载账号信息 (包含 `avatarUrl` 和 `avatarObjectKey`)
   - 调用 `syncAvatarCache` 检查本地缓存
   - 如果缓存存在且匹配，直接使用本地路径
   - 如果缓存不存在，从服务器下载并缓存

3. **关键字段**:
   - `avatar`: 头像 URL (存储在 SQLite)
   - `avatarObjectKey`: COS 对象键 (存储在 SQLite)
   - `avatarLocalPath`: 本地缓存路径 (仅存储在内存 store)

## 测试验证

### 测试场景 1: 多账号切换
1. 登录账号 A
2. 添加账号 B
3. 切换到账号 B
4. 验证：底部内容不被遮挡，头像正确显示

### 测试场景 2: 头像持久化
1. 登录账号 alice
2. 上传新头像
3. 退出登录
4. 重新登录
5. 验证：头像显示为上传的新头像，而不是默认头像

### 测试场景 3: 多账号头像独立
1. 登录账号 A，上传头像 A
2. 添加账号 B，上传头像 B
3. 切换到账号 A
4. 验证：显示头像 A
5. 切换到账号 B
6. 验证：显示头像 B

## 相关文件

- `src/App.vue` - 主应用组件，处理账号切换
- `src/views/Home.vue` - 主页视图，高度计算
- `src/components/AccountTabs.vue` - 账号切换标签组件
- `src/store/modules/accounts.ts` - 账号管理模块
- `src/api/user.ts` - 用户 API，包含头像上传和缓存同步
- `src/utils/avatar-cache.ts` - 头像缓存工具

## 注意事项

1. 头像缓存依赖 `avatarObjectKey` 匹配，确保上传后正确保存
2. 账号切换时会重新初始化 WebSocket 连接
3. 多账号场景下，每个账号的头像独立缓存
4. 本地缓存路径 (`avatarLocalPath`) 不持久化到 SQLite，每次启动时重新解析
