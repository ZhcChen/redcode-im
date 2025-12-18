import axios from 'axios';

export interface ReportAttachmentItem {
  key: string;
  downloadUrl?: string | null;
}

export interface ReportItem {
  id: string;
  reporterId: string;
  reporterUsername: string;
  reporterNickname?: string | null;
  targetType: string;
  targetId: string;
  targetName?: string | null;
  content: string;
  createdAt: string;
  attachments: ReportAttachmentItem[];
}

export interface ReportListParams {
  page?: number;
  pageSize?: number;
  reporterId?: string;
  targetType?: 'room' | 'user';
  targetId?: string;
  keyword?: string;
}

export interface ReportListResponse {
  reports: ReportItem[];
  total: number;
  page: number;
  pageSize: number;
}

export function getReportList(params?: ReportListParams) {
  return axios.get<ReportListResponse>('/api/admin/reports', { params });
}
