import { createRouter, createWebHistory } from 'vue-router'
import { getCurrentWindow } from '@tauri-apps/api/window'
import { store } from '../store'
import Home from '../views/Home.vue'
import Login from '../views/Login.vue'
import Chat from '../views/Chat.vue'
import Contact from '../views/Contact.vue'
import Settings from '../views/Settings.vue'
import Privacy from '../views/Privacy.vue'

const routes = [
  {
    path: '/',
    redirect: '/login'  // 应用启动时默认跳转到登录页
  },
  {
    path: '/home',
    name: 'Home',
    component: Home,
    redirect: '/home/chat',  // 默认重定向到第一个菜单项
    children: [
      {
        path: 'chat',
        name: 'Chat',
        component: Chat
      },
      {
        path: 'contact',
        name: 'Contact',
        component: Contact
      },
      {
        path: 'settings',
        name: 'Settings',
        component: Settings
      },
      {
        path: 'privacy',
        name: 'Privacy',
        component: Privacy
      }
    ]
  },
  {
    path: '/login',
    name: 'Login',
    component: Login
  }
]

export const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫 - 认证和窗口管理
router.beforeEach(async (to, from, next) => {
  // 直接从Vuex store获取登录状态，不检查localStorage
  const isLoggedIn = store.getters.isLoggedIn
  
  console.log('路由守卫 - 目标路由:', to.name)
  console.log('路由守卫 - 登录状态:', isLoggedIn)

  // 当用户访问登录页面时，重置登出状态
  if (to.name === 'Login') {
    try {
      const { setLoggingOut } = await import('../api/http')
      setLoggingOut(false)
      console.log('📝 访问登录页面，已重置登出状态')
    } catch (error) {
      console.warn('重置登出状态失败:', error)
    }
  }

  // 如果用户已登录且试图访问登录页，重定向到主页
  if (isLoggedIn && to.name === 'Login') {
    console.log('已登录用户试图访问登录页，重定向到主页')
    next({ name: 'Home', replace: true })
    return
  }
  
  // 如果用户未登录且试图访问需要认证的页面，重定向到登录页
  if (!isLoggedIn && to.name !== 'Login' && to.path !== '/login') {
    console.log('未登录用户试图访问受保护页面，重定向到登录页')
    next({ name: 'Login', replace: true })
    return
  }
  
  // 当导航到 Home 页面时，自动最大化窗口
  if (to.name === 'Home') {
    try {
      const appWindow = getCurrentWindow()
      
      // 检查当前窗口状态
      const isMaximized = await appWindow.isMaximized()
      console.log('进入 Home 页面 - 当前窗口最大化状态:', isMaximized)
      
      if (!isMaximized) {
        console.log('进入 Home 页面 - 开始最大化窗口...')
        await appWindow.maximize()
        
        // 确认最大化是否成功
        const newState = await appWindow.isMaximized()
        console.log('进入 Home 页面 - 窗口最大化完成，新状态:', newState)
      } else {
        console.log('进入 Home 页面 - 窗口已经是最大化状态')
      }
    } catch (error) {
      console.error('进入 Home 页面时窗口操作失败:', error)
    }
  }
  
  next()
})
