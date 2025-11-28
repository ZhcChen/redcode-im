<script setup lang="ts">
import { watch, onMounted, onUnmounted, computed, ref } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'
import { invoke } from '@tauri-apps/api/core'
import { webSocketManager } from './utils/websocket'
import { rustHttp } from './api/rust-http'
import { WebSocketApi } from './api/websocket'
import { toast } from './utils/toast'
import { eventManager } from './utils/eventManager'
import { memoryMonitor } from './utils/memoryMonitor'
import { initializeDownloadDir } from './utils/download-settings'
import { NotificationApi } from './api/notification'
import { VersionApi } from './api/version'
import LoadingMask from './components/LoadingMask.vue'
import AccountTabs from './components/AccountTabs.vue'
import AccountHome from './components/AccountHome.vue'
import type { AccountInfo } from './store/modules/accounts'

const store = useStore();
const router = useRouter();

// 更新事件报告帮助函数
const reportUpdateEvent = async (
  eventType: 'download_success' | 'download_failed' | 'apply_success' | 'apply_failed' | 'rollback',
  message?: string,
  version?: AppVersionInfo,
  triggerSource: 'manual' | 'auto' | 'notification' = 'manual'
) => {
  try {
    const currentVersion = store.getters.currentVersion || '1.0.0';
    const patchVersion = version?.version || currentVersion;
    const currentUser = store.getters.currentUser;

    await VersionApi.reportUpdateEvent({
      platform: 'windows', // 桌面端固定为windows
      channel: version?.channel || 'stable',
      base_version: currentVersion,
      patch_version: patchVersion,
      event_type: eventType,
      client_id: currentUser?.id,
      message: message,
      build_number: version?.build_number,
      trigger_source: triggerSource,
      // 其他字段（client_type, os_version, os_arch, app_arch, device_info）会由API自动收集
    });
  } catch (error) {
    console.warn('[Update Event] 报告失败:', error);
    // 不影响主要更新流程
  }
};

// 计算属性
const token = computed(() => store.getters.token);
const user = computed(() => store.getters.currentUser);
const websocket = computed(() => store.state.websocket);
const networkState = computed(() => store.state.networkState);
const globalLoading = computed(() => store.getters.globalLoading);
const versionState = computed(() => store.getters.appVersion);
const currentVersionInfo = computed(() => versionState.value.current);

// 多账号相关计算属性
const accounts = computed(() => store.getters['accounts/allAccounts']);
const currentAccountId = computed(() => store.state.accounts.currentAccountId);
const isLoggedIn = computed(() => store.getters.isLoggedIn);
// 只有多个账号时才显示切换标签
const showAccountTabs = computed(() => accounts.value.length > 1 && isLoggedIn.value);
const keepAliveViews = ['Home', 'Chat', 'Contacts', 'Settings'];
const latestVersion = computed(() => store.getters.latestVersionInfo);
const hasAppUpdate = computed(() => store.getters.hasAppUpdate);
const downloadButtonLabel = computed(() => {
  if (installInProgress.value) {
    return '安装中...';
  }
  if (updateDownloadStatus.value === 'downloading') {
    return `下载中 ${Math.floor(updateDownloadProgress.value)}%`;
  }
  if (updateDownloadStatus.value === 'finished' && downloadedInstallerPath.value) {
    return '重新安装';
  }
  return '立即更新';
});

const shouldShowUpdateButton = computed(() => {
  if (installInProgress.value) return false;
  if (updateDownloadStatus.value === 'downloading') return false;
  return true;
});

const showUpdateDialog = ref(false);
const updateMandatory = ref(false);
const updateDownloadInProgress = ref(false);
const updatePromptHandled = ref(false);
const updateNotice = ref('');
const lastPromptedVersion = ref<string | null>(null);
const updateDownloadProgress = ref(0);
const updateDownloadStatus = ref<'idle' | 'downloading' | 'finished' | 'error'>('idle');
const isTauriRuntime =
  typeof window !== 'undefined' &&
  Boolean(
    (window as any).__TAURI_INTERNALS__ ||
      (window as any).__TAURI_IPC__ ||
      (window as any).__TAURI__
  );
let unlistenUpdateDownload: (() => void) | null = null;
const downloadedInstallerPath = ref<string | null>(null);
const installInProgress = ref(false);
const isMacPlatform = typeof navigator !== 'undefined' ? /mac|darwin/i.test(navigator.userAgent) : false;

type DownloadEventPayload = {
  status: 'started' | 'progress' | 'finished' | 'error';
  received?: number;
  total?: number;
  progress?: number;
  file_path?: string;  // 修正：使用 file_path 匹配 Rust 发送的字段名
  message?: string;
};

function maybeShowUpdatePrompt(forcePrompt = false) {
  const info = latestVersion.value;
  if (!hasAppUpdate.value || !info) {
    return;
  }

  const versionChanged = !!info.version && info.version !== lastPromptedVersion.value;
  if (versionChanged) {
    lastPromptedVersion.value = info.version ?? null;
    updatePromptHandled.value = false;
  }

  if (forcePrompt || !updatePromptHandled.value || info.mandatory) {
    updateMandatory.value = !!info.mandatory;
    updateNotice.value = '';
    updateDownloadStatus.value = 'idle';
    updateDownloadProgress.value = 0;
    updateDownloadInProgress.value = false;
    installInProgress.value = false;
    downloadedInstallerPath.value = null;
    showUpdateDialog.value = true;
  }
}

