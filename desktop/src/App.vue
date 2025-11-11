<script setup lang="ts">
import { watch, onMounted, onUnmounted, computed } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'
import { invoke } from '@tauri-apps/api/core'
import { webSocketManager } from './utils/websocket'
import { rustHttp } from './api/rust-http'
import { toast } from './utils/toast'
import { eventManager } from './utils/eventManager'
import { memoryMonitor } from './utils/memoryMonitor'
import LoadingMask from './components/LoadingMask.vue'
import AccountTabs from './components/AccountTabs.vue'
import type { AccountInfo } from './store/modules/accounts'

const store = useStore();
const router = useRouter();

// 计算属性
const token = computed(() => store.getters.token);
const user = computed(() => store.getters.currentUser);
const websocket = computed(() => store.state.websocket);
const networkState = computed(() => store.state.networkState);
const globalLoading = computed(() => store.getters.globalLoading);

// 多账号相关计算属性
const accounts = computed(() => store.getters['accounts/allAccounts']);
const currentAccountId = computed(() => store.state.accounts.currentAccountId);
const isLoggedIn = computed(() => store.getters.isLoggedIn);
// 只有多个账号时才显示切换标签
const showAccountTabs = computed(() => accounts.value.length > 1 && isLoggedIn.value);
const keepAliveViews = ['Home', 'Chat', 'Contacts', 'Settings'];

async function ensureAvatarCacheConsistency(reason: string, forceDownload = false) {
  const logId = `AVATAR_VERIFY_${Date.now()}_${reason}`
  const currentUser = store.getters.currentUser
  if (!currentUser?.id) {
    return
  }

  try {
    console.log(`[${logId}] 开始校验头像缓存`, {
      userId: currentUser.id,
      avatarObjectKey: currentUser.avatarObjectKey,
      avatarLocalPath: currentUser.avatarLocalPath,
      forceDownload
    })

    const { UserApi } = await import('./api/user')
    const profileResp = await UserApi.getUserAccountInfo({ userId: 'me' })
    if (!profileResp.success || !profileResp.data) {
      console.warn(`[${logId}] 获取用户信息失败`, profileResp.message)
      return
    }

    const backendUser = profileResp.data
    const backendKey = backendUser.avatarObjectKey ?? null
    const localKey = currentUser.avatarObjectKey ?? null
    const localPath = currentUser.avatarLocalPath ?? null

    let shouldDownload = forceDownload

    if (backendKey !== localKey) {
      console.log(`[${logId}] 发现 avatar_object_key 变更`, { backendKey, localKey })
      store.commit('UPDATE_USER_INFO', {
        avatarObjectKey: backendKey,
        avatarLocalPath: null
      })
      try {
        await store.dispatch('accounts/syncAccountProfile', {
          accountId: currentUser.id,
          userInfo: {
            avatarObjectKey: backendKey,
            avatarLocalPath: null
          }
        })
      } catch (syncError) {
        console.warn(`[${logId}] 同步账号资料失败`, syncError)
      }
      shouldDownload = !!backendKey
    }

    if (!backendKey) {
      if (localKey || localPath) {
        await store.dispatch('accounts/syncAccountProfile', {
          accountId: currentUser.id,
          userInfo: {
            avatarObjectKey: null,
            avatarLocalPath: null
          }
        }).catch((err) => console.warn(`[${logId}] 清空账号缓存失败`, err))
      }
      console.log(`[${logId}] 后端未配置头像，结束校验`)
      return
    }

    // 如果 backendKey 和 localKey 一致，但 localPath 存在，先尝试使用它
    // 只有在 localPath 不存在或无效时才触发下载
    if (backendKey && backendKey === localKey) {
      if (localPath) {
        console.log(`[${logId}] 本地缓存路径存在: ${localPath}`)
        // 验证本地路径是否有效（检查是否是有效的 blob URL 或文件路径）
        if (localPath.startsWith('blob:') || localPath.startsWith('http://') || localPath.startsWith('https://')) {
          console.log(`[${logId}] 本地缓存路径有效，直接使用现有缓存，不触发下载`)
          // localPath 存在且有效，直接使用，不需要下载
          // store 中已经有 avatarLocalPath，组件会自动使用它
          return
        } else {
          console.log(`[${logId}] 本地缓存路径格式异常，准备重新下载`)
          shouldDownload = true
        }
      } else {
        console.log(`[${logId}] 本地缓存路径缺失，准备重新下载`, { backendKey })
        shouldDownload = true
      }
    } else if (backendKey && backendKey !== localKey) {
      // backendKey 和 localKey 不一致的情况已经在上面处理了
      shouldDownload = !!backendKey
    }

    if (shouldDownload) {
      console.log(`[${logId}] 触发头像缓存刷新`)
      await UserApi.syncAvatarCache(true)
    } else {
      console.log(`[${logId}] 缓存与后端一致，跳过下载`)
    }
  } catch (error) {
    console.warn(`[${logId}] 校验头像缓存出现异常`, error)
  }
}

