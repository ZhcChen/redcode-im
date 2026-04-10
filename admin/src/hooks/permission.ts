import { RouteLocationNormalized, RouteRecordRaw } from 'vue-router';
import { useUserStore } from '@/store';
import {
  canAccessRoute,
  findFirstAccessibleRoute,
} from '@/shared/access/route-access';

export default function usePermission() {
  const userStore = useUserStore();

  const getAccess = () => ({
    roleCodes: userStore.roleCodes,
    permissionKeys: userStore.permissionKeys,
    isSuperAdmin: userStore.isSuperAdmin,
    role: userStore.role,
  });

  return {
    accessRouter(route: RouteLocationNormalized | RouteRecordRaw) {
      return canAccessRoute(route, getAccess());
    },
    findFirstPermissionRoute(routers: RouteRecordRaw[]) {
      return findFirstAccessibleRoute(routers, getAccess());
    },
  };
}