async function checkForUpdates(forcePrompt = false) {
  try {
    await store.dispatch('checkAppUpdate');
    maybeShowUpdatePrompt(forcePrompt);
  } catch (error) {
  }
}

// 定时器相关
const CROSS_ACCOUNT_REFRESH_INTERVAL = 5000;
let unreadRefreshTimer: number | null = null;
let unreadRefreshInProgress = false;
let unreadRefreshPending = false;

async function triggerCrossAccountUnreadRefresh(reason: string) {
  if (accounts.value.length <= 1) {
    return;
  }

  if (unreadRefreshInProgress) {
    unreadRefreshPending = true;
    return;
  }

  unreadRefreshInProgress = true;
  try {
    await store.dispatch('accounts/refreshAllAccountsUnreadCount');
  } catch (error) {
  } finally {
    unreadRefreshInProgress = false;
    if (unreadRefreshPending) {
      unreadRefreshPending = false;
      window.setTimeout(() => triggerCrossAccountUnreadRefresh('pending-drain'), 0);
    }
  }
}

function handleDownloadEvent(payload: DownloadEventPayload) {
  switch (payload.status) {
    case 'started':
      updateDownloadInProgress.value = true;
      updateDownloadStatus.value = 'downloading';
      updateDownloadProgress.value = 0;
      installInProgress.value = false;
      downloadedInstallerPath.value = null;
      break;
    case 'progress':
      updateDownloadInProgress.value = true;
      updateDownloadStatus.value = 'downloading';
      if (typeof payload.progress === 'number') {
        updateDownloadProgress.value = Math.min(100, Math.max(0, payload.progress));
      }
      if (payload.received && payload.total) {
        updateDownloadProgress.value = Math.min(
          100,
          Math.round((payload.received / payload.total) * 1000) / 10
        );
      }
      break;
    case 'finished':
      updateDownloadProgress.value = 100;
      updateDownloadStatus.value = 'finished';
      updateDownloadInProgress.value = false;
      downloadedInstallerPath.value = payload.file_path ?? null;

      // 报告下载成功事件
      reportUpdateEvent('download_success', `下载完成，文件路径: ${payload.file_path}`, latestVersion.value);

      if (payload.file_path) {
        updateNotice.value = '安装包下载完成，正在准备安装...';
        beginInstallDownloadedUpdate(payload.file_path);
      } else {
        updateNotice.value = '下载完成，请手动运行安装包完成更新。';
      }
      break;
    case 'error':
      updateDownloadStatus.value = 'error';
      updateDownloadInProgress.value = false;
      installInProgress.value = false;
      downloadedInstallerPath.value = null;
      updateNotice.value = payload.message || '下载更新失败，请稍后重试。';
      toast.error(updateNotice.value);

      // 报告下载失败事件
      reportUpdateEvent('download_failed', payload.message || '下载更新失败', latestVersion.value);

      break;
    default:
      break;
  }
}

async function beginInstallDownloadedUpdate(installerPath: string, fileName?: string) {
  if (!isTauriRuntime || !installerPath) {
    return;
  }
  installInProgress.value = true;
  updateNotice.value = '安装程序已启动，应用即将重启以完成更新。';

  // 记录安装尝试事件
  reportUpdateEvent('apply_success', `开始安装更新包: ${installerPath}`, latestVersion.value);

  try {
    await invoke('install_update', {
      installerPath,
      platform: latestVersion.value?.platform || 'macos'
    });

    // 记录安装成功事件（这里可能不会执行，因为应用会重启）
    reportUpdateEvent('apply_success', '安装程序启动成功，应用即将重启', latestVersion.value);

    setTimeout(() => {
      handleQuitApp();
    }, 1500);
  } catch (error: any) {
    installInProgress.value = false;
    updateDownloadStatus.value = 'error';
    updateNotice.value = '启动安装失败，请手动运行下载的安装包。';
    toast.error(error?.message || '启动安装失败');

    // 记录安装失败事件
    reportUpdateEvent('apply_failed', `启动安装失败: ${error?.message || '未知错误'}, 安装包路径: ${installerPath}`, latestVersion.value);
  }
}

async function ensureAvatarCacheConsistency(_reason: string, forceDownload = false) {
  const currentUser = store.getters.currentUser
  if (!currentUser?.id) {
    return
  }

  try {

    const { UserApi } = await import('./api/user')
    const profileResp = await UserApi.getUserAccountInfo({ userId: 'me' })
    if (!profileResp.success || !profileResp.data) {
      return
    }

    const backendUser = profileResp.data
    const backendKey = backendUser.avatarObjectKey ?? null
    const localKey = currentUser.avatarObjectKey ?? null
    const localPath = currentUser.avatarLocalPath ?? null

    let shouldDownload = forceDownload

    if (backendKey !== localKey) {
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
        })
      }
      return
    }

    // 如果 backendKey 和 localKey 一致，尝试从缓存中恢复
    // 注意：blob URL 在页面刷新后会失效，需要通过 AvatarCache.resolve 重新创建
    if (backendKey && backendKey === localKey) {
      if (localPath) {
        // 如果是 blob URL，页面刷新后会失效，需要通过 AvatarCache.resolve 重新创建
        if (localPath.startsWith('blob:')) {
          try {
            const { AvatarCache } = await import('./utils/avatar-cache')
            const cached = await AvatarCache.resolve(currentUser.id, backendKey)
            if (cached) {
              store.commit('UPDATE_USER_INFO', { avatarLocalPath: cached.webPath })
              // 同步到账号存储
              try {
                await store.dispatch('accounts/syncAccountProfile', {
                  accountId: currentUser.id,
                  userInfo: {
                    avatarLocalPath: cached.webPath,
                    avatarObjectKey: backendKey
                  }
                })
              } catch (syncError) {
              }
              return
            } else {
              shouldDownload = true
            }
          } catch (error) {
            shouldDownload = true
          }
        } else if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
          // HTTP/HTTPS URL 可以直接使用
          return
        } else {
          shouldDownload = true
        }
      } else {
        shouldDownload = true
      }
    } else if (backendKey && backendKey !== localKey) {
      // backendKey 和 localKey 不一致的情况已经在上面处理了
      shouldDownload = !!backendKey
    }

    if (shouldDownload) {
      await UserApi.syncAvatarCache(true)
    } else {
    }
  } catch (error) {
  }
}