// 账号切换处理
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

      // 4. 检查头像缓存
      await ensureAvatarCacheConsistency('switch-account');

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

// 添加账号处理
async function handleAddAccount() {
  console.log('添加新账号');

  // 检查是否可以添加新账号
  if (!store.getters['accounts/canAddAccount']) {
    toast.warning(`最多支持 ${store.state.accounts.maxAccounts} 个账号`);
    return;
  }

  // 跳转到登录页面添加新账号
  router.push('/login');
}

// 移除账号处理
async function handleRemoveAccount(accountId: string, skipConfirm = false) {
  console.log('移除账号:', accountId, 'skipConfirm:', skipConfirm);

  const account = store.getters['accounts/getAccountById'](accountId);
  if (!account) {
    toast.error('账号不存在');
    return;
  }

  if (!skipConfirm) {
    const confirmed = confirm(`确定要移除账号 "${account.userInfo.nickname}" 吗？`);
    if (!confirmed) {
      console.log('用户取消移除账号');
      return;
    }
  }

  const isCurrentAccount = currentAccountId.value === accountId;

  if (isCurrentAccount) {
    try {
      await webSocketManager.closeWebSocket();
      console.log('✅ 已关闭当前账号 WebSocket 连接');
    } catch (error) {
      console.warn('⚠️ 关闭 WebSocket 连接失败:', error);
    }

    try {
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(null);
      console.log('✅ 已同步清除 Rust 端 token');
    } catch (error) {
      console.warn('⚠️ 清除 Rust token 失败:', error);
    }
  }

  try {
    await store.dispatch('accounts/logoutAccount', accountId);
  } catch (error) {
    console.error('❌ 移除账号失败:', error);
    toast.error('移除账号失败');
    return;
  }

  const remainingAccounts: AccountInfo[] = store.getters['accounts/allAccounts'];

  if (remainingAccounts.length === 0) {
    try {
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(null);
    } catch (error) {
      console.warn('⚠️ 最终清空 Rust token 失败:', error);
    }

    store.commit('SET_TOKEN', null);
    store.commit('LOGOUT_USER');
    toast.success(`账号 ${account.userInfo.nickname} 已移除`);
    router.push('/login');
    return;
  }

  toast.success(`账号 ${account.userInfo.nickname} 已移除`);

  if (isCurrentAccount) {
    const nextAccountId = store.state.accounts.currentAccountId || remainingAccounts[0].id;
    if (nextAccountId) {
      await handleAccountSwitch(nextAccountId);
    }
  }
}

// 使用 Rust 后端强制窗口居中
async function forceWindowCenter() {
  try {
    await invoke('force_center_window');
    console.log("窗口已通过 Rust 后端居中");
  } catch (error) {
    console.error("Rust 后端窗口居中失败:", error);
  }
}

