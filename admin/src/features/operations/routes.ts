import { DEFAULT_LAYOUT } from '@/router/routes/base';
import type { AppRouteRecordRaw } from '@/app/router/route-types';

const isDataCleanupEnabled =
  import.meta.env.VITE_ENABLE_DATA_CLEANUP === 'true';

const operationsRoutes: AppRouteRecordRaw[] = [
  {
    path: '/operations',
    name: 'Operations',
    component: DEFAULT_LAYOUT,
    meta: {
      locale: 'menu.operations',
      requiresAuth: true,
      icon: 'icon-settings',
      order: 3,
    },
    children: [
      {
        path: 'system-log',
        name: 'SystemLog',
        component: () => import('@/views/dashboard/system-log/index.vue'),
        meta: {
          locale: 'menu.operations.systemLog',
          requiresAuth: true,
          perm: 'log:audit',
        },
      },
      {
        path: 'push-log',
        name: 'PushLog',
        component: () => import('@/views/operations/push-log/index.vue'),
        meta: {
          locale: 'menu.operations.pushLog',
          requiresAuth: true,
          perm: 'log:audit',
        },
      },
      {
        path: 'storage-provider',
        name: 'StorageProviderSettings',
        component: () =>
          import('@/features/operations/pages/storage-provider-page.vue'),
        meta: {
          locale: 'menu.operations.storageProvider',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'cos-test',
        name: 'CosTestSettings',
        component: () => import('@/views/settings/cos-test/index.vue'),
        meta: {
          locale: 'menu.operations.cosTest',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'ipinfo-token',
        name: 'IpInfoTokenSettings',
        component: () => import('@/views/settings/ipinfo-token/index.vue'),
        meta: {
          locale: 'menu.operations.ipinfoToken',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'api-metrics',
        name: 'ApiMetrics',
        component: () => import('@/views/operations/api-metrics/index.vue'),
        meta: {
          locale: 'menu.operations.apiMetrics',
          requiresAuth: true,
          perm: 'data:analysis',
        },
      },
      {
        path: 'file-upload-audit',
        name: 'FileUploadAudit',
        component: () =>
          import('@/views/operations/file-upload-audit/index.vue'),
        meta: {
          locale: 'menu.operations.fileUploadAudit',
          requiresAuth: true,
          perm: 'file:manage',
        },
      },
      ...(isDataCleanupEnabled
        ? [
            {
              path: 'data-cleanup',
              name: 'DataCleanup',
              component: () =>
                import('@/views/settings/data-cleanup/index.vue'),
              meta: {
                locale: 'menu.operations.dataCleanup',
                requiresAuth: true,
                superAdminOnly: true,
              },
            },
          ]
        : []),
    ],
  },
];

export default operationsRoutes;
