import axios from 'axios';

import type { LoginRes } from '@/api/user';

export interface AdminBootstrapStatusResponse {
  bootstrap_required: boolean;
}

export interface AdminBootstrapInitData {
  username: string;
  password: string;
  display_name?: string;
}

export function getAdminBootstrapStatus() {
  return axios.get<AdminBootstrapStatusResponse>('/api/admin/bootstrap/status');
}

export function bootstrapAdmin(data: AdminBootstrapInitData) {
  return axios.post<LoginRes>('/api/admin/bootstrap/init', data);
}
