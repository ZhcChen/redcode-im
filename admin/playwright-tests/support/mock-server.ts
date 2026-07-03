import type { Page, Request, Route } from '@playwright/test';

import { adminPassword } from './test-context';

interface FailureRule {
  endpoint: RegExp;
  status: number;
  message: string;
}

export interface AdminMockController {
  failNext(endpoint: RegExp, status: number, message?: string): void;
}

const now = '2026-03-05T00:00:00Z';

const adminUser = {
  id: 'admin-1',
  username: 'admin',
  email: 'admin@example.com',
  nickname: '系统管理员',
  avatarUrl: null,
  status: 'active',
  createdAt: now,
  updatedAt: now,
  roleCodes: ['super_admin'],
  permissionKeys: [
    'user:manage',
    'role:manage',
    'message:manage',
    'file:manage',
    'system:settings',
    'data:analysis',
    'log:audit',
  ],
  isSuperAdmin: true,
};

const rbacPermissions = [
  {
    id: 'perm-user-manage',
    name: '用户管理',
    code: 'user:manage',
    description: '管理用户账户',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'perm-role-manage',
    name: '角色管理',
    code: 'role:manage',
    description: '管理角色与权限',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'perm-message-manage',
    name: '消息管理',
    code: 'message:manage',
    description: '管理消息与聊天记录',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'perm-system-settings',
    name: '系统设置',
    code: 'system:settings',
    description: '管理系统配置',
    createdAt: now,
    updatedAt: now,
  },
];

const rbacRoles = [
  {
    id: 'role-super-admin',
    name: '超级管理员',
    code: 'super_admin',
    description: '拥有全部权限',
    isSystem: true,
    createdAt: now,
    updatedAt: now,
    permissions: rbacPermissions,
  },
  {
    id: 'role-ops',
    name: '运营管理员',
    code: 'operator',
    description: '负责用户与内容运营',
    isSystem: false,
    createdAt: now,
    updatedAt: now,
    permissions: rbacPermissions.slice(0, 2),
  },
];

const adminUsers = [
  {
    id: 'admin-1',
    username: 'admin',
    email: 'admin@example.com',
    nickname: '系统管理员',
    avatarUrl: null,
    status: 'active',
    lastLoginAt: now,
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'admin-2',
    username: 'ops',
    email: 'ops@example.com',
    nickname: '运营管理员',
    avatarUrl: null,
    status: 'active',
    lastLoginAt: now,
    createdAt: now,
    updatedAt: now,
  },
];

const adminUserRoleAssignments: Record<
  string,
  { roleIds: string[]; roleCodes: string[] }
> = {
  'admin-1': {
    roleIds: ['role-super-admin'],
    roleCodes: ['super_admin'],
  },
  'admin-2': {
    roleIds: ['role-ops'],
    roleCodes: ['operator'],
  },
};

const storageProvider = {
  id: 'sp-1',
  provider_type: 'backblaze_b2',
  name: '测试 B2 配置',
  secret_id: '',
  secret_key: '',
  secret_id_configured: true,
  secret_key_configured: true,
  region: 'us-east-005',
  endpoint: 'https://s3.us-east-005.backblazeb2.com',
  bucket_name: 'demo-private-bucket',
  is_active: true,
  is_default: true,
  description: 'e2e provider',
  created_at: now,
  updated_at: now,
  updated_by: 'admin',
};

const objectStorageCurrent = {
  source: 'database',
  version: 3,
  provider: 'backblaze_b2',
  endpoint: 'https://s3.us-east-005.backblazeb2.com',
  region: 'us-east-005',
  private_bucket: 'demo-private-bucket',
  public_bucket: 'demo-public-bucket',
  public_base_url: 'https://cdn.example.com',
  upload_url_ttl_seconds: 900,
  download_url_ttl_seconds: 600,
  key_id_configured: true,
  application_key_configured: true,
  last_applied_by: 'admin',
  last_applied_at: now,
  rollback_source_version: null,
  updated_at: now,
};

const objectStorageHistory = [
  {
    ...objectStorageCurrent,
    status: 'active',
    change_note: '切换到新的 B2 Key',
    created_by: 'admin',
    created_at: now,
    applied_by: 'admin',
    applied_at: now,
  },
  {
    ...objectStorageCurrent,
    version: 2,
    status: 'superseded',
    change_note: '初始接入 B2',
    created_by: 'admin',
    created_at: now,
    applied_by: 'admin',
    applied_at: now,
  },
];

const objectStorageProbePayload = {
  normalized: objectStorageCurrent,
  probe: {
    status: 'pass',
    allowed_capabilities: [
      'listBuckets',
      'readFiles',
      'writeBuckets',
      'writeFiles',
    ],
    required_runtime_capabilities: ['readFiles', 'writeFiles'],
    missing_runtime_capabilities: [],
    bucket_init_supported: true,
    s3_api_url: 'https://s3.us-east-005.backblazeb2.com',
    allowed: {
      buckets: [
        {
          id: 'bucket-1',
          name: 'demo-private-bucket',
        },
      ],
      name_prefix: null,
    },
    checks: [
      {
        code: 'authorize_account',
        status: 'pass',
        message: 'B2 authorize_account 成功。',
      },
      {
        code: 'runtime_capabilities',
        status: 'pass',
        message: '运行时所需能力齐全。',
      },
      {
        code: 'bucket_init_capability',
        status: 'pass',
        message: '当前 key 具备 writeBuckets，可执行初始化桶。',
      },
    ],
  },
};

