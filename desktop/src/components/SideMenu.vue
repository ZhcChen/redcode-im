<template>
  <div class="side-menu">
    <div class="user-avatar" @click="handleAvatarClick">
      <Avatar 
        :src="userAvatarSrc" 
        :alt="userDisplayName + '的头像'" 
        :size="48" 
      />
    </div>
    <div class="menu-items">
      <div
        v-for="item in menuItems"
        :key="item.name"
        class="menu-item"
        :class="{ active: isMenuItemActive(item.path) }"
        @click="handleMenuClick(item)"
      >
        <img
          :src="isMenuItemActive(item.path) ? item.iconSelected : item.icon"
          :alt="item.label"
          class="menu-icon"
        />
        <span class="menu-label">{{ item.label }}</span>
      </div>
    </div>
    
    <!-- 更多菜单项 -->
    <div class="more-menu-container">
      <Popover 
        placement="top" 
        trigger="click" 
        :offset="8"
        :content-offset-x="30"
        :arrow-offset-x="-30"
      >
        <template #trigger>
          <div class="menu-item more-menu-item">
            <img
              src="/assets/image/icon-menu.svg"
              alt="更多"
              class="menu-icon"
            />
            <span class="menu-label">更多</span>
          </div>
        </template>
        
        <template #content>
          <div
            class="popover-item"
            @click="handleSettings"
          >
            <img
              src="/assets/image/icon-setting.svg"
              alt="设置"
              class="popover-icon"
            />
            <span class="popover-label">设置</span>
          </div>
          <div
            class="popover-item"
            @click="handleAddAccount"
          >
            <img
              src="/assets/image/icon-add-user.svg"
              alt="添加账号"
              class="popover-icon"
            />
            <span class="popover-label">添加账号</span>
          </div>
          <div
            class="popover-item"
            @click="handleLogout"
          >
            <img
              src="/assets/image/icon-logout.svg"
              alt="退出登录"
              class="popover-icon"
            />
            <span class="popover-label">退出登录</span>
          </div>
        </template>
      </Popover>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useStore } from 'vuex'
import Avatar from './Avatar.vue'
import Popover from './Popover.vue'

interface MenuItem {
  name: string
  label: string
  path: string
  icon: string
  iconSelected: string
}

const route = useRoute()
const router = useRouter()
const store = useStore()

// 用于管理退出登录的超时检查
let logoutTimeoutId: number | null = null

// 获取当前用户信息
const currentUser = computed(() => store.getters.currentUser)

// 用户显示名称（优先使用昵称，如果没有则使用用户名）
const userDisplayName = computed(() => {
  return currentUser.value.nickname || currentUser.value.username || '用户'
})

