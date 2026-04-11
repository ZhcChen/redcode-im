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

export interface TestCosDeleteResponse {
  success: boolean;
  message: string;
}

export interface TestCosExistsResponse {
  success: boolean;
  exists?: boolean;
  message: string;
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

export interface TestCosCreateBucketResponse {
  success: boolean;
  message: string;
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

export interface TestCosUploadRequest {
  provider_id?: string;
  key: string;
  content?: string;
  file_base64?: string;
  content_type?: string;
}

export interface TestCosUploadResponse {
  success: boolean;
  url?: string;
  message: string;
}

export interface DirectUploadSignature {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface TestCosUploadSignatureRequest {
  provider_id?: string;
  key: string;
  content_type?: string;
  file_size?: number;
  hash_value?: string;
  hash_alg?: number;
}

export interface TestCosUploadSignatureResponse {
  success: boolean;
  signature?: DirectUploadSignature;
  message: string;
}

export interface TestCosMultipartUploadInitiateRequest {
  provider_id?: string;
  key: string;
  content_type?: string;
  file_size: number;
  hash_value?: string;
  hash_alg?: number;
}

export interface TestCosMultipartUploadInitiateResponse {
  success: boolean;
  message: string;
  key?: string;
  session_id?: string;
  part_size?: number;
  total_parts?: number;
}

export interface TestCosDownloadUrlRequest {
  provider_id?: string;
  key: string;
  expires_in_seconds?: number;
}

export interface TestCosDownloadUrlResponse {
  success: boolean;
  url?: string;
  message: string;
}

export interface SetCosCorsRulePayload {
  allowed_origins: string[];
  allowed_methods: string[];
  allowed_headers?: string[];
  expose_headers?: string[];
  max_age_seconds?: number;
}

export interface SetCosCorsRequest {
  provider_id?: string;
  rules: SetCosCorsRulePayload[];
}

export interface GetCosCorsRequest {
  provider_id?: string;
}

export interface GetCosCorsResponse {
  success: boolean;
  message: string;
  rules: SetCosCorsRulePayload[];
}

export interface SetCosCorsResponse {
  success: boolean;
  message: string;
}

export interface TestCosDeleteRequest {
  provider_id?: string;
  key: string;
}

export interface TestCosExistsRequest {
  provider_id?: string;
  key: string;
}

export interface TestCosListBucketsRequest {
  provider_id?: string;
}

export interface TestCosCreateBucketRequest {
  provider_id?: string;
  bucket_name: string;
}

export interface GetCosDownloadUrlRequest {
  provider_id: string;
  key: string;
  expires_in_seconds?: number;
}

export interface GetCosDownloadUrlResponse {
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

export function testCosUpload(payload: TestCosUploadRequest) {
  return http.post<TestCosUploadResponse>(
    '/api/admin/storage-providers/test/upload',
    payload
  );
}

export function testCosUploadSignature(payload: TestCosUploadSignatureRequest) {
  return http.post<TestCosUploadSignatureResponse>(
    '/api/admin/storage-providers/test/upload/signature',
    payload
  );
}

export function testCosMultipartUploadInitiate(
  payload: TestCosMultipartUploadInitiateRequest
) {
  return http.post<TestCosMultipartUploadInitiateResponse>(
    '/api/admin/storage-providers/test/upload/multipart/initiate',
    payload
  );
}

export function setCosCors(payload: SetCosCorsRequest) {
  return http.post<SetCosCorsResponse>(
    '/api/admin/storage-providers/test/cors',
    payload
  );
}

export function getCosCors(payload: GetCosCorsRequest) {
  return http.post<GetCosCorsResponse>(
    '/api/admin/storage-providers/test/cors/list',
    payload
  );
}

export function testCosDelete(payload: TestCosDeleteRequest) {
  return http.post<TestCosDeleteResponse>(
    '/api/admin/storage-providers/test/delete',
    payload
  );
}

export function testCosExists(payload: TestCosExistsRequest) {
  return http.post<TestCosExistsResponse>(
    '/api/admin/storage-providers/test/exists',
    payload
  );
}

export function testCosDownloadUrl(payload: TestCosDownloadUrlRequest) {
  return http.post<TestCosDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}

export function testCosListBuckets(payload: TestCosListBucketsRequest) {
  return http.post<TestCosListBucketsResponse>(
    '/api/admin/storage-providers/test/buckets',
    payload
  );
}

export function testCosCreateBucket(payload: TestCosCreateBucketRequest) {
  return http.post<TestCosCreateBucketResponse>(
    '/api/admin/storage-providers/test/buckets/create',
    payload
  );
}

export function getCosDownloadUrl(payload: GetCosDownloadUrlRequest) {
  return http.post<GetCosDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}
