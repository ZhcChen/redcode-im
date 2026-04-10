import type { RouteLocationNormalized, RouteRecordRaw } from 'vue-router';

export interface AccessSnapshot {
  roleCodes: string[];
  permissionKeys: string[];
  isSuperAdmin: boolean;
  role?: string;
}

function normalizeRoles(roles?: string[]) {
  return roles?.map((item) => item.trim()).filter(Boolean) ?? [];
}

export function hasPermission(
  access: AccessSnapshot,
  permission?: string,
  options?: { superAdminOnly?: boolean }
) {
  if (access.isSuperAdmin) {
    return true;
  }

  if (options?.superAdminOnly) {
    return false;
  }

  if (!permission) {
    return true;
  }

  return access.permissionKeys.includes(permission);
}

export function canAccessRoute(
  route: RouteLocationNormalized | RouteRecordRaw,
  access: AccessSnapshot
) {
  if (!route.meta?.requiresAuth) {
    return true;
  }

  if (route.meta?.superAdminOnly) {
    return access.isSuperAdmin;
  }

  if (route.meta?.perm) {
    return hasPermission(access, route.meta.perm as string);
  }

  const legacyRoles = normalizeRoles(route.meta?.roles as string[] | undefined);
  if (!legacyRoles.length || legacyRoles.includes('*')) {
    return true;
  }

  return legacyRoles.some((role) => {
    return access.roleCodes.includes(role) || access.role === role;
  });
}

export function filterAccessibleRoutes(
  routes: RouteRecordRaw[],
  access: AccessSnapshot
): RouteRecordRaw[] {
  return routes.reduce<RouteRecordRaw[]>((collector, route) => {
    const nextChildren = route.children
      ? filterAccessibleRoutes(route.children, access)
      : undefined;
    const hasAccessibleChildren = Boolean(nextChildren?.length);

    if (!canAccessRoute(route, access) && !hasAccessibleChildren) {
      return collector;
    }

    collector.push(nextChildren ? { ...route, children: nextChildren } : route);
    return collector;
  }, []);
}

export function findFirstAccessibleRoute(
  routes: RouteRecordRaw[],
  access: AccessSnapshot
): { name?: string | symbol } | null {
  const queue = [...routes];

  while (queue.length > 0) {
    const current = queue.shift();
    const hasChildren = Boolean(current?.children?.length);
    const isLeafLike = Boolean(
      current?.name &&
        !current?.redirect &&
        !current?.meta?.hideInMenu &&
        (!hasChildren || current?.meta?.hideChildrenInMenu)
    );

    if (isLeafLike && current && canAccessRoute(current, access)) {
      return { name: current.name };
    }

    if (current?.children?.length) {
      queue.push(...current.children);
    }
  }

  return null;
}
