import axios from 'axios';

export interface PushLogEntry {
  id: string;
  pushId: string;
  userId: string;
  username?: string;
  nickname?: string;
  deviceId: string;
  platform: string;
  channel: string;
  provider: string;
  eventType: string;
  roomId?: string;
  messageId?: string;
  requestId?: string;
  title?: string;
  body?: string;
  data: any;
  attempt: number;
  success: boolean;
  error?: string;
  createdAt: string;
}

export interface PushLogQueryParams {
  pushId?: string;
  userId?: string;
  deviceId?: string;
  platform?: string;
  channel?: string;
  provider?: string;
  eventType?: string;
  roomId?: string;
  messageId?: string;
  requestId?: string;
  keyword?: string;
  startTime?: string;
  endTime?: string;
  limit?: number;
  offset?: number;
  success?: boolean;
}

export interface PushLogsResponse {
  logs: PushLogEntry[];
  total: number;
  limit: number;
  offset: number;
}

export interface PushLogCleanupRequest {
  retentionDays: number;
}

export interface PushLogCleanupResponse {
  success: boolean;
  deletedCount: number;
  message: string;
}

export function queryPushLogs(params: PushLogQueryParams) {
  return axios.get<PushLogsResponse>('/api/admin/push/logs', { params });
}

export function cleanupPushLogs(data: PushLogCleanupRequest) {
  return axios.post<PushLogCleanupResponse>(
    '/api/admin/push/logs/cleanup',
    data
  );
}