// 获取账号路由状态
function getAccountRouteState(accountId: string) {
  const routeState = store.dispatch('accounts/getAccountRouteState', accountId)
  // 如果没有保存的路由状态，返回默认值
  return routeState || {
    path: '/home/chat',
    name: 'Chat',
    params: {},
    query: {}
  }
}

// 账号切换处理（多实例页面架构：只切换显示/隐藏，不销毁组件）
// 多 WebSocket 架构：不断开旧连接，只切换当前活跃账号
async function handleAccountSwitch(accountId: string) {
  try {
    // 1. 保存当前账号的路由状态（在切换前保存）
    // 注意：在多实例架构下，应该从账号的 routeState 中获取，而不是全局路由
    // 因为每个账号都有自己独立的路由状态
    if (currentAccountId.value) {
      const currentAccount = store.getters['accounts/getAccountById'](currentAccountId.value);
      // 如果账号已经有 routeState，使用它；否则使用默认值
      const currentRouteState = currentAccount?.routeState || {
        path: '/home/chat',
        name: 'Chat',
        params: {},
        query: {}
      };
      // 确保保存当前账号的路由状态（即使已经存在，也要确保是最新的）
      store.dispatch('accounts/saveAccountRouteState', {
        accountId: currentAccountId.value,
        routeState: currentRouteState
      });
    }

    // 2. 切换当前账号（这会触发显示/隐藏对应的容器）
    await store.dispatch('accounts/switchAccount', accountId);

    // 3. 切换 Vuex store 中的 token 和用户信息
    const account = store.getters['accounts/getAccountById'](accountId);
    if (account) {
      store.commit('SET_TOKEN', account.token);
      store.commit('SET_USER', account.userInfo);

      // 4. 同步 Rust 后端 token
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(account.token);

      // 5. 检查头像缓存
      await ensureAvatarCacheConsistency('switch-account');

      // 注意：在多实例页面架构下，不需要恢复路由状态
      // 因为每个账号的页面容器已经根据 routeState 渲染了正确的页面
      // 组件实例一直存在，只是之前被隐藏了，现在显示出来

      // 6. 恢复页面特定状态（如 currentChatGroupId）
      const savedPageState = await store.dispatch('accounts/restoreAccountPageState', accountId);
      if (savedPageState?.pageState?.currentChatGroupId) {
        store.commit('SET_CURRENT_CHAT_GROUP_ID', savedPageState.pageState.currentChatGroupId);
      } else {
        store.commit('SET_CURRENT_CHAT_GROUP_ID', null);
      }

      // 7. 切换 WebSocket 当前活跃账号（多连接架构：不断开旧连接）
      // 如果该账号尚未连接，则建立新连接；已连接则只切换当前用户
      const params = {
        userId: account.userInfo.id,
        token: account.token,
        chatGroupId: "00000000"
      };
      await webSocketManager.initWebSocketSafely(params, true);

      // 8. 刷新数据（联系人、聊天列表等）
      store.dispatch('loadChatList', { forceRefresh: true });
      store.dispatch('loadContacts', { forceRefresh: true });
    }
  } catch (error) {
    toast.error('账号切换失败');
  }
}

// 添加账号处理
async function handleAddAccount() {

  // 检查是否可以添加新账号
  if (!store.getters['accounts/canAddAccount']) {
    toast.warning(`最多支持 ${store.state.accounts.maxAccounts} 个账号`);
    return;
  }

  // 跳转到登录页面添加新账号
  router.push('/login');
}

