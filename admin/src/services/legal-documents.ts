import http from '@/services/http';

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
  return http.get<DocumentContent>('/api/admin/settings/privacy-policy');
}

export function updatePrivacyPolicy(payload: UpdateDocumentPayload) {
  return http.post<DocumentContent>(
    '/api/admin/settings/privacy-policy',
    payload
  );
}

export function getUserAgreement() {
  return http.get<DocumentContent>('/api/admin/settings/user-agreement');
}

export function updateUserAgreement(payload: UpdateDocumentPayload) {
  return http.post<DocumentContent>(
    '/api/admin/settings/user-agreement',
    payload
  );
}