// 用户头像地址（如果没有头像则使用默认头像）
const userAvatarSrc = computed(() => {
  if (currentUser.value.avatar && currentUser.value.avatar.trim()) {
    return currentUser.value.avatar
  }
  // 使用用户名的首字符生成默认头像
  const firstChar = userDisplayName.value.charAt(0).toUpperCase()
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(firstChar)}&background=6366f1&color=ffffff&size=96&rounded=true`
})

const menuItems = ref<MenuItem[]>([
  {
    name: 'Chat',
    label: '聊天',
    path: '/home/chat',
    icon: '/assets/image/menu/icon-chat.svg',
    iconSelected: '/assets/image/menu/icon-chat-selected.svg'
  },
  {
    name: 'Contact',
    label: '联系人',
    path: '/home/contact',
    icon: '/assets/image/menu/icon-contract.svg',
    iconSelected: '/assets/image/menu/icon-contract-selected.svg'
  }
])

// 判断菜单项是否激活的逻辑
const isMenuItemActive = (itemPath: string) => {
  return route.path === itemPath
}

// 处理菜单项点击
const handleMenuClick = (item: MenuItem) => {
  console.log('菜单项被点击:', item.label, item.path)
  router.push(item.path)
}


// 处理头像点击
const handleAvatarClick = () => {
  console.log('头像被点击')
  router.push('/home/settings')
}

// 处理设置点击
const handleSettings = () => {
  console.log('设置被点击')
  router.push('/home/settings')
}

// 处理添加账号点击
const handleAddAccount = async () => {
  console.log('添加账号被点击')

  // 检查是否可以添加新账号
  const canAdd = store.getters['accounts/canAddAccount']
  if (!canAdd) {
    const maxAccounts = store.state.accounts.maxAccounts
    const currentCount = store.state.accounts.accounts.length
    console.warn(`已达到最大账号数量限制: ${maxAccounts}`)

    // 导入 toast 提示
    const { toast } = await import('@/utils/toast')
    toast.warning(`已达到最大账号数量限制（${currentCount}/${maxAccounts}）`)
    return
  }

  try {
    // 使用 Tauri API 打开新的登录窗口
    const { WebviewWindow } = await import('@tauri-apps/api/webviewWindow')

    // 创建一个新的登录窗口
    const loginWindow = new WebviewWindow('login-' + Date.now(), {
      url: '/login',
      title: '添加账号',
      width: 400,
      height: 600,
      resizable: false,
      center: true,
      alwaysOnTop: false,
      skipTaskbar: false
    })

    // 监听窗口创建完成
    loginWindow.once('tauri://created', () => {
      console.log('登录窗口已创建')
    })

    // 监听窗口创建错误
    loginWindow.once('tauri://error', (error) => {
      console.error('创建登录窗口失败:', error)
    })
  } catch (error) {
    console.error('打开登录窗口失败:', error)
  }
}

// 处理退出登录点击
const handleLogout = () => {
  console.log('🔄 用户点击退出登录...')

  // 清除之前的超时检查（如果存在）
  if (logoutTimeoutId !== null) {
    clearTimeout(logoutTimeoutId)
    logoutTimeoutId = null
    console.log('🧹 已清除之前的退出检查超时器')
  }

  // 立即设置登出状态，防止新的API请求
  import('@/api/http').then(({ setLoggingOut, clearLoginTime }) => {
    setLoggingOut(true);
    clearLoginTime(); // 清除登录时间
    console.log('📝 已设置登出状态并清除登录时间');
  }).catch(error => {
    console.warn('⚠️ 设置登出状态失败:', error)
  })

  // 调用 store 的 logout action
  store.dispatch('logout')
  console.log('✅ 退出登录请求已发送')

  // 设置新的fallback机制
  logoutTimeoutId = setTimeout(() => {
    const currentToken = store.state.token
    const loadingVisible = store.getters.globalLoading.visible
    const isLoggedIn = store.getters.isLoggedIn

    console.log('🔍 5秒后检查退出状态:', {
      hasToken: !!currentToken,
      isLoggedIn,
      loadingVisible,
      currentPath: window.location.pathname,
      timeoutId: logoutTimeoutId
    });

    // 只有当前确实还在登录状态时才执行强制清除
    if ((currentToken || loadingVisible || isLoggedIn) && window.location.pathname !== '/login') {
      console.warn('⚠️ 检测到退出登录可能卡住，执行强制清除')

      // 强制隐藏加载蒙版
      if (loadingVisible) {
        store.dispatch('hideGlobalLoading')
      }

      // 强制清除所有状态
      if (currentToken || isLoggedIn) {
        store.commit('SET_TOKEN', null)
        store.commit('LOGOUT_USER')

        // 重置登出状态，允许用户重新登录
        try {
          import('@/api/http').then(({ setLoggingOut, clearLoginTime }) => {
            setLoggingOut(false)
            clearLoginTime()
            console.log('📝 强制登出后已重置所有状态')
          }).catch(error => {
            console.warn('重置状态失败:', error)
          })
        } catch (error) {
          console.warn('无法加载http模块:', error)
        }

        // 重置窗口标题
        try {
          import('@/utils').then(({ updateWindowTitle }) => {
            updateWindowTitle() // 不传参数，显示默认标题
          }).catch(error => {
            console.warn('重置窗口标题失败:', error)
          })
        } catch (error) {
          console.warn('无法加载utils模块:', error)
        }
      }

      // 强制跳转到登录页
      router.push('/login')
    } else {
      console.log('✅ 退出登录状态正常或已在登录页，无需强制处理')
    }

    // 清除超时器引用
    logoutTimeoutId = null
  }, 5000) as unknown as number // 保持5秒检查
}

// 组件卸载时清理超时器
onUnmounted(() => {
  if (logoutTimeoutId !== null) {
    clearTimeout(logoutTimeoutId)
    logoutTimeoutId = null
    console.log('🧹 组件卸载时清除退出检查超时器')
  }
})
</script>

<style lang="scss" scoped>
.side-menu {
  width: 100px;
  height: 100vh;
  background-color: $side-menu-bg; // 使用全局变量 #F5F4F5
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  position: sticky;
  top: 0;
  flex-shrink: 0;
  z-index: 20;
  pointer-events: auto;
}

.user-avatar {
  display: flex;
  justify-content: center;
  padding: 20px;
  margin-bottom: 10px;
  cursor: pointer;
  transition: opacity 0.2s ease;
  
  &:hover {
    opacity: 0.8;
  }
}

.menu-items {
  padding: 20px 0;
  flex: 1;
}

.menu-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px 20px;
  cursor: pointer;
  transition: all 0.2s ease;
  color: $text-secondary;
  
  &:hover {
    background-color: $side-menu-hover;
  }
  
  &.active {
    color: $primary-color;
    
    .menu-label {
      color: $primary-color;
    }
  }
  
  .menu-icon {
    width: 24px;
    height: 24px;
    margin-bottom: 11px;
  }
  
  .menu-label {
    font-size: 12px;
    font-weight: 500;
    text-align: center;
    color: inherit;
  }
}

// 更多菜单容器
.more-menu-container {
  position: relative;
  margin-top: auto;
  padding-bottom: 20px;
  display: flex;
  justify-content: center;
}

// 更多菜单项特殊样式
.more-menu-item {
  // 保持居中对齐
  display: flex;
  flex-direction: column;
  align-items: center;
  
  // 不改变背景色
  &:hover {
    background-color: transparent !important;
  }
  
  // 不能选中
  &.active {
    color: $text-secondary !important;
    
    .menu-label {
      color: $text-secondary !important;
    }
  }
}

// 弹窗内部选项样式
.popover-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  cursor: pointer;
  transition: background-color 0.2s ease;
  
  &:hover {
    background-color: #f5f5f5;
  }
  
  .popover-icon {
    width: 24px;
    height: 24px;
    margin-right: 8px;
    flex-shrink: 0;
  }

  .popover-label {
    font-size: 14px;
    color: $chat-message-color; // #707991
    white-space: nowrap;
  }
}
</style>
