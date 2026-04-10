import http from '@/services/http';

export interface SystemLogEntry {
  id: string;
  level: string;
  target: string;
  message: string;
  fields?: any;
  spanId?: string;
  nodeId: string;
  createdAt: string;
}

export interface SystemLogQueryParams {
  level?: string;
  target?: string;
  keyword?: string;
  startTime?: string;
  endTime?: string;
  limit?: number;
  offset?: number;
}

export interface SystemLogsResponse {
  logs: SystemLogEntry[];
  total: number;
  limit: number;
  offset: number;
}

export interface SystemLogStatsResponse {
  totalCount: number;
  debugCount: number;
  infoCount: number;
  warnCount: number;
  errorCount: number;
  oldestLog?: string;
  newestLog?: string;
}

export interface LogCleanupRequest {
  retentionDays: number;
}

export interface LogCleanupResponse {
  success: boolean;
  deletedCount: number;
  message: string;
}

export function querySystemLogs(params: SystemLogQueryParams) {
  return http.get<SystemLogsResponse>('/api/admin/logs', { params });
}

export function getSystemLogStats() {
  return http.get<SystemLogStatsResponse>('/api/admin/logs/stats');
}

export function cleanupSystemLogs(data: LogCleanupRequest) {
  return http.post<LogCleanupResponse>('/api/admin/logs/cleanup', data);
}
