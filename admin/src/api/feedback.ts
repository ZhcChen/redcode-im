import axios from 'axios';

export interface FeedbackItem {
  id: string;
  userId: string;
  username?: string | null;
  nickname?: string | null;
  contact?: string | null;
  content: string;
  createdAt: string;
}

export interface FeedbackListParams {
  page?: number;
  pageSize?: number;
  userId?: string;
  keyword?: string;
}

export interface FeedbackListResponse {
  feedbacks: FeedbackItem[];
  total: number;
  page: number;
  pageSize: number;
}

export function getFeedbackList(params?: FeedbackListParams) {
  return axios.get<FeedbackListResponse>('/api/admin/feedbacks', { params });
}
