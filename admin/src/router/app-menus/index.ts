import appRoutes from '../routes';

// 在构建时确定的常量，避免环境变量缓存问题
const isDataCleanupEnabled =
  typeof __VITE_ENABLE_DATA_CLEANUP__ !== 'undefined'
    ? __VITE_ENABLE_DATA_CLEANUP__ === 'true'
    : false;

const appClientMenus = appRoutes
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
      return isDataCleanupEnabled;
    }
    return true;
  });

export default appClientMenus;
