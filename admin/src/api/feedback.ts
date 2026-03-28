import axios from 'axios';
import type { AxiosRequestConfig } from 'axios';

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

type AdminRequestConfig = AxiosRequestConfig & {
  suppressGlobalErrorMessage?: boolean;
};

export function getFeedbackList(
  params?: FeedbackListParams,
  config?: AdminRequestConfig
) {
  return axios.get<FeedbackListResponse>('/api/admin/feedbacks', {
    ...config,
    params,
  });
}
