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

export function getUserAgreement() {
  return axios.get<DocumentContent>('/api/admin/settings/user-agreement');
}

export function updateUserAgreement(payload: UpdateDocumentPayload) {
  return axios.post<DocumentContent>(
    '/api/admin/settings/user-agreement',
    payload
  );
}

// ========== Push 通知配置（Admin）==========

export interface PushProviderConfigView {
  id: string;
  provider: string;
  platform: string;
  enabled: boolean;
  config_public: Record<string, any>;
  has_secret: boolean;
  secret_fingerprint?: string | null;
  updated_at: string;
  updated_by?: string | null;
}

export interface GetPushSettingsResponse {
  enabled: boolean;
  skip_if_online: boolean;
  providers: PushProviderConfigView[];
}

export interface UpdatePushSettingsPayload {
  enabled: boolean;
  skip_if_online: boolean;
}

export function getPushSettings() {
  return axios.get<GetPushSettingsResponse>('/api/admin/settings/push');
}

export function updatePushSettings(payload: UpdatePushSettingsPayload) {
  return axios.put<GetPushSettingsResponse>(
    '/api/admin/settings/push',
    payload
  );
}

export interface UpsertFcmProviderPayload {
  enabled: boolean;
  service_account_json?: string;
}

export function upsertPushProviderConfig(provider: string, payload: any) {
  return axios.put<PushProviderConfigView>(
    `/api/admin/settings/push/providers/${provider}`,
    payload
  );
}

export interface TestPushPayload {
  provider: string;
  user_id?: string;
  device_token?: string;
  title: string;
  body: string;
}

export interface TestPushResponse {
  success: boolean;
  message: string;
}

export function testPush(payload: TestPushPayload) {
  return axios.post<TestPushResponse>('/api/admin/settings/push/test', payload);
}

export interface PushJobQueueStatsResponse {
  pending: number;
  retry: number;
  done: number;
  failed: number;
  due: number;
  next_run_at?: string | null;
  oldest_created_at?: string | null;
}

export function getPushJobQueueStats() {
  return axios.get<PushJobQueueStatsResponse>(
    '/api/admin/push/job-queue/stats'
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
  data: {
    providers: StorageProvider[];
  };
}

// API 响应包装类型
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

export function testCosUpload(payload: TestCosUploadRequest) {
  return axios.post<TestCosUploadResponse>(
    '/api/admin/storage-providers/test/upload',
    payload
  );
}

export function testCosUploadSignature(payload: TestCosUploadSignatureRequest) {
  return axios.post<TestCosUploadSignatureResponse>(
    '/api/admin/storage-providers/test/upload/signature',
    payload
  );
}

export function testCosMultipartUploadInitiate(
  payload: TestCosMultipartUploadInitiateRequest
) {
  return axios.post<TestCosMultipartUploadInitiateResponse>(
    '/api/admin/storage-providers/test/upload/multipart/initiate',
    payload
  );
}

export function setCosCors(payload: SetCosCorsRequest) {
  return axios.post<SetCosCorsResponse>(
    '/api/admin/storage-providers/test/cors',
    payload
  );
}

export function getCosCors(payload: GetCosCorsRequest) {
  return axios.post<GetCosCorsResponse>(
    '/api/admin/storage-providers/test/cors/list',
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

export function testCosDownloadUrl(payload: TestCosDownloadUrlRequest) {
  return axios.post<TestCosDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
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

// ========== 通用设置 API ==========

export interface GeneralSettingsResponse {
  app_name: string;
}

export interface AppNameResponse {
  app_name: string;
}

export interface UpdateAppNamePayload {
  app_name: string;
}

export function getGeneralSettings() {
  return axios.get<GeneralSettingsResponse>('/settings/general');
}

export function getAppName() {
  return axios.get<AppNameResponse>('/settings/app-name');
}

export function updateAppName(payload: UpdateAppNamePayload) {
  return axios.put<AppNameResponse>('/api/admin/settings/app-name', payload);
}

// ========== 用户账号限制设置 API ==========

export interface UserAccountLimitResponse {
  enable_phone_validation: boolean;
  enable_email_validation: boolean;
  enable_length_validation: boolean;
  min_length: number;
  max_length: number;
  enable_alphanumeric_validation: boolean;
}

export interface UpdateUserAccountLimitPayload {
  enable_phone_validation: boolean;
  enable_email_validation: boolean;
  enable_length_validation: boolean;
  min_length: number;
  max_length: number;
  enable_alphanumeric_validation: boolean;
}

export function getUserAccountLimit() {
  return axios.get<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit'
  );
}

export function updateUserAccountLimit(payload: UpdateUserAccountLimitPayload) {
  return axios.put<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit',
    payload
  );
}

// ========== IP地理位置解析开关 API ==========

export interface IpGeolocationStatusResponse {
  enabled: boolean;
  description: string;
}

export interface SetIpGeolocationEnabledPayload {
  enabled: boolean;
}

export function getIpGeolocationEnabled() {
  return axios.get<IpGeolocationStatusResponse>(
    '/api/admin/ip-geolocation/enabled'
  );
}

export function setIpGeolocationEnabled(
  payload: SetIpGeolocationEnabledPayload
) {
  return axios.patch<IpGeolocationStatusResponse>(
    '/api/admin/ip-geolocation/enabled',
    payload
  );
}

// ========== COS 存储相关 API ==========

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

export function getCosDownloadUrl(payload: GetCosDownloadUrlRequest) {
  return axios.post<GetCosDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}
