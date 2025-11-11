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
  const guardId = `GUARD_${Date.now()}`;
  
  // 直接从Vuex store获取登录状态，不检查localStorage
  const isLoggedIn = store.getters.isLoggedIn
  const token = store.state.token
  
  console.log(`[${guardId}] ========== 路由守卫触发 ==========`);
  console.log(`[${guardId}] 路由守卫 - 从:`, from.path, from.name);
  console.log(`[${guardId}] 路由守卫 - 到:`, to.path, to.name);
  console.log(`[${guardId}] 路由守卫 - 登录状态:`, {
    isLoggedIn,
    hasToken: !!token,
    tokenPreview: token ? `${token.substring(0, 10)}...` : '无token'
  });

  // 如果用户已登录且试图访问登录页，重定向到主页
  if (isLoggedIn && to.name === 'Login') {
    console.log(`[${guardId}] ⚠️ 已登录用户试图访问登录页，重定向到主页`);
    console.log(`[${guardId}] ========== 路由守卫结束 (重定向到主页) ==========`);
    next({ name: 'Home', replace: true })
    return
  }
  
  // 如果用户未登录且试图访问需要认证的页面，重定向到登录页
  if (!isLoggedIn && to.name !== 'Login' && to.path !== '/login') {
    console.log(`[${guardId}] ⚠️ 未登录用户试图访问受保护页面，重定向到登录页`);
    console.log(`[${guardId}] 调用栈:`, new Error().stack);
    console.log(`[${guardId}] ========== 路由守卫结束 (重定向到登录页) ==========`);
    next({ name: 'Login', replace: true })
    return
  }
  
  console.log(`[${guardId}] ✅ 路由守卫通过`);
  console.log(`[${guardId}] ========== 路由守卫结束 (通过) ==========`);
  next()
})
