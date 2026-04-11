import http from '@/services/http';

export interface FileUploadAuditTaskQueryParams {
  providerId?: string;
  status?: number;
  scene?: string;
  mediaKind?: string;
  keyword?: string;
  startTime?: string;
  endTime?: string;
  limit?: number;
  offset?: number;
}

export interface FileUploadAuditTaskListEntry {
  id: string;
  storageProviderId: string;
  objectKey: string;
  scene: string;
  mediaKind: string;
  contentType?: string;
  fileSize?: number;
  status: number;
  vendorJobId?: string;
  rejectedReason?: string;
  attempts: number;
  nextRunAt: string;
  lastError?: string;
  auditedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface FileUploadAuditTaskListResponse {
  tasks: FileUploadAuditTaskListEntry[];
  total: number;
  limit: number;
  offset: number;
}

export interface FileUploadAuditTaskDetailEntry {
  id: string;
  storageProviderId: string;
  objectKey: string;
  scene: string;
  mediaKind: string;
  contentType?: string;
  fileSize?: number;
  status: number;
  vendorJobId?: string;
  result: any;
  rejectedReason?: string;
  attempts: number;
  nextRunAt: string;
  lastError?: string;
  auditedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface FileUploadAuditTaskDetailResponse {
  task: FileUploadAuditTaskDetailEntry;
}

export interface FileUploadAuditTaskRequeueResponse {
  success: boolean;
  message: string;
}

export function queryFileUploadAuditTasks(
  params: FileUploadAuditTaskQueryParams
) {
  return http.get<FileUploadAuditTaskListResponse>(
    '/api/admin/file-upload-audit/tasks',
    { params }
  );
}

export function getFileUploadAuditTask(taskId: string) {
  return http.get<FileUploadAuditTaskDetailResponse>(
    `/api/admin/file-upload-audit/tasks/${taskId}`
  );
}

export function requeueFileUploadAuditTask(taskId: string) {
  return http.post<FileUploadAuditTaskRequeueResponse>(
    `/api/admin/file-upload-audit/tasks/${taskId}/requeue`
  );
}