// 初始化 WebSocket 连接（优化：避免重复连接）
async function initWebSocketConnection() {
  const callStack = new Error().stack;
  console.log('🔄 [APP DEBUG] initWebSocketConnection 被调用', {
    hasToken: !!token.value,
    hasUserId: !!user.value.id,
    networkState: networkState.value,
    websocketExists: !!websocket.value,
    callStack: callStack?.split('\n').slice(1, 3) // 显示调用栈前2行
  });

  if (!token.value || !user.value.id) {
    console.log('⚠️ 缺少token或用户ID，跳过WebSocket初始化');
    return;
  }

  // 检查是否已经有活跃连接
  if (networkState.value && websocket.value) {
    console.log('✅ WebSocket已连接，跳过重复初始化');
    return;
  }

  console.log('🔄 初始化 WebSocket 连接');

  const params = {
    userId: user.value.id,
    token: token.value,
    chatGroupId: "00000000" // 默认群组ID
  };

  try {
    await webSocketManager.initWebSocketSafely(params);
    console.log('✅ WebSocket 连接初始化成功');
  } catch (error) {
    console.error('❌ WebSocket 初始化失败:', error);
  }
}

// 关闭 WebSocket 连接
function closeWebSocketConnection() {
  console.log('关闭 WebSocket 连接');
  webSocketManager.closeWebSocket();
}

// 监听 WebSocket 状态变化
function setupWebSocketEventListeners() {
  // 监听聊天消息
  window.addEventListener('websocket-chat-message', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('收到聊天消息:', detail);
    handleChatMessage(detail);
  });

  // 监听 AI 消息
  window.addEventListener('websocket-ai-message', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('收到 AI 消息:', detail);
    handleAIMessage(detail);
  });

  // 监听好友变化
  window.addEventListener('websocket-friend-change', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('好友关系变化:', detail);
    handleFriendChange(detail);
  });

  // 监听删除好友
  window.addEventListener('websocket-delete-friend', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('好友被删除:', detail);
    handleDeleteFriend(detail);
  });

  // 监听朋友圈消息
  window.addEventListener('websocket-friend-circle', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('朋友圈动态:', detail);
    handleFriendCircle(detail);
  });

  // 监听群组相关消息
  window.addEventListener('websocket-launch-group', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('发起群聊:', detail);
    handleLaunchGroup(detail);
  });

  window.addEventListener('websocket-room-created', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('新群聊创建:', detail);
    handleLaunchGroup(detail);
  });

  window.addEventListener('websocket-delete-group', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('群组被解散:', detail);
    handleDeleteGroup(detail);
  });

  // 监听通话消息
  window.addEventListener('websocket-message-update', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('消息更新:', detail);
    handleMessageUpdate(detail);
  });

  window.addEventListener('websocket-message-read', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('消息已读:', detail);
    handleMessageRead(detail);
  });

  window.addEventListener('websocket-pin-update', (event) => {
    const detail = (event as CustomEvent).detail;
    console.log('置顶更新:', detail);
    handlePinUpdate(detail);
  });
}

// 移除 WebSocket 事件监听器
function removeWebSocketEventListeners() {
  window.removeEventListener('websocket-chat-message', handleChatMessage);
  window.removeEventListener('websocket-ai-message', handleAIMessage);
  window.removeEventListener('websocket-friend-change', handleFriendChange);
  window.removeEventListener('websocket-delete-friend', handleDeleteFriend);
  window.removeEventListener('websocket-friend-circle', handleFriendCircle);
  window.removeEventListener('websocket-launch-group', handleLaunchGroup);
  window.removeEventListener('websocket-room-created', handleLaunchGroup);
  window.removeEventListener('websocket-delete-group', handleDeleteGroup);
  window.removeEventListener('websocket-message-update', handleMessageUpdate);
  window.removeEventListener('websocket-message-read', handleMessageRead);
  window.removeEventListener('websocket-pin-update', handlePinUpdate);
}

