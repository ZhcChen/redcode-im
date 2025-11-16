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
import { computed, watch, onMounted, ref } from 'vue'
import { useStore } from 'vuex'
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
  routeState: () => ({
    path: '/home/chat',
    name: 'Chat',
    params: {},
    query: {}
  })
})

const store = useStore()

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
  (newRouteState, oldRouteState) => {
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

