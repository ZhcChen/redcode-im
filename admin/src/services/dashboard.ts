import http from '@/services/http';

export interface SystemStats {
  totalUsers: number;
  onlineUsers: number;
  totalRooms: number;
  activeRooms: number;
  totalMessages: number;
  todayMessages: number;
  systemLoad: number;
  memoryUsage: number;
  storageUsage: number;
}

export function getSystemStats() {
  return http.get<SystemStats>('/api/dashboard/stats');
}

export interface SystemMonitor {
  cpu: number;
  memory: number;
  disk: number;
  network_in: number;
  network_out: number;
  connections: number;
}

export function getSystemMonitor() {
  return http.get<SystemMonitor>('/api/dashboard/monitor');
}

export interface NodeMonitor {
  nodeId: string;
  address: string;
  connectedUsers: number;
  activeRooms: number;
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  cpuCount: number;
  totalMemory: number;
  lastHeartbeat: string;
  startedAt: string;
}

export function getNodesMonitor() {
  return http.get<NodeMonitor[]>('/api/admin/nodes/monitor');
}

export interface ApiPerformanceMetric {
  method: string;
  path: string;
  count: number;
  avg_duration: number;
  max_duration: number;
}

export interface ApiPerformanceResponse {
  metrics: ApiPerformanceMetric[];
  top_avg: ApiPerformanceMetric[];
  top_count: ApiPerformanceMetric[];
  total: number;
  page: number;
  page_size: number;
}

export function getApiPerformanceMetrics(params: {
  page?: number;
  page_size?: number;
  sort_field?: string;
  sort_order?: string;
}) {
  return http.get<ApiPerformanceResponse>('/api/admin/metrics/performance', {
    params,
  });
}

export interface DailyStat {
  date: string;
  count: number;
}

export interface StorageTypeStat {
  file_type: string;
  count: number;
  size_bytes: number;
  percentage: number;
}

export interface DataStatistics {
  daily_active_users: DailyStat[];
  daily_messages: DailyStat[];
  storage_usage_by_type: StorageTypeStat[];
  user_growth_rate: number;
  message_growth_rate: number;
  peak_active_time: string;
}

export function getDataStatistics() {
  return http.get<DataStatistics>('/api/dashboard/statistics');
}

export interface DashboardStorageStats {
  totalFiles: number;
  totalSize: number;
  todayUploads: number;
}

export function getDashboardStorageStats() {
  return http.get<DashboardStorageStats>('/api/dashboard/storage-stats');
}

export interface DashboardEmojiStats {
  totalEmojis: number;
  todayUsage: number;
  popularCount: number;
}

export function getDashboardEmojiStats() {
  return http.get<DashboardEmojiStats>('/api/dashboard/emoji-stats');
}

export interface PopularContentItem {
  id: string;
  title: string;
  clickNumber: string;
  increases: number;
}

export interface PopularContentData {
  text: PopularContentItem[];
  image: PopularContentItem[];
  video: PopularContentItem[];
}

// 获取热门内容数据（暂时使用模拟数据，后续可扩展为真实API）
export function getPopularContent(): Promise<{ data: PopularContentData }> {
  // 暂时返回模拟数据，未来可以根据后端API扩展
  const data: PopularContentData = {
    text: [
      {
        id: '1',
        title: '系统消息统计',
        clickNumber: '1.2k',
        increases: 15,
      },
      {
        id: '2',
        title: '用户活跃分析',
        clickNumber: '980',
        increases: 8,
      },
      {
        id: '3',
        title: '聊天室使用报告',
        clickNumber: '756',
        increases: 22,
      },
      {
        id: '4',
        title: '文件上传统计',
        clickNumber: '543',
        increases: 12,
      },
      {
        id: '5',
        title: '系统性能监控',
        clickNumber: '432',
        increases: 5,
      },
    ],
    image: [
      {
        id: '1',
        title: '用户头像统计',
        clickNumber: '890',
        increases: 18,
      },
      {
        id: '2',
        title: '聊天图片分析',
        clickNumber: '654',
        increases: 25,
      },
      {
        id: '3',
        title: '贴纸使用情况',
        clickNumber: '521',
        increases: 7,
      },
    ],
    video: [
      {
        id: '1',
        title: '视频消息统计',
        clickNumber: '345',
        increases: 30,
      },
      {
        id: '2',
        title: '语音消息分析',
        clickNumber: '234',
        increases: 15,
      },
      {
        id: '3',
        title: '多媒体内容报告',
        clickNumber: '198',
        increases: 10,
      },
    ],
  };
  return Promise.resolve({ data });
}