// 消息处理函数
function handleChatMessage(detail: any) {
  const payload = detail?.message ?? detail
  console.log('处理聊天消息:', payload)
  // 这里可以更新聊天界面，播放提示音等
}

function handleAIMessage(detail: any) {
  // 处理 AI 消息逻辑
  console.log('处理 AI 消息:', detail);
}

function handleFriendChange(detail: any) {
  // 处理好友变化逻辑
  console.log('处理好友变化:', detail);
  // 收到好友申请相关消息后，重新获取数量
  store.dispatch('updatePendingFriendRequests');
}

function handleDeleteFriend(detail: any) {
  // 处理删除好友逻辑
  console.log('处理删除好友:', detail);
  const currentChatGroupId = store.state.currentChatGroupId;
  const deletedGroupId = detail.content?.chatGroupId;
  
  if (deletedGroupId && currentChatGroupId === deletedGroupId) {
    toast.warning('您已被对方删除好友');
    router.push('/home');
  }
  
  // 好友被删除后，也需要更新申请数量
  store.dispatch('updatePendingFriendRequests');
}

function handleFriendCircle(detail: any) {
  // 处理朋友圈消息逻辑
  console.log('处理朋友圈消息:', detail);
}

function handleLaunchGroup(detail: any) {
  // 处理发起群聊逻辑
  console.log('处理发起群聊:', detail);
}

function handleDeleteGroup(detail: any) {
  // 处理群组解散逻辑
  console.log('处理群组解散:', detail);
  const currentChatGroupId = store.state.currentChatGroupId;
  const deletedGroupId = detail.chatGroupId;
  
  if (deletedGroupId && currentChatGroupId === deletedGroupId) {
    toast.warning('当前群组已被解散');
    router.push('/home');
  }
}

function handleMessageUpdate(detail: any) {
  console.log('处理消息更新事件:', detail);
}

function handleMessageRead(detail: any) {
  console.log('处理消息已读事件:', detail);
  const roomId = detail?.room_id || detail?.roomId;
  if (roomId) {
    store.dispatch('setChatUnreadCount', { groupId: roomId, unreadCount: 0 });
  }
}

function handlePinUpdate(detail: any) {
  console.log('处理消息置顶事件:', detail);
  const roomId = detail?.room_id || detail?.roomId;
  const isPinned = detail?.is_pinned ?? detail?.isPinned;
  if (roomId !== undefined && isPinned !== undefined) {
    const chat = store.getters.getChatByGroupId(roomId);
    if (chat) {
      store.dispatch('updateChatItem', { ...chat, isTop: !!isPinned });
    }
  }
}

// 监听页面可见性变化
// 页面可见性变化处理
function handleVisibilityChange() {
  if (document.hidden) {
    console.log('页面隐藏，保持 WebSocket 连接');
  } else {
    console.log('页面可见，检查 WebSocket 连接状态');
    // 只有在确实没有连接时才重新连接
    if (token.value && user.value.id && !networkState.value && !websocket.value) {
      console.log('⚠️ 检测到WebSocket断开，尝试重新连接');
      initWebSocketConnection();
    }
  }
}

// 定时器管理
const timers = new Set<number>();

// 创建安全的定时器
function createSafeTimeout(callback: () => void, delay: number): number {
  const timerId = window.setTimeout(() => {
    timers.delete(timerId);
    callback();
  }, delay);
  timers.add(timerId);
  return timerId;
}

// 清理所有定时器
function clearAllTimers() {
  console.log('🧹 清理所有定时器，当前数量:', timers.size);
  timers.forEach(timerId => {
    clearTimeout(timerId);
  });
  timers.clear();
}

