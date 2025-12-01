import { appRoutes, appExternalRoutes } from '../routes';

const mixinRoutes = [...appRoutes, ...appExternalRoutes];

const appClientMenus = mixinRoutes
  .map((el) => {
    const { name, path, meta, redirect, children } = el;
    return {
      name,
      path,
      meta,
      redirect,
      children,
    };
  })
  .filter((menu) => {
    // 过滤掉开发模式专用但未开启的菜单
    const isDevModeOnly = menu.meta?.devModeOnly as boolean;
    if (isDevModeOnly) {
      // 检查是否启用了数据清理功能
      return import.meta.env.VITE_ENABLE_DATA_CLEANUP === 'true';
    }
    return true;
  });

export default appClientMenus;
