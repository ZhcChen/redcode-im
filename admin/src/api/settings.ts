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
  return axios.post<DocumentContent>(
    '/api/admin/settings/privacy-policy',
    payload
  );
}

// ========== 文件上传提供商管理 API ==========

export interface StorageProvider {
  id: string;
  provider_type: string;
  name: string;
  secret_id: string;
  secret_key: string;
  region: string;
  endpoint: string;
  bucket_name?: string | null;
  is_active: boolean;
  is_default: boolean;
  description?: string | null;
  created_at: string;
  updated_at: string;
  updated_by?: string | null;
}

export interface StorageProviderListResponse {
  providers: StorageProvider[];
}

export interface CreateStorageProviderPayload {
  provider_type: string;
  name: string;
  secret_id: string;
  secret_key: string;
  region: string;
  endpoint: string;
  bucket_name?: string;
  is_active?: boolean;
  is_default?: boolean;
  description?: string;
}

export interface UpdateStorageProviderPayload {
  provider_type?: string;
  name?: string;
  secret_id?: string;
  secret_key?: string;
  region?: string;
  endpoint?: string;
  bucket_name?: string | null;
  is_active?: boolean;
  is_default?: boolean;
  description?: string | null;
}

export function listStorageProviders() {
  return axios.get<StorageProviderListResponse>('/api/admin/storage-providers');
}

export function createStorageProvider(payload: CreateStorageProviderPayload) {
  return axios.post<StorageProvider>('/api/admin/storage-providers', payload);
}

export function updateStorageProvider(
  providerId: string,
  payload: UpdateStorageProviderPayload
) {
  return axios.patch<StorageProvider>(
    `/api/admin/storage-providers/${providerId}`,
    payload
  );
}

export function deleteStorageProvider(providerId: string) {
  return axios.delete(`/api/admin/storage-providers/${providerId}`);
}

export function getDefaultStorageProvider() {
  return axios.get<StorageProvider>('/api/admin/storage-providers/default');
}

// ========== COS 测试 API ==========

export interface TestCosUploadRequest {
  provider_id?: string;
  key: string;
  content: string;
  content_type?: string;
}

export interface TestCosUploadResponse {
  success: boolean;
  url?: string;
  message: string;
}

export interface TestCosDeleteRequest {
  provider_id?: string;
  key: string;
}

export interface TestCosDeleteResponse {
  success: boolean;
  message: string;
}

export interface TestCosExistsRequest {
  provider_id?: string;
  key: string;
}

export interface TestCosExistsResponse {
  success: boolean;
  exists: boolean;
  message: string;
}

export function testCosUpload(payload: TestCosUploadRequest) {
  return axios.post<TestCosUploadResponse>(
    '/api/admin/storage-providers/test/upload',
    payload
  );
}

export function testCosDelete(payload: TestCosDeleteRequest) {
  return axios.post<TestCosDeleteResponse>(
    '/api/admin/storage-providers/test/delete',
    payload
  );
}

export function testCosExists(payload: TestCosExistsRequest) {
  return axios.post<TestCosExistsResponse>(
    '/api/admin/storage-providers/test/exists',
    payload
  );
}

export interface TestCosListBucketsRequest {
  provider_id?: string;
}

export interface TestCosListBucketsResponse {
  success: boolean;
  buckets: Array<{
    name: string;
    region: string;
    creation_date?: string | null;
  }>;
  message: string;
}

export interface TestCosCreateBucketRequest {
  provider_id?: string;
  bucket_name: string;
}

export interface TestCosCreateBucketResponse {
  success: boolean;
  message: string;
}

export function testCosListBuckets(payload: TestCosListBucketsRequest) {
  return axios.post<TestCosListBucketsResponse>(
    '/api/admin/storage-providers/test/buckets',
    payload
  );
}

export function testCosCreateBucket(payload: TestCosCreateBucketRequest) {
  return axios.post<TestCosCreateBucketResponse>(
    '/api/admin/storage-providers/test/buckets/create',
    payload
  );
}