// 监听 token 变化，控制路由跳转和 WebSocket 连接
watch(token, async (val, oldVal) => {
  // 先清理所有定时器，防止累积
  clearAllTimers();

  const watchId = `WATCH_${Date.now()}`;
  console.log(`[${watchId}] ========== TOKEN WATCH 触发 ==========`);
  console.log(`[${watchId}] 🔄 Token变化监听:`, {
    newToken: val ? `${val.substring(0, 10)}...` : '无token',
    oldToken: oldVal ? `${oldVal.substring(0, 10)}...` : '无token',
    isLoggedIn: user.value.isLoggedIn,
    currentPath: router.currentRoute.value.path,
    callStack: new Error().stack?.split('\n').slice(2, 5).join('\n')
  });

  if (val) {
    // 检查是否在独立的登录窗口中
    let isLoginWindow = false;
    try {
      const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
      const currentWindow = getCurrentWebviewWindow();
      const windowLabel = currentWindow.label;
      isLoginWindow = windowLabel.startsWith('login-');
      console.log('当前窗口:', windowLabel, '是否为登录窗口:', isLoginWindow);
    } catch (error) {
      console.warn('检测窗口类型失败:', error);
    }

    // 有token时跳转到主页（但独立登录窗口不跳转）
    if (router.currentRoute.value.path === '/login' && !isLoginWindow) {
      console.log('🔄 从登录页面跳转到主页');
      router.push('/home');
    }

    // 独立登录窗口不需要初始化 WebSocket 和更新标题
    if (!isLoginWindow) {
      // 登录成功后延迟初始化 WebSocket 连接，确保用户状态完全同步
      createSafeTimeout(() => {
        // 再次验证登录状态
        if (store.getters.isLoggedIn && store.state.token === val) {
          console.log('🔄 Token变化触发WebSocket连接初始化');
          initWebSocketConnection();
        } else {
          console.warn('⚠️ 用户状态未同步，跳过WebSocket初始化');
        }
      }, 800); // 增加延迟确保状态同步

      // 更新窗口标题（添加更长延迟确保用户信息已更新）
      createSafeTimeout(async () => {
        try {
          // 验证用户信息是否已正确设置
          if (user.value.id && user.value.username) {
            console.log('🔄 App.vue token watch - 准备更新窗口标题，当前用户信息:', user.value);
            const { updateWindowTitle } = await import('@/utils');
            await updateWindowTitle(user.value);
          } else {
            console.warn('⚠️ 用户信息不完整，跳过窗口标题更新');
          }
        } catch (error) {
          console.warn('更新窗口标题失败:', error);
        }
      }, 300); // 增加延迟确保用户信息已同步
    } else {
      console.log('🔕 独立登录窗口，跳过 WebSocket 初始化和窗口标题更新');
    }
  } else {
    // 无token时立即执行退出逻辑
    console.log(`[${watchId}] ⚡ 检测到token清除，立即执行退出操作`);
    console.log(`[${watchId}] 调用栈:`, new Error().stack);
    
    // 立即关闭 WebSocket 连接
    closeWebSocketConnection();
    
    // 隐藏加载蒙版
    if (globalLoading.value.visible) {
      store.dispatch('hideGlobalLoading');
      console.log(`[${watchId}] 🔄 token已清除，隐藏加载蒙版`);
    }
    
    // 立即跳转到登录页面（但避免重复跳转）
    if (router.currentRoute.value.path !== '/login') {
      console.log(`[${watchId}] 🔄 准备跳转到登录页面，当前路径: ${router.currentRoute.value.path}`);
      router.push('/login');
      console.log(`[${watchId}] ✅ 已执行跳转到登录页面`);
    } else {
      console.log(`[${watchId}] ⏭️ 已在登录页，跳过跳转`);
    }
    
    // 跳转到登录页面时强制窗口居中
    createSafeTimeout(async () => {
      await forceWindowCenter();
    }, 50);  // 减少延迟
  }
  
  console.log(`[${watchId}] ========== TOKEN WATCH 结束 ==========`);
}, {
  immediate: true
});

