import http from '@/services/http';

export interface MultipartSessionInfo {
  session_id: string;
  object_key: string;
  part_size: number;
  total_parts: number;
  status: number;
  uploaded_parts: Record<string, string>;
}

export interface MultipartSessionResponse {
  success: boolean;
  message: string;
  session?: MultipartSessionInfo;
}

export interface DirectUploadSignature {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface MultipartPartSignatureResponse {
  success: boolean;
  message: string;
  signature?: DirectUploadSignature;
}

export interface MultipartPartCommitResponse {
  success: boolean;
  message: string;
}

export interface MultipartCompleteResponse {
  success: boolean;
  message: string;
}

export interface MultipartAbortResponse {
  success: boolean;
  message: string;
}

export interface MultipartCompletedPart {
  part_number: number;
  etag: string;
}

export function getAdminMultipartSession(sessionId: string) {
  return http.get<MultipartSessionResponse>(
    `/api/admin/uploads/multipart/sessions/${sessionId}`
  );
}

export function generateAdminMultipartPartSignature(
  sessionId: string,
  partNumber: number
) {
  return http.post<MultipartPartSignatureResponse>(
    `/api/admin/uploads/multipart/sessions/${sessionId}/parts/signature`,
    { part_number: partNumber }
  );
}

export function commitAdminMultipartPart(
  sessionId: string,
  partNumber: number,
  etag: string
) {
  return http.post<MultipartPartCommitResponse>(
    `/api/admin/uploads/multipart/sessions/${sessionId}/parts/commit`,
    { part_number: partNumber, etag }
  );
}

export function completeAdminMultipartUpload(
  sessionId: string,
  parts: MultipartCompletedPart[]
) {
  return http.post<MultipartCompleteResponse>(
    `/api/admin/uploads/multipart/sessions/${sessionId}/complete`,
    { parts }
  );
}

export function abortAdminMultipartUpload(sessionId: string) {
  return http.post<MultipartAbortResponse>(
    `/api/admin/uploads/multipart/sessions/${sessionId}/abort`
  );
}
