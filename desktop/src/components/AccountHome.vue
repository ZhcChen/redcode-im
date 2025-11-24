<template>
  <div class="account-home">
    <div class="layout-container">
      <!-- 左侧菜单栏 -->
      <SideMenu :account-id="accountId" />
      
      <!-- 右侧内容区域 -->
      <div class="main-content">
        <!-- 根据路由状态显示对应的子页面 -->
        <Chat v-if="currentPage === 'chat'" :account-id="accountId" :key="`chat-${accountId}`" />
        <Contact v-if="currentPage === 'contact'" :account-id="accountId" :key="`contact-${accountId}`" />
        <Settings v-if="currentPage === 'settings'" :account-id="accountId" :key="`settings-${accountId}`" />
        <Privacy v-if="currentPage === 'privacy'" :account-id="accountId" :key="`privacy-${accountId}`" />
        <GeneralSettings v-if="currentPage === 'general'" :account-id="accountId" :key="`general-${accountId}`" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, watch, onMounted, onActivated, ref } from 'vue'
import { useStore } from 'vuex'
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { setWindowSizeSafe, hasUserResized, installUserResizeListener } from '@/utils/window'
import SideMenu from './SideMenu.vue'
import Chat from '../views/Chat.vue'
import Contact from '../views/Contact.vue'
import Settings from '../views/Settings.vue'
import Privacy from '../views/Privacy.vue'
import GeneralSettings from '../views/GeneralSettings.vue'
import type { AccountRouteState } from '../store/modules/accounts'

interface Props {
  accountId: string
  routeState?: AccountRouteState
}

const props = withDefaults(defineProps<Props>(), {
  routeState: undefined
})

const store = useStore()

// 窗口大小管理
let windowStateInitialized = false
const DEFAULT_MAIN_WINDOW_SIZE = { width: 1200, height: 720 }

// 设置主窗口尺寸（固定为 1200x720）
async function setMainWindowSize() {
  try {
    const currentWindow = getCurrentWebviewWindow()
    const isCurrentlyMaximized = await currentWindow.isMaximized()

    // 先确保窗口可调整（解除登录页面的限制）
    try {
      await currentWindow.setResizable(true)
      console.log('[AccountHome] Window set to resizable')
      // 添加小延迟确保 resizable 状态生效
      await new Promise(resolve => setTimeout(resolve, 50))
    } catch (error) {
      console.error('[AccountHome] Failed to set resizable:', error)
    }

    // 如果窗口不是最大化状态，设置为固定大小
    if (!isCurrentlyMaximized && !hasUserResized()) {
      console.log('[AccountHome] Setting window size to:', DEFAULT_MAIN_WINDOW_SIZE)
      await setWindowSizeSafe(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)
    } else {
      console.log('[AccountHome] Skipping resize - maximized or user resized')
    }
  } catch (error) {
    console.error('[AccountHome] Failed to set window size:', error)
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  // 防止重复初始化
  if (windowStateInitialized) {
    return
  }
  
  try {
    await setMainWindowSize()
    windowStateInitialized = true
  } catch (error) {
    windowStateInitialized = true
  }
}

// 使用本地状态来响应 store 中的路由状态变化
const localRouteState = ref<AccountRouteState>(props.routeState || {
  path: '/home/chat',
  name: 'Chat',
  params: {},
  query: {}
})

// 监听 store 中账号的路由状态变化
watch(
  () => {
    const account = store.getters['accounts/getAccountById'](props.accountId)
    return account?.routeState ? { ...account.routeState } : null
  },
  (newRouteState: AccountRouteState | null, oldRouteState: AccountRouteState | null) => {
    if (newRouteState) {
      // 只有当路由状态真正改变时才更新
      if (!oldRouteState || newRouteState.path !== oldRouteState?.path) {
        localRouteState.value = { ...newRouteState }
      }
    }
  },
  { immediate: true, deep: true }
)

// 根据路由状态确定当前页面
const currentPage = computed(() => {
  const path = localRouteState.value?.path || '/home/chat'
  if (path.includes('/chat')) return 'chat'
  if (path.includes('/contact')) return 'contact'
  if (path.includes('/settings')) return 'settings'
  if (path.includes('/privacy')) return 'privacy'
  if (path.includes('/general')) return 'general'
  return 'chat'
})

// 组件激活时（用于 keep-alive）
onActivated(() => {
  // 重置状态，确保每次激活都重新设置窗口
  windowStateInitialized = false
  
  // 延迟设置窗口尺寸，确保窗口已完全显示
  setTimeout(() => {
    prepareWindowOnLogin()
  }, 100)
})

onMounted(() => {
  void installUserResizeListener()
  // 初始化时，优先使用 store 中保存的路由状态
  const account = store.getters['accounts/getAccountById'](props.accountId)
  if (account?.routeState) {
    // 如果 store 中有路由状态，使用它
    localRouteState.value = account.routeState
  } else {
    // 如果 store 中没有路由状态，使用默认值并保存到 store
    const defaultRouteState: AccountRouteState = {
      path: '/home/chat',
      name: 'Chat',
      params: {},
      query: {}
    }
    localRouteState.value = defaultRouteState
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: defaultRouteState
    })
  }
  
  // 延迟设置窗口尺寸，确保窗口已完全显示
  setTimeout(() => {
    prepareWindowOnLogin()
  }, 100)
})
</script>

<style lang="scss" scoped>
.account-home {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.layout-container {
  display: flex;
  width: 100%;
  height: 100%;
  position: relative;
}

.main-content {
  flex: 1;
  width: calc(100% - 100px);
  background: #ffffff;
  overflow: hidden;
  position: relative;
  z-index: 1;
  min-width: 0;
  pointer-events: auto;
}

// 确保子路由内容正确显示
:deep(.router-view) {
  width: 100%;
  height: 100%;
}
</style>