watch(isLoggedIn, (loggedIn) => {
  if (loggedIn) {
    ensureAvatarCacheConsistency('login-state').catch((error) => {
      console.warn('[App] login-state avatar校验失败:', error)
    })
  }
})

// 监听 WebSocket 连接状态变化
watch(websocket, (newWebSocket) => {
  if (newWebSocket) {
    console.log('WebSocket 连接已建立');
  } else {
    console.log('WebSocket 连接已断开');
  }
});

// 禁用右键菜单
let contextMenuHandler: ((event: MouseEvent) => boolean) | null = null;

function disableContextMenu() {
  contextMenuHandler = (event: MouseEvent) => {
    event.preventDefault();
    return false;
  };

  document.addEventListener('contextmenu', contextMenuHandler);
  console.log('🚫 已禁用浏览器右键菜单');
}

// 恢复右键菜单
function enableContextMenu() {
  if (contextMenuHandler) {
    document.removeEventListener('contextmenu', contextMenuHandler);
    contextMenuHandler = null;
    console.log('🔓 已恢复浏览器右键菜单');
  }
}

// 组件挂载时设置事件监听
onMounted(async () => {
  console.log('App 组件已挂载');

  // 检查是否是独立登录窗口
  let isLoginWindow = false;
  try {
    const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
    const currentWindow = getCurrentWebviewWindow();
    const windowLabel = currentWindow.label;
    isLoginWindow = windowLabel.startsWith('login-');
    console.log('当前窗口:', windowLabel, '是否为登录窗口:', isLoginWindow);
  } catch (error) {
    console.warn('检测窗口类型失败:', error);
  }

  // 独立登录窗口不恢复账号状态，保持干净的登录环境
  if (!isLoginWindow) {
    // 检查是否需要迁移 localStorage 数据
    try {
      const { needsMigration, migrateAccounts } = await import('./utils/accountMigration');
      const shouldMigrate = await needsMigration();

      if (shouldMigrate) {
        console.log('🔄 检测到需要迁移账号数据...');
        const result = await migrateAccounts();

        if (result.success) {
          console.log(`✅ ${result.message}`);
          toast.success(result.message);
        } else {
          console.error(`❌ ${result.message}`);
          toast.error(result.message);
        }
      }
    } catch (error) {
      console.error('❌ 账号数据迁移失败:', error);
    }

    // 从 Rust SQLite 恢复账号列表
    try {
      await store.dispatch('accounts/loadAccountsFromStorage');
      console.log('✅ 账号列表已从 SQLite 恢复');

      // 如果有当前账号，恢复其状态
      const currentAccount = store.getters['accounts/currentAccount'];
      if (currentAccount) {
        store.commit('SET_TOKEN', currentAccount.token);
        store.commit('SET_USER', currentAccount.userInfo);
        console.log('✅ 已恢复当前账号状态:', currentAccount.userInfo.nickname);

        await ensureAvatarCacheConsistency('app-initial-load');
      }
    } catch (error) {
      console.error('❌ 恢复账号列表失败:', error);
    }
  } else {
    console.log('🔕 独立登录窗口，跳过账号恢复');
  }

  // 确保全局加载蒙版是隐藏状态
  if (globalLoading.value.visible) {
    console.warn('检测到全局加载蒙版意外显示,立即隐藏');
    store.dispatch('hideGlobalLoading');
  }

  // 初始化 Rust HTTP 客户端 (不阻塞其他初始化)
  rustHttp.initialize(token.value || undefined)
    .then(() => {
      console.log('✅ Rust HTTP 客户端初始化完成');
    })
    .catch((error) => {
      console.error('❌ Rust HTTP 客户端初始化失败:', error);
      // 不显示错误提示,因为可能是正常的未连接状态
    });

  // 设置 WebSocket 事件监听
  console.log('设置全局 WebSocket 事件监听');
  setupWebSocketEventListeners();
  
  // 使用事件管理器添加监听器
  eventManager.addDocumentListener('visibilitychange', handleVisibilityChange);
  eventManager.addWindowListener('beforeunload', closeWebSocketConnection);
  
  // 初始化窗口标题
  try {
    const { updateWindowTitle } = await import('@/utils');
    if (token.value && user.value.mobile) {
      console.log('🔄 App.vue onMounted - 检测到已登录用户，设置标题:', user.value);
      await updateWindowTitle(user.value);
    } else {
      console.log('🔄 App.vue onMounted - 未登录，设置默认标题');
      await updateWindowTitle(); // 显示默认标题
    }
  } catch (error) {
    console.warn('初始化窗口标题失败:', error);
  }
  
  // 开发模式下启用调试工具
  if (import.meta.env.DEV) {
    // 启动内存监控
    memoryMonitor.startMonitoring();
    console.log('🔍 内存监控已启动');
  }

  // 禁用浏览器右键菜单
  disableContextMenu();

  // 监听新账号添加事件（来自独立登录窗口）
  let unlistenAccountAdded: (() => void) | null = null;
  (async () => {
    try {
      const { listen } = await import('@tauri-apps/api/event');
      unlistenAccountAdded = await listen('account-added', (event) => {
        console.log('🔔 收到新账号添加事件:', event.payload);
        // 账号已经在 Login.vue 中添加到 store，这里只需要显示提示
        const payload = event.payload as { accountId: string; nickname: string };
        toast.success(`账号 ${payload.nickname} 已添加`);
      });
      console.log('✅ 已注册账号添加事件监听');
    } catch (error) {
      console.warn('注册账号添加事件监听失败:', error);
    }
  })();
});

