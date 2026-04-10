import type { Router, LocationQueryRaw } from 'vue-router';
import NProgress from 'nprogress'; // progress bar

import { useUserStore } from '@/store';
import { isLogin } from '@/services/auth-runtime';
import appRoutes from '@/app/router/routes';
import { findFirstAccessibleRoute } from '@/shared/access/route-access';

export default function setupUserLoginInfoGuard(router: Router) {
  router.beforeEach(async (to, from, next) => {
    NProgress.start();
    const userStore = useUserStore();
    if (isLogin()) {
      try {
        const sessionReady = await userStore.ensureSession();
        if (!sessionReady) {
          throw new Error('session not ready');
        }

        if (to.name === 'login') {
          const destination = findFirstAccessibleRoute(appRoutes, {
            roleCodes: userStore.roleCodes,
            permissionKeys: userStore.permissionKeys,
            isSuperAdmin: userStore.isSuperAdmin,
            role: userStore.role,
          }) || { name: 'login' };

          next(destination);
          return;
        }

        next();
      } catch (error) {
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
