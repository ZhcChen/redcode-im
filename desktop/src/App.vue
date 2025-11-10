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
const showAccountTabs = computed(() => accounts.value.length > 0 && isLoggedIn.value);

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

      // 4. 重新初始化 WebSocket 连接
      await initWebSocketConnection();

      // 5. 刷新数据（联系人、聊天列表等）
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
async function handleRemoveAccount(accountId: string) {
  console.log('移除账号:', accountId);

  try {
    // 登出该账号
    await store.dispatch('accounts/logoutAccount', accountId);

    toast.success('账号已移除');

    // 如果移除后没有账号了，跳转到登录页
    if (accounts.value.length === 0) {
      router.push('/login');
    }
  } catch (error) {
    console.error('❌ 移除账号失败:', error);
    toast.error('移除账号失败');
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

  console.log('🔄 Token变化监听:', {
    newToken: val ? `${val.substring(0, 10)}...` : '无token',
    oldToken: oldVal ? `${oldVal.substring(0, 10)}...` : '无token',
    isLoggedIn: user.value.isLoggedIn,
    currentPath: router.currentRoute.value.path
  });

  if (val) {
    // 有token时跳转到主页（但避免在登录页面时重复跳转）
    if (router.currentRoute.value.path === '/login') {
      console.log('🔄 从登录页面跳转到主页');
      router.push('/home');
    }

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
    // 无token时立即执行退出逻辑
    console.log('⚡ 检测到token清除，立即执行退出操作');
    
    // 立即关闭 WebSocket 连接
    closeWebSocketConnection();
    
    // 隐藏加载蒙版
    if (globalLoading.value.visible) {
      store.dispatch('hideGlobalLoading');
      console.log('🔄 token已清除，隐藏加载蒙版');
    }
    
    // 立即跳转到登录页面（但避免重复跳转）
    if (router.currentRoute.value.path !== '/login') {
      console.log('🔄 跳转到登录页面');
      router.push('/login');
    }
    
    // 跳转到登录页面时强制窗口居中
    createSafeTimeout(async () => {
      await forceWindowCenter();
    }, 50);  // 减少延迟
  }
}, {
  immediate: true
});

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
    <!-- 多账号切换标签（仅在有账号且已登录时显示） -->
    <AccountTabs
      v-if="showAccountTabs"
      :accounts="accounts"
      :current-account-id="currentAccountId"
      @switch="handleAccountSwitch"
      @add="handleAddAccount"
      @remove="handleRemoveAccount"
    />

    <!-- 使用 keep-alive 保持页面状态，key 为当前账号 ID -->
    <keep-alive :include="['Home', 'Chat', 'Contacts', 'Settings']">
      <router-view :key="currentAccountId || 'default'" />
    </keep-alive>

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
}

#app {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
}

/* 账号标签区域 */
#app > .account-tabs {
  flex-shrink: 0;
}

/* 主内容区域 */
#app > div:not(.account-tabs):not(.loading-mask) {
  flex: 1;
  overflow: auto;
}
</style>