// 组件卸载时清理
onUnmounted(() => {
  console.log('App 组件卸载，清理 WebSocket 连接和事件监听');
  
  // 清理所有定时器
  clearAllTimers();
  
  // 清理所有事件监听器
  eventManager.clearAllListeners();
  
  // 停止内存监控
  memoryMonitor.stopMonitoring();

  // 恢复浏览器右键菜单
  enableContextMenu();

  removeWebSocketEventListeners();
  closeWebSocketConnection();
});
</script>

<template>
  <div id="app">
    <!-- 多账号切换标签（仅在多账号时显示） -->
    <div v-if="showAccountTabs" class="account-tabs-wrapper">
      <AccountTabs
        :accounts="accounts"
        :current-account-id="currentAccountId"
        :show-add-button="false"
        @switch="handleAccountSwitch"
        @remove="(accountId) => handleRemoveAccount(accountId, true)"
      />
    </div>

    <div :class="['app-main', { 'app-main--with-tabs': showAccountTabs }]">
      <!-- keep-alive 仅缓存视图，保持单一组件实例 -->
      <router-view v-slot="{ Component }">
        <keep-alive :include="keepAliveViews">
          <component :is="Component" />
        </keep-alive>
      </router-view>
    </div>

    <!-- 全局加载蒙版 -->
    <LoadingMask
      :visible="globalLoading.visible"
      :text="globalLoading.text"
    />
  </div>
</template>

<style>
body {
  margin: 0;
  padding: 0;
  overflow: hidden;
}

#app {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
}

.account-tabs-wrapper {
  flex-shrink: 0;
  height: 42px;
  z-index: 100;
  border-bottom: 1px solid rgba(148, 163, 184, 0.35);
  background: var(--bg-color, #fff);
}

.app-main {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 确保 router-view 及其内部组件正确继承高度 */
.app-main :deep(> *) {
  height: 100%;
  min-height: 0;
}

/* 移除固定高度，让 flexbox 自动处理高度分配 */
.app-main--with-tabs {
  /* height 属性已移除，使用 flex: 1 自动计算高度 */
}
</style>
