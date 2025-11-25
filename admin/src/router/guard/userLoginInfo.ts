import type { Router, LocationQueryRaw } from 'vue-router';
import NProgress from 'nprogress'; // progress bar

import { useUserStore } from '@/store';
import { isLogin } from '@/utils/auth';

export default function setupUserLoginInfoGuard(router: Router) {
  router.beforeEach(async (to, from, next) => {
    NProgress.start();
    const userStore = useUserStore();
    console.log(
      '[路由守卫] 页面刷新，isLogin:',
      isLogin(),
      'userStore.role:',
      userStore.role,
      'userStore.avatar:',
      userStore.avatar
    );

    if (isLogin()) {
      try {
        console.log('[路由守卫] 开始获取用户信息...');
        // 总是获取最新的用户信息，确保头像等数据是最新的
        await userStore.info();
        console.log(
          '[路由守卫] 获取用户信息完成，userStore.avatar:',
          userStore.avatar
        );
        next();
      } catch (error) {
        console.error('[路由守卫] 获取用户信息失败:', error);
        await userStore.logout();
        next({
          name: 'login',
          query: {
            redirect: to.name,
            ...to.query,
          } as LocationQueryRaw,
        });
      }
    } else {
      console.log('[路由守卫] 未登录，跳转到登录页');
      if (to.name === 'login') {
        next();
        return;
      }
      next({
        name: 'login',
        query: {
          redirect: to.name,
          ...to.query,
        } as LocationQueryRaw,
      });
    }
  });
}
