// @ts-nocheck
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
  
  next()
})
