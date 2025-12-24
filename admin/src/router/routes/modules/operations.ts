import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const isDataCleanupEnabled =
  import.meta.env.VITE_ENABLE_DATA_CLEANUP === 'true';

const OPERATIONS: AppRouteRecordRaw = {
  path: '/operations',
  name: 'Operations',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'menu.operations',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 2,
  },
  children: [
    {
      path: 'system-log',
      name: 'SystemLog',
      component: () => import('@/views/dashboard/system-log/index.vue'),
      meta: {
        locale: 'menu.operations.systemLog',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'storage-provider',
      name: 'StorageProviderSettings',
      component: () => import('@/views/settings/storage-provider/index.vue'),
      meta: {
        locale: 'menu.operations.storageProvider',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'cos-test',
      name: 'CosTestSettings',
      component: () => import('@/views/settings/cos-test/index.vue'),
      meta: {
        locale: 'menu.operations.cosTest',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'ipinfo-token',
      name: 'IpInfoTokenSettings',
      component: () => import('@/views/settings/ipinfo-token/index.vue'),
      meta: {
        locale: 'menu.operations.ipinfoToken',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'api-metrics',
      name: 'ApiMetrics',
      component: () => import('@/views/operations/api-metrics/index.vue'),
      meta: {
        locale: 'menu.operations.apiMetrics',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    {
      path: 'file-upload-audit',
      name: 'FileUploadAudit',
      component: () => import('@/views/operations/file-upload-audit/index.vue'),
      meta: {
        locale: 'menu.operations.fileUploadAudit',
        requiresAuth: true,
        roles: ['admin'],
      },
    },
    ...(isDataCleanupEnabled
      ? [
          {
            path: 'data-cleanup',
            name: 'DataCleanup',
            component: () => import('@/views/settings/data-cleanup/index.vue'),
            meta: {
              locale: 'menu.operations.dataCleanup',
              requiresAuth: true,
              roles: ['admin'],
            },
          },
        ]
      : []),
  ],
};

export default OPERATIONS;
