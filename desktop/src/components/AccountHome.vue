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
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, watch, onMounted, onActivated, onDeactivated, onUnmounted, ref } from 'vue'
import { useStore } from 'vuex'
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { LogicalSize, LogicalPosition } from '@tauri-apps/api/window'
import SideMenu from './SideMenu.vue'
import Chat from '../views/Chat.vue'
import Contact from '../views/Contact.vue'
import Settings from '../views/Settings.vue'
import Privacy from '../views/Privacy.vue'
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
const DEFAULT_MAIN_WINDOW_SIZE = { width: 1200, height: 800 }

// 窗口大小持久化键名
const WINDOW_SIZE_STORAGE_KEY = 'app_window_size'
const WINDOW_POSITION_STORAGE_KEY = 'app_window_position'

// 设置主窗口尺寸
async function setMainWindowSize() {
  try {
    const currentWindow = getCurrentWebviewWindow()
    
    // 尝试从持久化存储中恢复窗口大小
    let targetSize = DEFAULT_MAIN_WINDOW_SIZE
    try {
      const savedSize = localStorage.getItem(WINDOW_SIZE_STORAGE_KEY)
      if (savedSize) {
        const parsed = JSON.parse(savedSize)
        // 验证保存的大小是否合理
        if (parsed.width >= 400 && parsed.width <= 3840 && 
            parsed.height >= 300 && parsed.height <= 2160) {
          targetSize = parsed
        }
      }
    } catch (error) {
      // 如果读取失败，使用默认值
    }
    
    // 获取当前窗口状态
    const isCurrentlyMaximized = await currentWindow.isMaximized()
    
    // 如果窗口不是最大化状态，才设置大小
    if (!isCurrentlyMaximized) {
      await currentWindow.setSize(new LogicalSize(targetSize.width, targetSize.height))
      
      // 尝试恢复窗口位置
      try {
        const savedPosition = localStorage.getItem(WINDOW_POSITION_STORAGE_KEY)
        if (savedPosition) {
          const position = JSON.parse(savedPosition)
          await currentWindow.setPosition(new LogicalPosition(position.x, position.y))
        } else {
          // 如果没有保存的位置，居中显示
          await currentWindow.center()
        }
      } catch (error) {
        // 如果设置位置失败，居中显示
        await currentWindow.center()
      }
    }
  } catch (error) {
    // 静默失败，不影响应用运行
  }
}

// 保存窗口大小和位置
async function saveWindowState() {
  try {
    const currentWindow = getCurrentWebviewWindow()
    const isMaximized = await currentWindow.isMaximized()
    
    // 只有在非最大化状态下才保存大小和位置
    if (!isMaximized) {
      const size = await currentWindow.innerSize()
      const position = await currentWindow.outerPosition()
      
      localStorage.setItem(WINDOW_SIZE_STORAGE_KEY, JSON.stringify({
        width: size.width,
        height: size.height
      }))
      
      localStorage.setItem(WINDOW_POSITION_STORAGE_KEY, JSON.stringify({
        x: position.x,
        y: position.y
      }))
    }
  } catch (error) {
    // 静默失败
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  // 防止重复初始化
  if (windowStateInitialized) {
    return
  }
  
  try {
    const currentWindow = getCurrentWebviewWindow()
    const isCurrentlyMaximized = await currentWindow.isMaximized()
    
    // 如果不是最大化，设置为默认主窗口尺寸（或从持久化存储恢复）
    if (!isCurrentlyMaximized) {
      await setMainWindowSize()
    }
    
    windowStateInitialized = true
    
    // 设置窗口可调整大小（如果之前被禁用）
    try {
      await currentWindow.setResizable(true)
    } catch (error) {
      // 静默失败
    }
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

// 组件失活时（用于 keep-alive）
onDeactivated(() => {
  // 保存窗口状态
  saveWindowState()
})

onMounted(() => {
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
  
  // 监听窗口大小变化，定期保存窗口状态
  let resizeTimer: number | null = null
  const handleResize = () => {
    // 防抖：只在用户停止调整窗口大小后保存
    if (resizeTimer) {
      clearTimeout(resizeTimer)
    }
    resizeTimer = window.setTimeout(() => {
      saveWindowState()
    }, 500) // 500ms 后保存
  }
  
  window.addEventListener('resize', handleResize)
  
  // 组件卸载时清理
  onUnmounted(() => {
    window.removeEventListener('resize', handleResize)
    if (resizeTimer) {
      clearTimeout(resizeTimer)
    }
    // 保存窗口状态
    saveWindowState()
  })
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