// 移除账号处理
// 多 WebSocket 架构：只断开该账号的连接，不影响其他账号
async function handleRemoveAccount(accountId: string, skipConfirm = false) {

  const account = store.getters['accounts/getAccountById'](accountId);
  if (!account) {
    toast.error('账号不存在');
    return;
  }

  if (!skipConfirm) {
    const confirmed = confirm(`确定要移除账号 "${account.userInfo.nickname}" 吗？`);
    if (!confirmed) {
      return;
    }
  }

  const isCurrentAccount = currentAccountId.value === accountId;

  // 断开该账号的 WebSocket 连接（多连接架构：只断开该账号，不影响其他账号）
  try {
    await webSocketManager.closeWebSocket(account.userInfo.id);
  } catch (error) {
  }

  if (isCurrentAccount) {
    try {
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(null);
    } catch (error) {
    }
  }

  try {
    await store.dispatch('accounts/logoutAccount', accountId);
  } catch (error) {
    toast.error('移除账号失败');
    return;
  }

  const remainingAccounts: AccountInfo[] = store.getters['accounts/allAccounts'];

  if (remainingAccounts.length === 0) {
    // 没有剩余账号时，关闭所有连接并清理状态
    try {
      await webSocketManager.closeAllWebSockets();
      const { syncRustBackendToken } = await import('./api/http');
      await syncRustBackendToken(null);
    } catch (error) {
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
  } catch (error) {
  }
}

// 初始化 WebSocket 连接（优化：避免重复连接）
async function initWebSocketConnection() {
  const callStack = new Error().stack;

  if (!token.value || !user.value.id) {
    return;
  }

  // 检查是否已经有活跃连接
  if (networkState.value && websocket.value) {
    return;
  }


  const params = {
    userId: user.value.id,
    token: token.value,
    chatGroupId: "00000000" // 默认群组ID
  };

  try {
    await webSocketManager.initWebSocketSafely(params);
  } catch (error) {
  }
}

// 为所有已登录账号建立 WebSocket 连接（多账号场景重启后立即生效）
async function initAllAccountWebSockets() {
  const accounts = store.state.accounts?.accounts || [];
  if (!accounts.length) return;

  const currentAccountId = store.state.accounts?.currentAccountId;
  const currentUserId = store.getters['accounts/getAccountById']?.(currentAccountId)?.userInfo?.id;

  // 1. 为所有账号建立 WebSocket 连接
  const tasks = accounts.map(async (acc: any) => {
    if (!acc?.token || !acc?.userInfo?.id) return;
    const params = {
      userId: acc.userInfo.id,
      token: acc.token,
      chatGroupId: '00000000'
    };
    try {
      await webSocketManager.initWebSocketSafely(params, acc.id === currentAccountId);
    } catch (error) {
      console.warn('[App] initAllAccountWebSockets failed', acc.id, error);
    }
  });

  await Promise.allSettled(tasks);

  // 2. 为所有账号加载聊天列表并订阅房间（关键修复：非当前账号也需要订阅房间才能收到消息）
  for (const acc of accounts) {
    if (!acc?.token || !acc?.userInfo?.id) continue;
    try {
      // 加载该账号的聊天列表
      const loadResult = await invoke<{ chats: any[] }>('account_load_data', { token: acc.token });
      const chats = loadResult?.chats || [];

      // 提取所有房间 ID
      const roomIds = chats
        .map((chat: any) => chat.chat_group_id || chat.chatGroupId || chat.room_id || chat.roomId)
        .filter((id: string | undefined) => id && typeof id === 'string');

      if (roomIds.length > 0) {
        // 为该账号订阅所有房间
        webSocketManager.ensureRoomsSubscribed(roomIds, false, acc.userInfo.id);
        console.log(`[App] 账号 ${acc.userInfo.nickname} 订阅了 ${roomIds.length} 个房间`);
      }
    } catch (error) {
      console.warn('[App] 加载账号聊天列表失败', acc.id, error);
    }
  }

  // 3. 确保当前账号的 WebSocket 设为活跃状态
  if (currentAccountId && currentUserId) {
    try {
      await WebSocketApi.setCurrentUser(currentUserId);
    } catch (error) {
      console.warn('[App] restore current account ws failed', error);
    }
  }
}

// 关闭所有 WebSocket 连接（应用退出时调用）
function closeWebSocketConnection() {
  webSocketManager.closeAllWebSockets();
}

// 监听 WebSocket 状态变化
function setupWebSocketEventListeners() {
  // 监听聊天消息
  window.addEventListener('websocket-chat-message', (event) => {
    const detail = (event as CustomEvent).detail;
    handleChatMessage(detail);
  });

  // 监听 AI 消息
  window.addEventListener('websocket-ai-message', (event) => {
    const detail = (event as CustomEvent).detail;
    handleAIMessage(detail);
  });

  // 监听好友变化
  window.addEventListener('websocket-friend-change', (event) => {
    const detail = (event as CustomEvent).detail;
    handleFriendChange(detail);
  });

  // 监听删除好友
  window.addEventListener('websocket-delete-friend', (event) => {
    const detail = (event as CustomEvent).detail;
    handleDeleteFriend(detail);
  });

  // 监听朋友圈消息
  window.addEventListener('websocket-friend-circle', (event) => {
    const detail = (event as CustomEvent).detail;
    handleFriendCircle(detail);
  });

  // 监听群组相关消息
  window.addEventListener('websocket-launch-group', (event) => {
    const detail = (event as CustomEvent).detail;
    handleLaunchGroup(detail);
  });

  window.addEventListener('websocket-room-created', (event) => {
    const detail = (event as CustomEvent).detail;
    handleLaunchGroup(detail);
  });

  window.addEventListener('websocket-delete-group', (event) => {
    const detail = (event as CustomEvent).detail;
    handleDeleteGroup(detail);
  });

  // 监听通话消息
  window.addEventListener('websocket-message-update', (event) => {
    const detail = (event as CustomEvent).detail;
    handleMessageUpdate(detail);
  });

  window.addEventListener('websocket-message-read', (event) => {
    const detail = (event as CustomEvent).detail;
    handleMessageRead(detail);
  });

  window.addEventListener('websocket-pin-update', (event) => {
    const detail = (event as CustomEvent).detail;
    handlePinUpdate(detail);
  });

  // 监听群头像更新事件
  window.addEventListener('websocket-group-avatar-update', (event) => {
    const detail = (event as CustomEvent).detail;
    handleGroupAvatarUpdate(detail);
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
  window.removeEventListener('websocket-group-avatar-update', handleGroupAvatarUpdate);
}

// 消息处理函数
// 多账号架构：detail 中包含 userId 字段标识消息所属账号
function handleChatMessage(detail: any) {
  const payload = detail?.message ?? detail
  const eventUserId = detail?.userId // 消息所属的账号ID

  // 触发跨账号未读数刷新
  triggerCrossAccountUnreadRefresh('ws-chat-message')

  // 播放新消息通知（仅当不是自己发送的消息时）
  // 多账号场景：使用事件中的 userId 或当前账号 userId
  const targetUserId = eventUserId || user.value?.id
  const senderId = payload?.sender_id || payload?.senderId
  if (senderId && senderId !== targetUserId) {
    NotificationApi.showNewMessageNotification()
  }
}

function handleAIMessage(detail: any) {
  // 处理 AI 消息逻辑
}

function handleFriendChange(detail: any) {
  // 处理好友变化逻辑
  // 收到好友申请相关消息后，重新获取数量
  store.dispatch('updatePendingFriendRequests');
  triggerCrossAccountUnreadRefresh('friend-change')

  // 播放新好友请求通知
  NotificationApi.showNewMessageNotification()
}

function handleDeleteFriend(detail: any) {
  // 处理删除好友逻辑
  const currentChatGroupId = store.state.currentChatGroupId;
  const deletedGroupId = detail.content?.chatGroupId;
  
  if (deletedGroupId && currentChatGroupId === deletedGroupId) {
    toast.warning('您已被对方删除好友');
    router.push('/home');
  }
  
  // 好友被删除后，也需要更新申请数量
  store.dispatch('updatePendingFriendRequests');
  triggerCrossAccountUnreadRefresh('friend-delete')
}

function handleFriendCircle(detail: any) {
  // 处理朋友圈消息逻辑
}

function handleLaunchGroup(detail: any) {
  // 处理发起群聊逻辑
}

function handleDeleteGroup(detail: any) {
  // 处理群组解散逻辑
  const currentChatGroupId = store.state.currentChatGroupId;
  const deletedGroupId = detail.chatGroupId;
  
  if (deletedGroupId && currentChatGroupId === deletedGroupId) {
    toast.warning('当前群组已被解散');
    router.push('/home');
  }
}

function handleMessageUpdate(detail: any) {
}

function handleMessageRead(detail: any) {
  const roomId = detail?.room_id || detail?.roomId;
  if (roomId) {
    store.dispatch('setChatUnreadCount', { groupId: roomId, unreadCount: 0 });
  }
}

function handlePinUpdate(detail: any) {
  const roomId = detail?.room_id || detail?.roomId;
  const isPinned = detail?.is_pinned ?? detail?.isPinned;
  if (roomId !== undefined && isPinned !== undefined) {
    const chat = store.getters.getChatByGroupId(roomId);
    if (chat) {
      store.dispatch('updateChatItem', { ...chat, isTop: !!isPinned });
    }
  }
}

// 处理群头像更新事件
function handleGroupAvatarUpdate(detail: any) {
  const groupId = detail?.groupId || detail?.chatGroupId;
  const newAvatarUrl = detail?.avatarUrl || detail?.newAvatarUrl;
  
  if (!groupId || !newAvatarUrl) {
    return;
  }

  // 1. 更新聊天列表中对应群聊的头像
  const chat = store.getters.getChatByGroupId(groupId);
  if (chat) {
    store.dispatch('updateChatItem', { 
      ...chat, 
      avatar: newAvatarUrl,
      avatarLocalPath: undefined // 清除本地头像缓存路径，等待重新下载
    });
  }

  // 2. 如果当前正在查看该群聊，更新界面显示
  const currentChatGroupId = store.state.currentChatGroupId;
  if (currentChatGroupId === groupId) {
    // 触发界面刷新
    store.dispatch('updateCurrentChatAvatar', { groupId, avatarUrl: newAvatarUrl });
  }

  // 3. 同步群头像缓存
  try {
    // 延迟一小段时间确保网络请求完成
    setTimeout(async () => {
      try {
        const { UserApi } = await import('./api/user');
        await UserApi.syncGroupAvatarCache(groupId, newAvatarUrl, true); // 强制刷新
      } catch (cacheError) {
      }
    }, 1000);
  } catch (error) {
  }

  triggerCrossAccountUnreadRefresh('group-avatar-update');
}

// 监听页面可见性变化
// 页面可见性变化处理
function handleVisibilityChange() {
  if (document.hidden) {
  } else {
    // 只有在确实没有连接时才重新连接
    if (token.value && user.value.id && !networkState.value && !websocket.value) {
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

  if (val) {
    // 检查是否在独立的登录窗口中
    let isLoginWindow = false;
    try {
      const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
      const currentWindow = getCurrentWebviewWindow();
      const windowLabel = currentWindow.label;
      isLoginWindow = windowLabel.startsWith('login-');
    } catch (error) {
    }

    // 有token时跳转到主页（但独立登录窗口不跳转）
    if (router.currentRoute.value.path === '/login' && !isLoginWindow) {
      router.push('/home');
    }

    // 独立登录窗口不需要初始化 WebSocket 和更新标题
    if (!isLoginWindow) {
      // 登录成功后延迟初始化 WebSocket 连接，确保用户状态完全同步
      createSafeTimeout(() => {
        // 再次验证登录状态
        if (store.getters.isLoggedIn && store.state.token === val) {
          initWebSocketConnection();
        } else {
        }
      }, 800); // 增加延迟确保状态同步

      // 更新窗口标题（添加更长延迟确保用户信息已更新）
      createSafeTimeout(async () => {
        try {
          // 验证用户信息是否已正确设置
          if (user.value.id && user.value.username) {
            const { updateWindowTitle } = await import('@/utils');
            const appName = store.state.appName;
            await updateWindowTitle(user.value, appName);
          } else {
          }
        } catch (error) {
        }
      }, 300); // 增加延迟确保用户信息已同步
    } else {
    }
  } else {
    // 无token时立即执行退出逻辑
    
    // 立即关闭 WebSocket 连接
    closeWebSocketConnection();
    
    // 隐藏加载蒙版
    if (globalLoading.value.visible) {
      store.dispatch('hideGlobalLoading');
    }
    
    // 立即跳转到登录页面（但避免重复跳转）
    if (router.currentRoute.value.path !== '/login') {
      router.push('/login');
    } else {
    }
    
    // 跳转到登录页面时强制窗口居中
    createSafeTimeout(async () => {
      await forceWindowCenter();
    }, 50);  // 减少延迟
  }
  
}, {
  immediate: true
});

watch(isLoggedIn, (loggedIn, previous) => {
  if (loggedIn) {
    ensureAvatarCacheConsistency('login-state').catch((error) => {
    })
    if (!previous) {
      checkForUpdates(true);
    }
  }
})

watch(
  () => [hasAppUpdate.value, latestVersion.value?.version],
  () => {
    maybeShowUpdatePrompt(false);
  }
);

function handleUpdateLater() {
  showUpdateDialog.value = false;
  updatePromptHandled.value = true;
  updateDownloadStatus.value = 'idle';
  updateDownloadProgress.value = 0;
  updateDownloadInProgress.value = false;
}

async function handleDownloadNow() {
  if (!latestVersion.value) return;
  updateNotice.value = '';
  updateDownloadInProgress.value = true;
  updateDownloadStatus.value = 'downloading';
  updateDownloadProgress.value = 0;
  downloadedInstallerPath.value = null;
  installInProgress.value = false;
  try {
    const result = await store.dispatch('downloadLatestVersion');
    if (!result || !result.downloadUrl) {
      throw new Error('未获取到下载地址');
    }
    updateNotice.value = '正在下载安装包，请稍候...';
    // 调用 Rust 下载，完成后会通过 update-download-progress 事件触发安装
    // 不在这里直接调用 beginInstallDownloadedUpdate，避免重复调用
    await invoke<string>('download_update', {
      url: result.downloadUrl,
      fileName: result.fileName
    });
    // downloadedPath 会通过事件 handleDownloadEvent 设置并触发安装
  } catch (error: any) {
    updateDownloadStatus.value = 'error';
    updateNotice.value = '下载更新失败，请稍后重试。';
    toast.error(error?.message || '下载更新失败');
  } finally {
    if (!isTauriRuntime) {
      updateDownloadInProgress.value = false;
    }
  }
}

async function handleQuitApp() {
  try {
    await invoke('quit_app');
  } catch (error) {
    window.close();
  }
}

// 监听 WebSocket 连接状态变化
watch(websocket, (newWebSocket) => {
  if (newWebSocket) {
  } else {
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
}

// 恢复右键菜单
function enableContextMenu() {
  if (contextMenuHandler) {
    document.removeEventListener('contextmenu', contextMenuHandler);
    contextMenuHandler = null;
  }
}

// 组件挂载时设置事件监听
onMounted(async () => {
  // 确保应用启动时重置所有更新相关状态，避免残留状态影响后续更新
  updateDownloadStatus.value = 'idle';
  updateDownloadProgress.value = 0;
  updateDownloadInProgress.value = false;
  downloadedInstallerPath.value = null;
  installInProgress.value = false;
  updateNotice.value = '';

  if (isTauriRuntime) {
    try {
      const { listen } = await import('@tauri-apps/api/event');
      unlistenUpdateDownload = await listen('update-download-progress', (event) => {
        const payload = event.payload as DownloadEventPayload;
        console.log('[update-download-progress]', payload);
        handleDownloadEvent(payload);
      });
    } catch (error) {
    }
  }

  // 检查是否是独立登录窗口
  let isLoginWindow = false;
  try {
    const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
    const currentWindow = getCurrentWebviewWindow();
    const windowLabel = currentWindow.label;
    isLoginWindow = windowLabel.startsWith('login-');
  } catch (error) {
  }

  // 初始化下载目录设置（静默初始化）
  try {
    await initializeDownloadDir();
  } catch (error) {
    console.error('初始化下载目录失败:', error);
  }

  // 独立登录窗口不恢复账号状态，保持干净的登录环境
  if (!isLoginWindow) {
    // 检查是否需要迁移 localStorage 数据
    try {
      const { needsMigration, migrateAccounts } = await import('./utils/accountMigration');
      const shouldMigrate = await needsMigration();

      if (shouldMigrate) {
        const result = await migrateAccounts();

        if (result.success) {
          toast.success(result.message);
        } else {
          toast.error(result.message);
        }
      }
    } catch (error) {
    }

    // 从 Rust SQLite 恢复账号列表
    try {
      await store.dispatch('accounts/loadAccountsFromStorage');

      // 如果有当前账号，恢复其状态
      const currentAccount = store.getters['accounts/currentAccount'];
      if (currentAccount) {
        store.commit('SET_TOKEN', currentAccount.token);
        store.commit('SET_USER', currentAccount.userInfo);

        await ensureAvatarCacheConsistency('app-initial-load');

        // 在多实例页面架构下，账号的路由状态已经通过 AccountHome 组件管理
        // 这里只需要恢复页面特定状态（如 currentChatGroupId）
        const savedPageState = await store.dispatch('accounts/restoreAccountPageState', currentAccount.id);
        if (savedPageState?.pageState?.currentChatGroupId) {
          store.commit('SET_CURRENT_CHAT_GROUP_ID', savedPageState.pageState.currentChatGroupId);
        }

        // 为所有账号建立 WebSocket 连接（当前账号置为活跃）
        await initAllAccountWebSockets();
      }
    } catch (error) {
    }
  } else {
  }

  // 确保全局加载蒙版是隐藏状态
  if (globalLoading.value.visible) {
    store.dispatch('hideGlobalLoading');
  }

  // 初始化 Rust HTTP 客户端 (不阻塞其他初始化)
  rustHttp.initialize(token.value || undefined)
    .then(() => {
    })
    .catch((error) => {
      // 不显示错误提示,因为可能是正常的未连接状态
    });

  // 设置 WebSocket 事件监听
  setupWebSocketEventListeners();

  // 应用启动时检查用户登录状态并自动初始化 WebSocket
  if (isLoggedIn.value && token.value && user.value.id) {
    createSafeTimeout(async () => {
      try {
        // 再次验证登录状态，避免状态变化
        if (store.getters.isLoggedIn && store.state.token === token.value) {
          await initWebSocketConnection();
        }
      } catch (error) {
        console.warn('[App] 应用启动时 WebSocket 初始化失败:', error);
        // WebSocket 初始化失败不影响应用正常启动
      }
    }, 1000); // 延迟1秒确保其他初始化完成
  }
  
  // 使用事件管理器添加监听器
  eventManager.addDocumentListener('visibilitychange', handleVisibilityChange);
  eventManager.addWindowListener('beforeunload', closeWebSocketConnection);
  
  // 加载应用名称（静默加载，失败不影响启动）
  try {
    await store.dispatch('loadAppName');
  } catch (error) {
    // 静默失败
  }

  // 初始化窗口标题
  try {
    const { updateWindowTitle } = await import('@/utils');
    const appName = store.state.appName;
    if (token.value && user.value.mobile) {
      await updateWindowTitle(user.value, appName);
    } else {
      await updateWindowTitle(undefined, appName); // 显示默认标题
    }
  } catch (error) {
  }
  
  // 开发模式下启用调试工具
  if (import.meta.env.DEV) {
    // 启动内存监控
    memoryMonitor.startMonitoring();
  }

  // 禁用浏览器右键菜单
  disableContextMenu();

  // 监听新账号添加事件（来自独立登录窗口）
  let unlistenAccountAdded: (() => void) | null = null;
  (async () => {
    try {
      const { listen } = await import('@tauri-apps/api/event');
      unlistenAccountAdded = await listen('account-added', (event) => {
        // 账号已经在 Login.vue 中添加到 store，这里只需要显示提示
        const payload = event.payload as { accountId: string; nickname: string };
        toast.success(`账号 ${payload.nickname} 已添加`);
      });
    } catch (error) {
    }
  })();

  // 启动定时刷新所有账号未读数（仅在有多个账号时）
  if (!isLoginWindow) {
    const startUnreadRefresh = () => {
      if (unreadRefreshTimer) {
        clearInterval(unreadRefreshTimer);
      }
      
      // 立即执行一次
      if (accounts.value.length > 1) {
        triggerCrossAccountUnreadRefresh('initial');
      }
      
      // 每10秒刷新一次
      unreadRefreshTimer = window.setInterval(() => {
        // 只有在有多个账号时才刷新
        if (accounts.value.length > 1) {
          triggerCrossAccountUnreadRefresh('interval');
        }
      }, CROSS_ACCOUNT_REFRESH_INTERVAL);
      
    };

    // 监听账号数量变化，动态启动/停止定时器
    watch(
      () => accounts.value.length,
      (newLength, oldLength) => {
        if (newLength > 1) {
          startUnreadRefresh();
        } else if (newLength <= 1 && unreadRefreshTimer) {
          clearInterval(unreadRefreshTimer);
          unreadRefreshTimer = null;
          unreadRefreshInProgress = false;
          unreadRefreshPending = false;
        }
      },
      { immediate: true }
    );
  }
});

// 组件卸载时清理
onUnmounted(() => {
  if (unlistenUpdateDownload) {
    unlistenUpdateDownload();
    unlistenUpdateDownload = null;
  }
  
  // 清理未读数刷新定时器
  if (unreadRefreshTimer) {
    clearInterval(unreadRefreshTimer);
    unreadRefreshTimer = null;
  }
  
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
      <!-- 多账号独立页面架构：为每个账号创建独立的页面容器 -->
      <template v-if="isLoggedIn && accounts.length > 0">
        <!-- 为每个账号创建独立的页面容器，使用 v-show 控制显示/隐藏 -->
        <template v-for="account in accounts" :key="account.id">
          <div
            v-show="currentAccountId === account.id"
            class="account-container"
            :data-account-id="account.id"
            :style="{ display: currentAccountId === account.id ? 'block' : 'none' }"
          >
            <AccountHome
              :account-id="account.id"
              :route-state="getAccountRouteState(account.id)"
            />
          </div>
        </template>
      </template>
      
      <!-- 单账号或未登录时使用原有的路由视图 -->
      <template v-else>
        <router-view v-slot="{ Component }">
          <keep-alive :include="keepAliveViews">
            <component :is="Component" />
          </keep-alive>
        </router-view>
      </template>
    </div>

    <!-- 全局加载蒙版 -->
    <LoadingMask
      :visible="globalLoading.visible"
      :text="globalLoading.text"
    />
  </div>

    <div
      v-if="showUpdateDialog && latestVersion"
      class="update-dialog"
    >
      <div class="update-dialog__panel">
        <div class="update-dialog__title">
          {{ updateMandatory ? '必须更新至最新版本' : '发现新版本' }}
        </div>
        <div class="update-dialog__content">
          <p>当前版本：v{{ currentVersionInfo.version }}</p>
          <p>最新版本：v{{ latestVersion.version }}（{{ latestVersion.channel }}）</p>
          <p v-if="latestVersion.release_notes" class="update-dialog__notes">
            {{ latestVersion.release_notes }}
          </p>
          <div
            v-if="updateDownloadStatus !== 'idle'"
            class="update-dialog__progress"
          >
            <div class="progress-bar">
              <div
                class="progress-bar__inner"
                :style="{ width: `${Math.min(100, Math.floor(updateDownloadProgress))}%` }"
              ></div>
            </div>
            <p class="update-dialog__progress-text">
              {{
                updateDownloadStatus === 'finished' && installInProgress
                  ? '安装程序已启动...'
                  : `下载进度 ${Math.floor(updateDownloadProgress)}%`
              }}
            </p>
          </div>
          <p v-if="updateNotice" class="update-dialog__notice">
            {{ updateNotice }}
          </p>
        </div>
        <div class="update-dialog__actions">
          <button
            v-if="!updateMandatory"
            class="update-dialog__btn"
            :disabled="updateDownloadInProgress || installInProgress"
            @click="handleUpdateLater"
          >
            稍后再说
          </button>
          <button
            v-if="shouldShowUpdateButton"
            class="update-dialog__btn primary"
            :disabled="updateDownloadInProgress || installInProgress"
            @click="handleDownloadNow"
          >
            {{ downloadButtonLabel }}
          </button>
          <button
            v-if="updateMandatory"
            class="update-dialog__btn danger"
            @click="handleQuitApp"
          >
            退出应用
          </button>
        </div>
      </div>
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

/* 账号容器样式 - 确保每个账号的页面容器完全独立 */
.account-container {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: hidden;
}

/* 确保隐藏的账号容器不占用布局空间，但保持DOM存在 */
.account-container[style*="display: none"] {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  visibility: hidden;
  pointer-events: none;
}

.update-dialog {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.65);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 24px;
}

.update-dialog__panel {
  width: 360px;
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 24px 80px rgba(15, 23, 42, 0.25);
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.update-dialog__title {
  font-size: 20px;
  font-weight: 600;
  color: #0f172a;
}

.update-dialog__content p {
  margin: 6px 0;
  color: #475569;
  font-size: 14px;
}

.update-dialog__notes {
  background: #f8fafc;
  border-radius: 8px;
  padding: 12px;
  color: #334155;
  font-size: 13px;
}

.update-dialog__notice {
  margin-top: 12px;
  padding: 8px 12px;
  background: rgba(37, 99, 235, 0.08);
  border-radius: 8px;
  color: #1e3a8a;
  font-size: 13px;
}

.update-dialog__progress {
  margin-top: 12px;
}

.progress-bar {
  width: 100%;
  height: 12px;
  border-radius: 999px;
  background: rgba(78, 205, 196, 0.12);
  border: 1px solid rgba(78, 205, 196, 0.35);
  overflow: hidden;
}

.progress-bar__inner {
  height: 100%;
  background: linear-gradient(90deg, #4ecdc4, #1abc9c);
  box-shadow: 0 4px 12px rgba(26, 188, 156, 0.35);
  transition: width 0.2s ease;
}

.update-dialog__progress-text {
  margin-top: 6px;
  font-size: 13px;
  color: #064e3b;
}

.update-dialog__actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
}

.update-dialog__btn {
  border: none;
  border-radius: 8px;
  padding: 10px 18px;
  font-size: 14px;
  background: #e2e8f0;
  color: #0f172a;
  transition: background 0.2s;
}

.update-dialog__btn.primary {
  background: #2563eb;
  color: #fff;
}

.update-dialog__btn.danger {
  background: #fda4af;
  color: #881337;
}

.update-dialog__btn:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}
</style>
