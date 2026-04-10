import { DEFAULT_LAYOUT } from '@/app/router/base-routes';
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
        component: () =>
          import('@/features/operations/pages/system-log-page.vue'),
        meta: {
          locale: 'menu.operations.systemLog',
          requiresAuth: true,
          perm: 'log:audit',
        },
      },
      {
        path: 'push-log',
        name: 'PushLog',
        component: () =>
          import('@/features/operations/pages/push-log-page.vue'),
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
        component: () =>
          import('@/features/operations/pages/cos-test-page.vue'),
        meta: {
          locale: 'menu.operations.cosTest',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'ipinfo-token',
        name: 'IpInfoTokenSettings',
        component: () =>
          import('@/features/operations/pages/ipinfo-token-page.vue'),
        meta: {
          locale: 'menu.operations.ipinfoToken',
          requiresAuth: true,
          perm: 'system:settings',
        },
      },
      {
        path: 'api-metrics',
        name: 'ApiMetrics',
        component: () =>
          import('@/features/operations/pages/api-metrics-page.vue'),
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
          import('@/features/operations/pages/file-upload-audit-page.vue'),
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
                import('@/features/operations/pages/data-cleanup-page.vue'),
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
