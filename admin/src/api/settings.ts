import axios from 'axios';

export interface DocumentContent {
  key: string;
  title: string;
  content: string;
  updated_at: string;
  updated_by?: string | null;
}

export interface UpdateDocumentPayload {
  title?: string;
  content: string;
}

export function getPrivacyPolicy() {
  return axios.get<DocumentContent>('/api/admin/settings/privacy-policy');
}

export function updatePrivacyPolicy(payload: UpdateDocumentPayload) {
  return axios.post<DocumentContent>('/api/admin/settings/privacy-policy', payload);
}
