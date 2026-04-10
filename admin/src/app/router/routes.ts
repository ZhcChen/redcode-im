import type { RouteRecordRaw } from 'vue-router';

import dashboardRoutes from '@/features/dashboard/routes';
import userManagementRoutes from '@/features/user-management/routes';
import accessControlRoutes from '@/features/access-control/routes';
import operationsRoutes from '@/features/operations/routes';
import settingsRoutes from '@/features/settings/routes';
import versionRoutes from '@/features/version/routes';

const appRoutes = [
  ...dashboardRoutes,
  ...userManagementRoutes,
  ...accessControlRoutes,
  ...operationsRoutes,
  ...settingsRoutes,
  ...versionRoutes,
] as RouteRecordRaw[];

export default appRoutes;