const objectStorageBucketInitPayload = {
  current: objectStorageCurrent,
  result: {
    status: 'success',
    items: [
      {
        bucket_name: 'demo-private-bucket',
        bucket_role: 'private',
        status: 'already_exists',
        message: '当前 key 的允许桶范围已包含该桶。',
      },
      {
        bucket_name: 'demo-public-bucket',
        bucket_role: 'public',
        status: 'already_exists',
        message: '当前 key 的允许桶范围已包含该桶。',
      },
    ],
  },
};

const sampleChatMessage = {
  id: 'msg-1',
  room_id: 'room-e2e',
  room_name: 'E2E 房间',
  sender_id: 'user-e2e',
  sender_name: 'Alice',
  sender_avatar: null,
  message_type: 'text',
  content: 'hello from e2e',
  parts: [],
  created_at: now,
  updated_at: now,
};

const sampleWorldGeoJson = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      properties: { name: 'DemoLand' },
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [100.0, 30.0],
            [101.0, 30.0],
            [101.0, 31.0],
            [100.0, 31.0],
            [100.0, 30.0],
          ],
        ],
      },
    },
  ],
};

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function parseJsonBody(request: Request): Record<string, any> {
  const raw = request.postData();
  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw) as Record<string, any>;
  } catch {
    return {};
  }
}

export async function bootstrapAdminSession(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem('token', 'e2e-token');
    window.localStorage.setItem('refresh_token', 'e2e-refresh-token');
    window.localStorage.setItem('arco-locale', 'zh-CN');
  });
}

function jsonResponse(route: Route, status: number, body: unknown) {
  return route.fulfill({
    status,
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(body),
  });
}

function textResponse(route: Route, status: number, body: string) {
  return route.fulfill({
    status,
    contentType: 'text/plain; charset=utf-8',
    body,
  });
}

function isApiPath(pathname: string) {
  return (
    pathname.startsWith('/api/') ||
    pathname.startsWith('/auth/') ||
    pathname.startsWith('/settings/') ||
    pathname.startsWith('/admin/') ||
    pathname.startsWith('/versions/')
  );
}

function isGeoDataUrl(url: URL) {
  return (
    url.hostname === 'geo.datav.aliyun.com' ||
    (url.hostname === 'raw.githubusercontent.com' &&
      (url.pathname.includes('world.geojson') ||
        url.pathname.includes('world-countries.json')))
  );
}

