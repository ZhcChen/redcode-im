import type { AdminRouteProfile } from './test-context';

export type InteractionKind =
  | 'noop'
  | 'search'
  | 'refresh'
  | 'save'
  | 'bucket-list'
  | 'reset'
  | 'switch-tab';

export interface AdminRouteCase {
  id: string;
  path: string;
  anchorText: string;
  primaryEndpoint: RegExp;
  interaction: InteractionKind;
  profiles: AdminRouteProfile[];
}

const bothProfiles: AdminRouteProfile[] = ['default', 'data-cleanup'];

const ROUTE_CASES: AdminRouteCase[] = [
  {
    id: 'dashboard-workplace',
    path: '/dashboard/workplace',
    anchorText: '全球用户分布',
    primaryEndpoint: /\/api\/admin\/users\/geolocation\/distribution$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'dashboard-monitor',
    path: '/dashboard/monitor',
    anchorText: '集群节点实时监控',
    primaryEndpoint: /\/api\/admin\/nodes\/monitor$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'operations-system-log',
    path: '/operations/system-log',
    anchorText: '系统日志',
    primaryEndpoint: /\/api\/admin\/logs$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'operations-push-log',
    path: '/operations/push-log',
    anchorText: 'Push 日志',
    primaryEndpoint: /\/api\/admin\/push\/logs$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'operations-storage-provider',
    path: '/operations/storage-provider',
    anchorText: '对象存储配置',
    primaryEndpoint: /\/api\/admin\/storage-providers$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'operations-cos-test',
    path: '/operations/cos-test',
    anchorText: '腾讯云 COS 测试',
    primaryEndpoint: /\/api\/admin\/storage-providers\/test\/buckets$/,
    interaction: 'bucket-list',
    profiles: bothProfiles,
  },
  {
    id: 'operations-ipinfo-token',
    path: '/operations/ipinfo-token',
    anchorText: 'ipinfo.io Token 管理',
    primaryEndpoint: /\/api\/admin\/ipinfo-tokens$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'operations-api-metrics',
    path: '/operations/api-metrics',
    anchorText: 'API 性能监控',
    primaryEndpoint: /\/api\/admin\/metrics\/performance$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'operations-file-upload-audit',
    path: '/operations/file-upload-audit',
    anchorText: '文件内容审核',
    primaryEndpoint: /\/api\/admin\/file-upload-audit\/tasks$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'operations-data-cleanup',
    path: '/operations/data-cleanup',
    anchorText: '数据清理',
    primaryEndpoint: /\/admin\/data\/cleanup\/all$/,
    interaction: 'reset',
    profiles: ['data-cleanup'],
  },
  {
    id: 'settings-captcha',
    path: '/settings/captcha',
    anchorText: '验证码设置',
    primaryEndpoint: /\/api\/admin\/settings\/captcha$/,
    interaction: 'save',
    profiles: bothProfiles,
  },
  {
    id: 'settings-privacy-policy',
    path: '/settings/privacy-policy',
    anchorText: '隐私协议',
    primaryEndpoint: /\/api\/admin\/settings\/privacy-policy$/,
    interaction: 'save',
    profiles: bothProfiles,
  },
  {
    id: 'settings-user-agreement',
    path: '/settings/user-agreement',
    anchorText: '用户协议',
    primaryEndpoint: /\/api\/admin\/settings\/user-agreement$/,
    interaction: 'save',
    profiles: bothProfiles,
  },
  {
    id: 'settings-general',
    path: '/settings/general',
    anchorText: '通用设置',
    primaryEndpoint: /\/settings\/app-name$/,
    interaction: 'save',
    profiles: bothProfiles,
  },
  {
    id: 'settings-push',
    path: '/settings/push',
    anchorText: 'Push 通知',
    primaryEndpoint: /\/api\/admin\/settings\/push$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'settings-emoji-pack',
    path: '/settings/emoji-pack',
    anchorText: '贴纸设置',
    primaryEndpoint: /\/api\/admin\/emoji-packs$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'settings-user-profile',
    path: '/settings/user-profile',
    anchorText: '个人设置',
    primaryEndpoint: /\/auth\/admin\/me$/,
    interaction: 'save',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-list',
    path: '/user-management/list',
    anchorText: '用户管理',
    primaryEndpoint: /\/api\/admin\/users$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-feedback',
    path: '/user-management/feedback',
    anchorText: '用户反馈',
    primaryEndpoint: /\/api\/admin\/feedbacks$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-reports',
    path: '/user-management/reports',
    anchorText: '举报记录',
    primaryEndpoint: /\/api\/admin\/reports$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-chat-history',
    path: '/user-management/chat-history',
    anchorText: '用户聊天记录',
    primaryEndpoint: /\/api\/admin\/chat-history$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-room-history',
    path: '/user-management/chat-history/room/room-e2e',
    anchorText: '房间聊天记录',
    primaryEndpoint: /\/api\/admin\/rooms\/room-e2e\/chat-history$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
  {
    id: 'user-management-user-history',
    path: '/user-management/chat-history/user/user-e2e',
    anchorText: '用户聊天记录',
    primaryEndpoint: /\/api\/admin\/users\/user-e2e\/rooms$/,
    interaction: 'switch-tab',
    profiles: bothProfiles,
  },
  {
    id: 'versions-frontend',
    path: '/versions/frontend',
    anchorText: 'App客户端版本管理',
    primaryEndpoint: /\/api\/admin\/app-versions$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'versions-desktop',
    path: '/versions/desktop',
    anchorText: '桌面客户端版本管理',
    primaryEndpoint: /\/api\/admin\/app-versions$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'versions-hot-updates',
    path: '/versions/hot-updates',
    anchorText: '热更新管理',
    primaryEndpoint: /\/api\/admin\/hot-updates$/,
    interaction: 'refresh',
    profiles: bothProfiles,
  },
  {
    id: 'versions-hot-update-events',
    path: '/versions/hot-update-events',
    anchorText: '热更新上报',
    primaryEndpoint: /\/api\/admin\/hot-updates\/events$/,
    interaction: 'search',
    profiles: bothProfiles,
  },
];

export function getRouteCases(profile: AdminRouteProfile): AdminRouteCase[] {
  return ROUTE_CASES.filter((item) => item.profiles.includes(profile));
}

export function getRouteCaseById(id: string): AdminRouteCase | undefined {
  return ROUTE_CASES.find((item) => item.id === id);
}

export function getAllRouteCases(): AdminRouteCase[] {
  return [...ROUTE_CASES];
}
