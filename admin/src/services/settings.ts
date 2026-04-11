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
  return http.get<GetPushSettingsResponse>('/api/admin/settings/push');
}

export function updatePushSettings(payload: UpdatePushSettingsPayload) {
  return http.put<GetPushSettingsResponse>('/api/admin/settings/push', payload);
}

export interface UpsertFcmProviderPayload {
  enabled: boolean;
  service_account_json?: string;
}

export function upsertPushProviderConfig(provider: string, payload: any) {
  return http.put<PushProviderConfigView>(
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
  return http.post<TestPushResponse>('/api/admin/settings/push/test', payload);
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
  return http.get<PushJobQueueStatsResponse>('/api/admin/push/job-queue/stats');
}

// ========== 文件上传提供商管理 API ==========

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

// ========== 通用设置 API ==========

export interface MessageRuntimeSettingsResponse {
  server_storage_mode: 'persist' | 'relay_only';
  content_audit_mode: 'plaintext' | 'e2ee';
  updated_at?: string | null;
  updated_by?: string | null;
}

export interface UpdateMessageRuntimeSettingsPayload {
  server_storage_mode: 'persist' | 'relay_only';
  content_audit_mode: 'plaintext' | 'e2ee';
}

export interface GeneralSettingsResponse {
  app_name: string;
  message_runtime?: MessageRuntimeSettingsResponse;
}

export interface AppNameResponse {
  app_name: string;
}

export interface UpdateAppNamePayload {
  app_name: string;
}

export function getGeneralSettings() {
  return http.get<GeneralSettingsResponse>('/settings/general');
}

export function getAppName() {
  return http.get<AppNameResponse>('/settings/app-name');
}

export function updateAppName(payload: UpdateAppNamePayload) {
  return http.put<AppNameResponse>('/api/admin/settings/app-name', payload);
}

export function getMessageRuntimeSettings() {
  return http.get<MessageRuntimeSettingsResponse>(
    '/api/admin/settings/message-runtime'
  );
}

export function updateMessageRuntimeSettings(
  payload: UpdateMessageRuntimeSettingsPayload
) {
  return http.put<MessageRuntimeSettingsResponse>(
    '/api/admin/settings/message-runtime',
    payload
  );
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
  return http.get<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit'
  );
}

export function updateUserAccountLimit(payload: UpdateUserAccountLimitPayload) {
  return http.put<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit',
    payload
  );
}

// ========== 上传策略（Upload Policy）==========

export interface UploadPolicyMaxSizeMbByPartType {
  image: number;
  video: number;
  audio: number;
  file: number;
}

export interface UploadPolicyMimeByPartType {
  image: string[];
  video: string[];
  audio: string[];
  file: string[];
}

export interface AudioOnlyPolicy {
  enabled: boolean;
  force_single_attachment: boolean;
  allow_text: boolean;
}

export interface UploadPolicyView {
  version: string;
  max_total_size_mb: number;
  max_attachments_per_message: number;
  max_size_mb_by_part_type: UploadPolicyMaxSizeMbByPartType;
  mime_by_part_type: UploadPolicyMimeByPartType;
  mime_whitelist: string[];
  audio_only: AudioOnlyPolicy;
}

export interface UploadPolicyAdminResponse {
  policy: UploadPolicyView;
  updated_at?: string | null;
  updated_by?: string | null;
}

export type UpdateUploadPolicyPayload = Omit<
  UploadPolicyView,
  'mime_whitelist'
>;

export function getUploadPolicy() {
  return http.get<UploadPolicyAdminResponse>(
    '/api/admin/settings/upload-policy'
  );
}

export function updateUploadPolicy(payload: UpdateUploadPolicyPayload) {
  return http.put<UploadPolicyAdminResponse>(
    '/api/admin/settings/upload-policy',
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
  return http.get<IpGeolocationStatusResponse>(
    '/api/admin/ip-geolocation/enabled'
  );
}

export function setIpGeolocationEnabled(
  payload: SetIpGeolocationEnabledPayload
) {
  return http.patch<IpGeolocationStatusResponse>(
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
  return http.post<GetCosDownloadUrlResponse>(
    '/api/admin/storage-providers/test/download-url',
    payload
  );
}
