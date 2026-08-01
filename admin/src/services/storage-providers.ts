import http from '@/services/http';

export interface StorageProvider {
  id: string;
  provider_type: string;
  name: string;
  secret_id: string;
  secret_key: string;
  secret_id_configured?: boolean;
  secret_key_configured?: boolean;
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
  data: {
    providers: StorageProvider[];
  };
}

export interface ApiResponse<T> {
  data: T;
  success?: boolean;
  message?: string;
}

export interface CreateStorageProviderPayload {
  provider_type: 's3_compatible';
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
  provider_type?: 's3_compatible';
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

export interface DirectUploadSignature {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface TestStorageUploadRequest {
  provider_id?: string;
  key: string;
  content?: string;
  file_base64?: string;
  content_type?: string;
}

export interface TestStorageUploadResponse {
  success: boolean;
  url?: string;
  message: string;
}

export interface TestStorageUploadSignatureRequest {
  provider_id?: string;
  key: string;
  content_type?: string;
  file_size?: number;
  hash_value?: string;
  hash_alg?: number;
}

export interface TestStorageUploadSignatureResponse {
  success: boolean;
  signature?: DirectUploadSignature;
  message: string;
}

export interface TestStorageMultipartUploadInitiateRequest {
  provider_id?: string;
  key: string;
  content_type?: string;
  file_size: number;
  hash_value?: string;
  hash_alg?: number;
}

export interface TestStorageMultipartUploadInitiateResponse {
  success: boolean;
  message: string;
  key?: string;
  session_id?: string;
  part_size?: number;
  total_parts?: number;
}

export interface TestStorageDownloadUrlRequest {
  provider_id?: string;
  key: string;
  expires_in_seconds?: number;
}

export interface TestStorageDownloadUrlResponse {
  success: boolean;
  url?: string | null;
  message: string;
}

export interface TestStorageDeleteRequest {
  provider_id?: string;
  key: string;
}

export interface TestStorageDeleteResponse {
  success: boolean;
  message: string;
}

export interface TestStorageExistsRequest {
  provider_id?: string;
  key: string;
}

export interface TestStorageExistsResponse {
  success: boolean;
  exists?: boolean;
  message: string;
}

export interface TestStorageListBucketsRequest {
  provider_id?: string;
}

export interface TestStorageListBucketsResponse {
  success: boolean;
  buckets: Array<{
    name: string;
    region: string;
    creation_date?: string | null;
  }>;
  message: string;
}

export interface TestStorageCreateBucketRequest {
  provider_id?: string;
  bucket_name: string;
}

export interface TestStorageCreateBucketResponse {
  success: boolean;
  message: string;
}

export interface GetStorageDownloadUrlRequest {
  provider_id: string;
  key: string;
  expires_in_seconds?: number;
}

export interface GetStorageDownloadUrlResponse {
  success: boolean;
  url: string | null;
  message: string;
}

export function listStorageProviders() {
  return http.get<StorageProviderListResponse>('/api/admin/storage-providers');
}

export function createStorageProvider(payload: CreateStorageProviderPayload) {
  return http.post<StorageProvider>('/api/admin/storage-providers', payload);
}

export function updateStorageProvider(
  providerId: string,
  payload: UpdateStorageProviderPayload
) {
  return http.patch<StorageProvider>(
    `/api/admin/storage-providers/${providerId}`,
    payload
  );
}

export function deleteStorageProvider(providerId: string) {
  return http.delete(`/api/admin/storage-providers/${providerId}`);
}

export function getDefaultStorageProvider() {
  return http.get<StorageProvider>('/api/admin/storage-providers/default');
}

export function testStorageUpload(payload: TestStorageUploadRequest) {
  return http.post<TestStorageUploadResponse>(
    '/api/admin/storage-providers/test/upload',
    payload
  );
}

export function testStorageUploadSignature(
  payload: TestStorageUploadSignatureRequest
) {
  return http.post<TestStorageUploadSignatureResponse>(
    '/api/admin/storage-providers/test/upload/signature',
    payload
  );
}

export function testStorageMultipartUploadInitiate(
  payload: TestStorageMultipartUploadInitiateRequest
) {
  return http.post<TestStorageMultipartUploadInitiateResponse>(
    '/api/admin/storage-providers/test/upload/multipart/initiate',
    payload
  );
}

export function testStorageDelete(payload: TestStorageDeleteRequest) {
  return http.post<TestStorageDeleteResponse>(
    '/api/admin/storage-providers/test/delete',
    payload
  );
}

export function testStorageExists(payload: TestStorageExistsRequest) {
  return http.post<TestStorageExistsResponse>(
    '/api/admin/storage-providers/test/exists',
    payload
  );
}

export function testStorageDownloadUrl(payload: TestStorageDownloadUrlRequest) {
  return http.post<TestStorageDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}

export function testStorageListBuckets(payload: TestStorageListBucketsRequest) {
  return http.post<TestStorageListBucketsResponse>(
    '/api/admin/storage-providers/test/buckets',
    payload
  );
}

export function testStorageCreateBucket(
  payload: TestStorageCreateBucketRequest
) {
  return http.post<TestStorageCreateBucketResponse>(
    '/api/admin/storage-providers/test/buckets/create',
    payload
  );
}

export function getStorageDownloadUrl(payload: GetStorageDownloadUrlRequest) {
  return http.post<GetStorageDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}