function buildSuccessBody(pathname: string, method: string, url: URL) {
  // Auth
  if (pathname === '/auth/admin/login' && method === 'POST') {
    return {
      token: 'e2e-token',
      refresh_token: 'e2e-refresh-token',
      user: adminUser,
    };
  }

  if (pathname === '/auth/admin/refresh' && method === 'POST') {
    return {
      token: 'e2e-token-refresh',
      refresh_token: 'e2e-refresh-token-refresh',
    };
  }

  if (pathname === '/auth/admin/me' && method === 'GET') {
    return adminUser;
  }

  if (pathname === '/auth/admin/me' && method === 'PATCH') {
    return adminUser;
  }

  if (pathname === '/auth/admin/me/password' && method === 'POST') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/user/menu' && method === 'POST') {
    return [];
  }

  if (pathname === '/api/admin/permissions' && method === 'GET') {
    return {
      permissions: rbacPermissions,
    };
  }

  if (pathname === '/api/admin/roles' && method === 'GET') {
    return {
      roles: rbacRoles,
    };
  }

  if (pathname === '/api/admin/admin-users' && method === 'GET') {
    return {
      users: adminUsers,
      total: adminUsers.length,
      page: 1,
      page_size: 20,
    };
  }

  if (
    /^\/api\/admin\/admin-users\/[^/]+\/roles$/.test(pathname) &&
    method === 'GET'
  ) {
    const adminUserId = pathname.split('/')[4];
    const assignment = adminUserRoleAssignments[adminUserId] || {
      roleIds: [],
      roleCodes: [],
    };

    return {
      adminUserId,
      roleIds: assignment.roleIds,
      roleCodes: assignment.roleCodes,
    };
  }

  // Dashboard
  if (pathname === '/api/dashboard/stats' && method === 'GET') {
    return {
      totalUsers: 100,
      onlineUsers: 23,
      totalRooms: 12,
      activeRooms: 5,
      totalMessages: 1200,
      todayMessages: 96,
      systemLoad: 0.4,
      memoryUsage: 0.52,
      storageUsage: 0.27,
    };
  }

  if (pathname === '/api/dashboard/monitor' && method === 'GET') {
    return {
      cpu: 0.32,
      memory: 0.54,
      disk: 0.43,
      network_in: 1024,
      network_out: 2048,
      connections: 48,
    };
  }

  if (pathname === '/api/dashboard/statistics' && method === 'GET') {
    return {
      daily_active_users: [{ date: '2026-03-05', count: 20 }],
      daily_messages: [{ date: '2026-03-05', count: 120 }],
      storage_usage_by_type: [
        {
          file_type: 'image',
          count: 12,
          size_bytes: 1024,
          percentage: 25,
        },
      ],
      user_growth_rate: 0.08,
      message_growth_rate: 0.12,
      peak_active_time: '20:00',
    };
  }

  if (pathname === '/api/dashboard/storage-stats' && method === 'GET') {
    return {
      totalFiles: 88,
      totalSize: 1024 * 1024,
      todayUploads: 9,
    };
  }

  if (pathname === '/api/dashboard/emoji-stats' && method === 'GET') {
    return {
      totalEmojis: 42,
      todayUsage: 15,
      popularCount: 8,
    };
  }

  if (
    pathname === '/api/admin/users/geolocation/distribution' &&
    method === 'GET'
  ) {
    return [
      {
        latitude: 31.23,
        longitude: 121.47,
        country: 'China',
        region: 'Shanghai',
        city: 'Shanghai',
        user_count: 10,
        users: [
          {
            user_id: 'user-e2e',
            username: 'alice',
            nickname: 'Alice',
          },
        ],
      },
    ];
  }

  if (pathname === '/api/admin/nodes/monitor' && method === 'GET') {
    return [
      {
        nodeId: 'node-1',
        address: '10.0.0.1:8010',
        connectedUsers: 11,
        activeRooms: 4,
        cpuUsage: 0.4,
        memoryUsage: 0.48,
        diskUsage: 0.52,
        cpuCount: 4,
        totalMemory: 8 * 1024 * 1024 * 1024,
        lastHeartbeat: now,
        startedAt: now,
      },
    ];
  }

  if (pathname === '/api/chat/list' && method === 'POST') {
    return [
      {
        id: 1,
        username: 'alice',
        content: 'hello',
        time: now,
        isCollect: false,
      },
    ];
  }

  if (pathname === '/api/message/list' && method === 'POST') {
    return [];
  }

  if (pathname === '/api/message/read' && method === 'POST') {
    return [];
  }

  // Operations
  if (pathname === '/api/admin/logs' && method === 'GET') {
    return {
      logs: [
        {
          id: 'log-1',
          level: 'INFO',
          target: 'api',
          message: 'log message',
          fields: {},
          nodeId: 'node-1',
          createdAt: now,
        },
      ],
      total: 1,
      limit: 50,
      offset: 0,
    };
  }

  if (pathname === '/api/admin/logs/stats' && method === 'GET') {
    return {
      totalCount: 1,
      debugCount: 0,
      infoCount: 1,
      warnCount: 0,
      errorCount: 0,
      oldestLog: now,
      newestLog: now,
    };
  }

  if (pathname === '/api/admin/logs/cleanup' && method === 'POST') {
    return {
      success: true,
      deletedCount: 1,
      message: 'cleanup ok',
    };
  }

  if (pathname === '/api/admin/push/logs' && method === 'GET') {
    return {
      logs: [
        {
          id: 'push-1',
          pushId: 'push-id',
          userId: 'user-e2e',
          username: 'alice',
          nickname: 'Alice',
          deviceId: 'device-1',
          platform: 'android',
          channel: 'stable',
          provider: 'fcm',
          eventType: 'message',
          title: 'title',
          body: 'body',
          data: {},
          attempt: 1,
          success: true,
          createdAt: now,
        },
      ],
      total: 1,
      limit: 50,
      offset: 0,
    };
  }

  if (pathname === '/api/admin/push/logs/cleanup' && method === 'POST') {
    return {
      success: true,
      deletedCount: 1,
      message: 'cleanup ok',
    };
  }

  if (pathname === '/api/admin/metrics/performance' && method === 'GET') {
    return {
      metrics: [
        {
          method: 'GET',
          path: '/healthz',
          count: 10,
          avg_duration: 20,
          max_duration: 45,
        },
      ],
      top_avg: [],
      top_count: [],
      total: 1,
      page: 1,
      page_size: 20,
    };
  }

  if (pathname === '/api/admin/file-upload-audit/tasks' && method === 'GET') {
    return {
      tasks: [
        {
          id: 'task-1',
          storageProviderId: 'sp-1',
          objectKey: 'demo/file.png',
          scene: 'chat',
          mediaKind: 'image',
          contentType: 'image/png',
          fileSize: 123,
          status: 1,
          vendorJobId: 'vendor-job-1',
          attempts: 1,
          nextRunAt: now,
          auditedAt: now,
          createdAt: now,
          updatedAt: now,
        },
      ],
      total: 1,
      limit: 50,
      offset: 0,
    };
  }

  if (
    /^\/api\/admin\/file-upload-audit\/tasks\/[^/]+$/.test(pathname) &&
    method === 'GET'
  ) {
    return {
      task: {
        id: 'task-1',
        storageProviderId: 'sp-1',
        objectKey: 'demo/file.png',
        scene: 'chat',
        mediaKind: 'image',
        contentType: 'image/png',
        fileSize: 123,
        status: 1,
        result: {},
        attempts: 1,
        nextRunAt: now,
        auditedAt: now,
        createdAt: now,
        updatedAt: now,
      },
    };
  }

  if (
    /^\/api\/admin\/file-upload-audit\/tasks\/[^/]+\/requeue$/.test(pathname) &&
    method === 'POST'
  ) {
    return {
      success: true,
      message: 'requeue ok',
    };
  }

  // Settings
  if (pathname === '/api/admin/settings/captcha' && method === 'GET') {
    return {
      enabled: true,
      captcha_code: '1234',
      description: 'captcha',
      require_captcha_for_login: true,
      updated_at: now,
      deleted_at: null,
    };
  }

  if (pathname === '/api/admin/settings/captcha' && method === 'POST') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/settings/privacy-policy' && method === 'GET') {
    return {
      key: 'privacy',
      title: '隐私协议',
      content: 'privacy content',
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/api/admin/settings/privacy-policy' && method === 'POST') {
    return {
      key: 'privacy',
      title: '隐私协议',
      content: 'privacy content',
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/api/admin/settings/user-agreement' && method === 'GET') {
    return {
      key: 'agreement',
      title: '用户协议',
      content: 'agreement content',
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/api/admin/settings/user-agreement' && method === 'POST') {
    return {
      key: 'agreement',
      title: '用户协议',
      content: 'agreement content',
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/settings/general' && method === 'GET') {
    return {
      app_name: 'Chatly',
    };
  }

  if (pathname === '/settings/app-name' && method === 'GET') {
    return {
      app_name: 'Chatly',
    };
  }

  if (pathname === '/api/admin/settings/app-name' && method === 'PUT') {
    return {
      app_name: 'Chatly',
    };
  }

  if (pathname === '/api/admin/ip-geolocation/enabled' && method === 'GET') {
    return {
      enabled: true,
      description: 'enabled',
    };
  }

  if (pathname === '/api/admin/ip-geolocation/enabled' && method === 'PATCH') {
    return {
      enabled: true,
      description: 'enabled',
    };
  }

  if (
    pathname === '/api/admin/settings/user-account-limit' &&
    method === 'GET'
  ) {
    return {
      enable_email_auth: false,
      enable_phone_validation: true,
      enable_email_validation: false,
      enable_length_validation: true,
      min_length: 6,
      max_length: 30,
      enable_alphanumeric_validation: true,
    };
  }

  if (
    pathname === '/api/admin/settings/user-account-limit' &&
    method === 'PUT'
  ) {
    return {
      enable_email_auth: false,
      enable_phone_validation: true,
      enable_email_validation: false,
      enable_length_validation: true,
      min_length: 6,
      max_length: 30,
      enable_alphanumeric_validation: true,
    };
  }

  if (pathname === '/api/admin/settings/upload-policy' && method === 'GET') {
    return {
      policy: {
        version: '2026-03-05',
        max_total_size_mb: 200,
        max_attachments_per_message: 20,
        max_size_mb_by_part_type: {
          image: 10,
          video: 200,
          audio: 50,
          file: 100,
        },
        mime_by_part_type: {
          image: ['image/png'],
          video: ['video/mp4'],
          audio: ['audio/mp4'],
          file: ['application/pdf'],
        },
        mime_whitelist: [
          'image/png',
          'video/mp4',
          'audio/mp4',
          'application/pdf',
        ],
        audio_only: {
          enabled: true,
          force_single_attachment: true,
          allow_text: false,
        },
      },
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/api/admin/settings/upload-policy' && method === 'PUT') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/settings/push' && method === 'GET') {
    return {
      enabled: true,
      skip_if_online: true,
      providers: [
        {
          id: 'fcm-1',
          provider: 'fcm',
          platform: 'all',
          enabled: true,
          config_public: {
            project_id: 'demo-project',
            client_email: 'demo@example.com',
          },
          has_secret: true,
          secret_fingerprint: 'abc123',
          updated_at: now,
          updated_by: 'admin',
        },
      ],
    };
  }

  if (pathname === '/api/admin/settings/push' && method === 'PUT') {
    return {
      enabled: true,
      skip_if_online: true,
      providers: [],
    };
  }

  if (/^\/api\/admin\/settings\/push\/providers\/.+$/.test(pathname)) {
    return {
      id: 'fcm-1',
      provider: 'fcm',
      platform: 'all',
      enabled: true,
      config_public: {
        project_id: 'demo-project',
      },
      has_secret: true,
      secret_fingerprint: 'abc123',
      updated_at: now,
      updated_by: 'admin',
    };
  }

  if (pathname === '/api/admin/settings/push/test' && method === 'POST') {
    return {
      success: true,
      message: 'test sent',
    };
  }

  if (pathname === '/api/admin/push/job-queue/stats' && method === 'GET') {
    return {
      pending: 0,
      retry: 0,
      done: 10,
      failed: 0,
      due: 0,
      next_run_at: now,
      oldest_created_at: now,
    };
  }

  if (pathname === '/api/admin/emoji-packs' && method === 'GET') {
    const parentId = url.searchParams.get('parent_id');
    if (parentId) {
      return [
        {
          id: 'emoji-pack-1',
          name: '默认贴纸',
          icon_url: null,
          icon_object_key: null,
          description: 'default',
          is_active: true,
          pack_type: 0,
          parent_id: parentId,
          created_at: now,
          updated_at: now,
        },
      ];
    }

    return [
      {
        id: 'emoji-suite-1',
        name: '默认贴纸包',
        icon_url: null,
        icon_object_key: null,
        description: 'suite',
        is_active: true,
        pack_type: 1,
        parent_id: null,
        created_at: now,
        updated_at: now,
      },
    ];
  }

  if (/^\/api\/admin\/emoji-packs\/[^/]+$/.test(pathname) && method === 'GET') {
    return {
      id: 'emoji-pack-1',
      name: '默认贴纸',
      icon_url: null,
      icon_object_key: null,
      description: 'pack',
      is_active: true,
      pack_type: 0,
      parent_id: 'emoji-suite-1',
      created_at: now,
      updated_at: now,
      items: [
        {
          id: 'emoji-item-1',
          pack_id: 'emoji-pack-1',
          image_url: 'https://example.com/emoji.png',
          image_object_key: null,
          name: '开心',
          sort_order: 1,
          created_at: now,
        },
      ],
    };
  }

  if (/^\/api\/admin\/emoji-packs\/[^/]+$/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (/^\/api\/admin\/emoji-items\/.+$/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/emoji-items' && method === 'POST') {
    return {
      id: 'emoji-item-1',
      pack_id: 'emoji-pack-1',
      image_url: 'https://example.com/emoji.png',
      image_object_key: null,
      name: '开心',
      sort_order: 1,
      created_at: now,
    };
  }

  // User / Content / Chat
  if (pathname === '/api/admin/users' && method === 'GET') {
    return {
      users: [
        {
          id: 'user-e2e',
          username: 'alice',
          nickname: 'Alice',
          email: 'alice@example.com',
          status: 'active',
          avatar_url: null,
          created_at: now,
          updated_at: now,
          deleted_at: null,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    };
  }

  if (
    /^\/api\/admin\/users\/[^/]+\/status$/.test(pathname) &&
    method === 'PATCH'
  ) {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/feedbacks' && method === 'GET') {
    return {
      feedbacks: [
        {
          id: 'feedback-1',
          userId: 'user-e2e',
          username: 'alice',
          nickname: 'Alice',
          contact: 'alice@example.com',
          content: '反馈内容',
          createdAt: now,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    };
  }

  if (pathname === '/api/admin/reports' && method === 'GET') {
    return {
      reports: [
        {
          id: 'report-1',
          reporterId: 'user-e2e',
          reporterUsername: 'alice',
          reporterNickname: 'Alice',
          targetType: 'room',
          targetId: 'room-e2e',
          targetName: 'E2E 房间',
          content: '举报内容',
          createdAt: now,
          attachments: [],
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    };
  }

  if (pathname === '/api/admin/chat-history' && method === 'GET') {
    return {
      messages: [sampleChatMessage],
      total: 1,
      page: 1,
      pageSize: 20,
    };
  }

  if (
    /^\/api\/admin\/rooms\/[^/]+\/chat-history$/.test(pathname) &&
    method === 'GET'
  ) {
    return {
      messages: [sampleChatMessage],
      total: 1,
      page: 1,
      pageSize: 20,
    };
  }

  if (
    /^\/api\/admin\/users\/[^/]+\/rooms$/.test(pathname) &&
    method === 'GET'
  ) {
    return {
      rooms: [
        {
          id: 'room-e2e',
          name: 'E2E 房间',
          description: 'room',
          avatar_url: null,
          is_private: false,
          is_group: true,
          member_count: 3,
          last_message: sampleChatMessage,
          created_at: now,
          updated_at: now,
        },
      ],
      total: 1,
    };
  }

  // Versions
  if (pathname === '/api/admin/app-versions' && method === 'GET') {
    const platform = url.searchParams.get('platform') || 'android';
    return {
      total: 1,
      items: [
        {
          id: `version-${platform}`,
          platform,
          version: '1.0.0',
          build_number: 1,
          channel: 'stable',
          download_key: `${platform}/1.0.0/app.zip`,
          download_url: null,
          app_store_url: null,
          file_size: 1024,
          checksum: 'sha256-demo',
          signature: null,
          release_notes: 'release',
          mandatory: false,
          is_active: true,
          created_at: now,
          updated_at: now,
          released_at: now,
        },
      ],
    };
  }

  if (pathname === '/api/admin/app-versions' && method === 'POST') {
    return {
      id: 'version-new',
      platform: 'android',
      version: '1.0.1',
      build_number: 2,
      channel: 'stable',
      download_key: 'android/1.0.1/app.zip',
      mandatory: false,
      is_active: true,
      created_at: now,
      updated_at: now,
    };
  }

  if (
    /^\/api\/admin\/app-versions\/[^/]+$/.test(pathname) &&
    method === 'GET'
  ) {
    return {
      id: 'version-1',
      platform: 'android',
      version: '1.0.0',
      build_number: 1,
      channel: 'stable',
      download_key: 'android/1.0.0/app.zip',
      mandatory: false,
      is_active: true,
      created_at: now,
      updated_at: now,
    };
  }

  if (/^\/api\/admin\/app-versions\/.+/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/app-versions/upload/signature') {
    return {
      success: true,
      message: 'ok',
      key: 'upload-key',
      signature: {
        url: 'https://example.com/upload',
        method: 'PUT',
        headers: {},
        key: 'upload-key',
      },
    };
  }

  if (pathname === '/api/admin/app-versions/upload/multipart/initiate') {
    return {
      success: true,
      message: 'ok',
      key: 'upload-key',
      session_id: 'session-1',
      part_size: 1024,
      total_parts: 1,
    };
  }

  if (pathname === '/versions/download') {
    return {
      success: true,
      message: 'ok',
      download_url: 'https://example.com/download.zip',
    };
  }

  // Hot update
  if (pathname === '/api/admin/hot-updates' && method === 'GET') {
    return {
      total: 1,
      items: [
        {
          id: 'hot-1',
          platform: 'android',
          app_version_id: 'version-android',
          patch_version: '1.0.0-p1',
          channel: 'stable',
          download_key: 'hot/1.0.0-p1.patch',
          file_size: 1024,
          checksum: 'sha256-hot',
          signature: null,
          rollout_percentage: 100,
          mandatory: false,
          description: 'hot update',
          is_active: true,
          released_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
    };
  }

  if (pathname === '/api/admin/hot-updates/events' && method === 'GET') {
    return {
      total: 1,
      items: [
        {
          id: 'evt-1',
          platform: 'android',
          channel: 'stable',
          base_version: '1.0.0',
          patch_version: '1.0.0-p1',
          event_type: 'download_success',
          client_id: 'client-1',
          message: 'ok',
          created_at: now,
          client_type: 'frontend',
          os_version: 'Android 16',
          trigger_source: 'manual',
          network_type: 'wifi',
          device_info: 'Pixel 8 Pro',
        },
      ],
    };
  }

  if (/^\/api\/admin\/hot-updates\/.+/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  // Data cleanup
  if (pathname === '/admin/data/cleanup/all' && method === 'POST') {
    return {
      success: true,
      message: 'cleanup done',
    };
  }

  // Storage provider and object storage tests
  if (pathname === '/api/admin/system/storage-config' && method === 'GET') {
    return {
      current: objectStorageCurrent,
    };
  }

  if (
    pathname === '/api/admin/system/storage-config/history' &&
    method === 'GET'
  ) {
    return {
      list: objectStorageHistory,
    };
  }

  if (
    pathname === '/api/admin/system/storage-config/validate' &&
    method === 'POST'
  ) {
    return {
      valid: true,
      normalized: objectStorageCurrent,
    };
  }

  if (
    pathname === '/api/admin/system/storage-config/probe' &&
    method === 'POST'
  ) {
    return objectStorageProbePayload;
  }

  if (
    pathname === '/api/admin/system/storage-config/apply' &&
    method === 'POST'
  ) {
    return {
      current: objectStorageCurrent,
      version: objectStorageCurrent.version,
      applied_at: objectStorageCurrent.last_applied_at,
    };
  }

  if (
    pathname === '/api/admin/system/storage-config/init-bucket' &&
    method === 'POST'
  ) {
    return objectStorageBucketInitPayload;
  }

  if (
    pathname === '/api/admin/system/storage-config/rollback' &&
    method === 'POST'
  ) {
    return {
      current: {
        ...objectStorageCurrent,
        version: 4,
        rollback_source_version: 2,
      },
      version: 4,
      rolled_back_from_version: 2,
      applied_at: now,
    };
  }

  if (pathname === '/api/admin/storage-providers/default' && method === 'GET') {
    return storageProvider;
  }

  if (pathname === '/api/admin/storage-providers' && method === 'GET') {
    return {
      data: {
        providers: [storageProvider],
      },
    };
  }

  if (pathname === '/api/admin/storage-providers' && method === 'POST') {
    return storageProvider;
  }

  if (/^\/api\/admin\/storage-providers\/[^/]+$/.test(pathname)) {
    return storageProvider;
  }

  if (pathname === '/api/admin/storage-providers/test/upload/signature') {
    return {
      success: true,
      message: 'ok',
      signature: {
        url: 'https://example.com/upload',
        method: 'PUT',
        headers: {},
        key: 'demo/file.png',
      },
    };
  }

  if (
    pathname === '/api/admin/storage-providers/test/upload/multipart/initiate'
  ) {
    return {
      success: true,
      message: 'ok',
      key: 'demo/file.png',
      session_id: 'multipart-1',
      part_size: 1024,
      total_parts: 1,
    };
  }

  if (pathname === '/api/admin/storage-providers/test/buckets') {
    return {
      success: true,
      message: 'ok',
      buckets: [
        {
          name: 'demo-bucket',
          region: 'ap-guangzhou',
          creation_date: now,
        },
      ],
    };
  }

  if (pathname === '/api/admin/storage-providers/test/cors/list') {
    return {
      success: true,
      message: 'ok',
      rules: [],
    };
  }

  if (pathname === '/api/admin/storage-providers/test/cors') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/storage-providers/test/download-url') {
    return {
      success: true,
      message: 'ok',
      url: 'https://example.com/object.png',
    };
  }

  if (pathname === '/api/admin/storage-providers/test/delete') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/storage-providers/test/exists') {
    return {
      success: true,
      exists: true,
      message: 'ok',
    };
  }

  if (pathname === '/api/admin/storage-providers/test/buckets/create') {
    return {
      success: true,
      message: 'ok',
    };
  }

  // IPInfo token management page uses axios directly
  if (pathname === '/api/admin/ipinfo-tokens' && method === 'GET') {
    return {
      list: [
        {
          id: 'iptoken-1',
          name: 'default',
          token: 'token-demo',
          monthlyLimit: 50000,
          usedCount: 100,
          resetDate: '2026-03-01',
          status: 'active',
          lastUsedAt: now,
          createdAt: now,
          updatedAt: now,
        },
      ],
      total: 1,
    };
  }

  if (pathname === '/api/admin/ipinfo-tokens' && method === 'POST') {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (/^\/api\/admin\/ipinfo-tokens\/[^/]+\/reset$/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  if (/^\/api\/admin\/ipinfo-tokens\/.+/.test(pathname)) {
    return {
      success: true,
      message: 'ok',
    };
  }

  return undefined;
}

function matchFailure(
  failures: FailureRule[],
  pathname: string
): FailureRule | undefined {
  const index = failures.findIndex((rule) => rule.endpoint.test(pathname));
  if (index < 0) {
    return undefined;
  }

  const [rule] = failures.splice(index, 1);
  return rule;
}

export async function installAdminMockServer(
  page: Page
): Promise<AdminMockController> {
  const failures: FailureRule[] = [];
  const permissionsState = cloneJson(rbacPermissions);
  const rolesState = cloneJson(rbacRoles);
  const adminUsersState = cloneJson(adminUsers);
  const adminUserRoleAssignmentsState = cloneJson(adminUserRoleAssignments);

  const getRoleById = (roleId: string) => {
    return rolesState.find((item) => item.id === roleId) || null;
  };

  const buildRoleCodes = (roleIds: string[]) => {
    return roleIds
      .map((roleId) => getRoleById(roleId)?.code)
      .filter((item): item is string => Boolean(item));
  };

  const syncAdminUserRoleAssignment = (
    adminUserId: string,
    roleIds: string[]
  ) => {
    adminUserRoleAssignmentsState[adminUserId] = {
      roleIds: [...roleIds],
      roleCodes: buildRoleCodes(roleIds),
    };
  };

  await bootstrapAdminSession(page);

  await page.route('**/*', async (route: Route, request: Request) => {
    const url = new URL(request.url());
    const pathname = url.pathname;
    const method = request.method().toUpperCase();

    if (request.resourceType() === 'document') {
      return route.continue();
    }

    if (isGeoDataUrl(url)) {
      return jsonResponse(route, 200, sampleWorldGeoJson);
    }

    if (!isApiPath(pathname)) {
      return route.continue();
    }

    const failure = matchFailure(failures, pathname);
    if (failure) {
      return jsonResponse(route, failure.status, {
        message: failure.message,
      });
    }

    if (pathname === '/api/admin/permissions' && method === 'GET') {
      return jsonResponse(route, 200, {
        permissions: permissionsState,
      });
    }

    if (pathname === '/api/admin/roles' && method === 'GET') {
      return jsonResponse(route, 200, {
        roles: rolesState,
      });
    }

    if (pathname === '/api/admin/roles' && method === 'POST') {
      const body = parseJsonBody(request);
      const permissionIds = Array.isArray(body.permission_ids)
        ? body.permission_ids
        : [];
      const role = {
        id: `role-${Date.now()}`,
        name: body.name || '新角色',
        code: body.code || `role_${rolesState.length + 1}`,
        description: body.description ?? null,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
        permissions: permissionsState.filter((item) =>
          permissionIds.includes(item.id)
        ),
      };

      rolesState.push(role);
      return jsonResponse(route, 200, role);
    }

    if (/^\/api\/admin\/roles\/[^/]+$/.test(pathname) && method === 'PATCH') {
      const roleId = pathname.split('/')[4];
      const role = getRoleById(roleId);
      const body = parseJsonBody(request);
      if (!role) {
        return jsonResponse(route, 404, { message: '角色不存在' });
      }

      role.name = body.name ?? role.name;
      role.description = Object.prototype.hasOwnProperty.call(
        body,
        'description'
      )
        ? body.description
        : role.description;
      if (Array.isArray(body.permission_ids)) {
        role.permissions = permissionsState.filter((item) =>
          body.permission_ids.includes(item.id)
        );
      }
      role.updatedAt = now;

      return jsonResponse(route, 200, role);
    }

    if (/^\/api\/admin\/roles\/[^/]+$/.test(pathname) && method === 'DELETE') {
      const roleId = pathname.split('/')[4];
      const roleIndex = rolesState.findIndex((item) => item.id === roleId);
      if (roleIndex >= 0) {
        rolesState.splice(roleIndex, 1);
      }

      Object.entries(adminUserRoleAssignmentsState).forEach(
        ([adminUserId, assignment]) => {
          const nextRoleIds = assignment.roleIds.filter(
            (item) => item !== roleId
          );
          syncAdminUserRoleAssignment(adminUserId, nextRoleIds);
        }
      );

      return jsonResponse(route, 200, {
        success: true,
        message: 'ok',
      });
    }

    if (/^\/api\/admin\/roles\/[^/]+\/permissions$/.test(pathname)) {
      const roleId = pathname.split('/')[4];
      const role = getRoleById(roleId);
      if (!role) {
        return jsonResponse(route, 404, { message: '角色不存在' });
      }

      if (method === 'GET') {
        return jsonResponse(route, 200, {
          roleId,
          permissionIds: role.permissions.map((item) => item.id),
          permissionCodes: role.permissions.map((item) => item.code),
        });
      }

      if (method === 'PUT') {
        const body = parseJsonBody(request);
        const permissionIds = Array.isArray(body.permission_ids)
          ? body.permission_ids
          : [];
        role.permissions = permissionsState.filter((item) =>
          permissionIds.includes(item.id)
        );
        role.updatedAt = now;

        return jsonResponse(route, 200, {
          roleId,
          permissionIds: role.permissions.map((item) => item.id),
          permissionCodes: role.permissions.map((item) => item.code),
        });
      }
    }

    if (pathname === '/api/admin/admin-users' && method === 'GET') {
      return jsonResponse(route, 200, {
        users: adminUsersState,
        total: adminUsersState.length,
        page: 1,
        pageSize: 20,
      });
    }

    if (pathname === '/api/admin/admin-users' && method === 'POST') {
      const body = parseJsonBody(request);
      const user = {
        id: `admin-${Date.now()}`,
        username: body.username || `admin_${adminUsersState.length + 1}`,
        email: body.email || `admin_${adminUsersState.length + 1}@example.com`,
        nickname: body.nickname ?? null,
        avatarUrl: null,
        status: 'active',
        lastLoginAt: null,
        createdAt: now,
        updatedAt: now,
      };

      adminUsersState.unshift(user);
      syncAdminUserRoleAssignment(user.id, []);
      return jsonResponse(route, 200, user);
    }

    if (/^\/api\/admin\/admin-users\/[^/]+\/roles$/.test(pathname)) {
      const adminUserId = pathname.split('/')[4];
      if (method === 'GET') {
        const assignment = adminUserRoleAssignmentsState[adminUserId] || {
          roleIds: [],
          roleCodes: [],
        };

        return jsonResponse(route, 200, {
          adminUserId,
          roleIds: assignment.roleIds,
          roleCodes: assignment.roleCodes,
        });
      }

      if (method === 'PUT') {
        const body = parseJsonBody(request);
        const roleIds = Array.isArray(body.role_ids) ? body.role_ids : [];
        syncAdminUserRoleAssignment(adminUserId, roleIds);
        const assignment = adminUserRoleAssignmentsState[adminUserId];

        return jsonResponse(route, 200, {
          adminUserId,
          roleIds: assignment.roleIds,
          roleCodes: assignment.roleCodes,
        });
      }
    }

    if (
      /^\/api\/admin\/admin-users\/[^/]+\/status$/.test(pathname) &&
      method === 'PATCH'
    ) {
      const adminUserId = pathname.split('/')[4];
      const body = parseJsonBody(request);
      const adminUser = adminUsersState.find((item) => item.id === adminUserId);
      if (adminUser) {
        adminUser.status = body.status || adminUser.status;
        adminUser.updatedAt = now;
      }

      return jsonResponse(route, 200, {
        success: true,
        message: 'ok',
      });
    }

    const successBody = buildSuccessBody(pathname, method, url);
    if (typeof successBody !== 'undefined') {
      return jsonResponse(route, 200, successBody);
    }

    // 未显式声明的 API 兜底，避免因漏配造成页面白屏。
    if (method === 'GET') {
      return jsonResponse(route, 200, {});
    }

    if (method === 'DELETE') {
      return jsonResponse(route, 200, { success: true });
    }

    return jsonResponse(route, 200, {
      success: true,
      message: 'ok',
    });
  });

  return {
    failNext(endpoint: RegExp, status: number, message?: string) {
      failures.push({
        endpoint,
        status,
        message:
          message ||
          (status >= 500 ? '服务器内部错误（mock）' : '请求失败（mock）'),
      });
    },
  };
}

export async function ensureAdminLogin(page: Page) {
  await page.goto('/login');

  await page.getByPlaceholder('用户名：admin').fill('admin');
  await page.getByPlaceholder('密码：admin').fill(adminPassword);
  await page.getByRole('button', { name: '登录' }).click();
}

export async function triggerBasicRefresh(page: Page) {
  const labels = ['刷新', '查询', '搜索'];
  for (const label of labels) {
    const button = page.getByRole('button', { name: label }).first();
    if ((await button.count()) > 0) {
      await button.click({ force: true });
      return;
    }
  }

  await page.reload();
}

export async function waitForRecoverableSurface(page: Page) {
  const candidates = [
    '.arco-message-notice-content',
    '.arco-alert-content',
    '.arco-empty-description',
  ];

  const deadline = Date.now() + 1500;
  while (Date.now() < deadline) {
    for (const selector of candidates) {
      const locator = page.locator(selector);
      if ((await locator.count()) > 0 && (await locator.first().isVisible())) {
        return;
      }
    }

    await page.waitForTimeout(100);
  }

  // 没有明显反馈时，至少确保应用根节点仍然可用。
  await page.locator('#app').waitFor({ state: 'visible', timeout: 5000 });
}
