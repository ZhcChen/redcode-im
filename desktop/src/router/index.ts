import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router';
import { store } from '@/store';
import Login from '@/views/Login.vue';
import AppShell from '@/views/AppShell.vue';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: () =>
      store.getters.isLoggedIn
        ? { name: 'AppShell' }
        : { name: 'Login' },
  },
  {
    path: '/login',
    name: 'Login',
    component: Login,
  },
  {
    path: '/app',
    name: 'AppShell',
    component: AppShell,
    meta: { requiresAuth: true },
  },
];

export const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, _from, next) => {
  const isLoggedIn = store.getters.isLoggedIn;

  if (to.meta.requiresAuth && !isLoggedIn) {
    return next({ name: 'Login', replace: true });
  }

  if (to.name === 'Login' && isLoggedIn) {
    return next({ name: 'AppShell', replace: true });
  }

  return next();
});
