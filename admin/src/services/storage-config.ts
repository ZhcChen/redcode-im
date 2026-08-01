import http from '@/services/http';

export interface ObjectStorageConfigSummary {
  source: string;
  version: number | null;
  provider: string;
  endpoint: string | null;
  region: string;
  privateBucket: string;
  publicBucket: string | null;
  publicBaseUrl: string | null;
  uploadUrlTtlSeconds: number;
  downloadUrlTtlSeconds: number;
  keyIdConfigured: boolean;
  applicationKeyConfigured: boolean;
  lastAppliedBy: string | null;
  lastAppliedAt: string | null;
  rollbackSourceVersion: number | null;
  updatedAt: string | null;
}

export interface ObjectStorageConfigHistoryItem
  extends ObjectStorageConfigSummary {
  status: string;
  changeNote: string | null;
  createdBy: string | null;
  createdAt: string;
  appliedBy: string | null;
  appliedAt: string | null;
}

export interface ObjectStorageProbeAllowedBucket {
  id: string | null;
  name: string | null;
}

export interface ObjectStorageProbeCheck {
  code: string;
  status: 'pass' | 'warn' | 'fail';
  message: string;
}

export interface ObjectStorageProbeResult {
  status: 'pass' | 'warn' | 'fail';
  allowedCapabilities: string[];
  requiredRuntimeCapabilities: string[];
  missingRuntimeCapabilities: string[];
  bucketInitSupported: boolean;
  s3ApiUrl: string | null;
  allowed: {
    buckets: ObjectStorageProbeAllowedBucket[];
    namePrefix: string | null;
  };
  checks: ObjectStorageProbeCheck[];
}

export interface ObjectStorageBucketInitItem {
  bucketName: string;
  bucketRole: string;
  status: 'created' | 'already_exists' | 'skipped' | 'failed';
  message: string;
}

export interface ObjectStorageBucketInitResult {
  status: 'success' | 'partial' | 'failed';
  items: ObjectStorageBucketInitItem[];
}

export interface ObjectStorageConfigInput {
  keyId?: string | null;
  applicationKey?: string | null;
  endpoint?: string | null;
  region?: string | null;
  privateBucket?: string | null;
  publicBucket?: string | null;
  publicBaseUrl?: string | null;
  uploadUrlTtlSeconds?: number | null;
  downloadUrlTtlSeconds?: number | null;
}

type StorageConfigSummaryResponse = {
  source?: string;
  version?: number | null;
  provider?: string;
  endpoint?: string | null;
  region?: string;
  private_bucket?: string;
  public_bucket?: string | null;
  public_base_url?: string | null;
  upload_url_ttl_seconds?: number;
  download_url_ttl_seconds?: number;
  key_id_configured?: boolean;
  application_key_configured?: boolean;
  last_applied_by?: string | null;
  last_applied_at?: string | null;
  rollback_source_version?: number | null;
  updated_at?: string | null;
};

type StorageConfigHistoryResponse = StorageConfigSummaryResponse & {
  status?: string;
  change_note?: string | null;
  created_by?: string | null;
  created_at?: string;
  applied_by?: string | null;
  applied_at?: string | null;
};

type StorageProbeResultResponse = {
  status?: 'pass' | 'warn' | 'fail';
  allowed_capabilities?: string[];
  required_runtime_capabilities?: string[];
  missing_runtime_capabilities?: string[];
  bucket_init_supported?: boolean;
  s3_api_url?: string | null;
  allowed?: {
    buckets?: Array<{ id?: string | null; name?: string | null }>;
    name_prefix?: string | null;
  };
  checks?: Array<{
    code?: string;
    status?: 'pass' | 'warn' | 'fail';
    message?: string;
  }>;
};

type BucketInitResultResponse = {
  status?: 'success' | 'partial' | 'failed';
  items?: Array<{
    bucket_name?: string;
    bucket_role?: string;
    status?: 'created' | 'already_exists' | 'skipped' | 'failed';
    message?: string;
  }>;
};

function mapSummary(
  payload?: StorageConfigSummaryResponse | null
): ObjectStorageConfigSummary | null {
  if (!payload) {
    return null;
  }

  return {
    source: payload.source ?? 'env_fallback',
    version: payload.version ?? null,
    provider: payload.provider ?? 's3_compatible',
    endpoint: payload.endpoint ?? null,
    region: payload.region ?? '',
    privateBucket: payload.private_bucket ?? '',
    publicBucket: payload.public_bucket ?? null,
    publicBaseUrl: payload.public_base_url ?? null,
    uploadUrlTtlSeconds: payload.upload_url_ttl_seconds ?? 0,
    downloadUrlTtlSeconds: payload.download_url_ttl_seconds ?? 0,
    keyIdConfigured: payload.key_id_configured ?? false,
    applicationKeyConfigured: payload.application_key_configured ?? false,
    lastAppliedBy: payload.last_applied_by ?? null,
    lastAppliedAt: payload.last_applied_at ?? null,
    rollbackSourceVersion: payload.rollback_source_version ?? null,
    updatedAt: payload.updated_at ?? null,
  };
}

function mapHistoryItem(
  payload: StorageConfigHistoryResponse
): ObjectStorageConfigHistoryItem {
  const summary = mapSummary(payload);
  return {
    ...(summary ?? {
      source: 'database',
      version: null,
      provider: 's3_compatible',
      endpoint: null,
      region: '',
      privateBucket: '',
      publicBucket: null,
      publicBaseUrl: null,
      uploadUrlTtlSeconds: 0,
      downloadUrlTtlSeconds: 0,
      keyIdConfigured: false,
      applicationKeyConfigured: false,
      lastAppliedBy: null,
      lastAppliedAt: null,
      rollbackSourceVersion: null,
      updatedAt: null,
    }),
    status: payload.status ?? 'active',
    changeNote: payload.change_note ?? null,
    createdBy: payload.created_by ?? null,
    createdAt: payload.created_at ?? '',
    appliedBy: payload.applied_by ?? null,
    appliedAt: payload.applied_at ?? null,
  };
}

function buildConfigPayload(input: ObjectStorageConfigInput) {
  const config: Record<string, unknown> = {};

  if (input.keyId !== undefined) config.key_id = input.keyId ?? null;
  if (input.applicationKey !== undefined) {
    config.application_key = input.applicationKey ?? null;
  }
  if (input.endpoint !== undefined) config.endpoint = input.endpoint ?? null;
  if (input.region !== undefined) config.region = input.region ?? null;
  if (input.privateBucket !== undefined) {
    config.private_bucket = input.privateBucket ?? null;
  }
  if (input.publicBucket !== undefined) {
    config.public_bucket = input.publicBucket ?? null;
  }
  if (input.publicBaseUrl !== undefined) {
    config.public_base_url = input.publicBaseUrl ?? null;
  }
  if (input.uploadUrlTtlSeconds !== undefined) {
    config.upload_url_ttl_seconds = input.uploadUrlTtlSeconds ?? null;
  }
  if (input.downloadUrlTtlSeconds !== undefined) {
    config.download_url_ttl_seconds = input.downloadUrlTtlSeconds ?? null;
  }

  return { config };
}

function mapProbeResult(
  payload?: StorageProbeResultResponse | null
): ObjectStorageProbeResult {
  return {
    status: payload?.status ?? 'fail',
    allowedCapabilities: payload?.allowed_capabilities ?? [],
    requiredRuntimeCapabilities: payload?.required_runtime_capabilities ?? [],
    missingRuntimeCapabilities: payload?.missing_runtime_capabilities ?? [],
    bucketInitSupported: payload?.bucket_init_supported ?? false,
    s3ApiUrl: payload?.s3_api_url ?? null,
    allowed: {
      buckets: (payload?.allowed?.buckets ?? []).map((item) => ({
        id: item.id ?? null,
        name: item.name ?? null,
      })),
      namePrefix: payload?.allowed?.name_prefix ?? null,
    },
    checks: (payload?.checks ?? []).map((item) => ({
      code: item.code ?? '',
      status: item.status ?? 'fail',
      message: item.message ?? '',
    })),
  };
}

function mapBucketInitResult(
  payload?: BucketInitResultResponse | null
): ObjectStorageBucketInitResult {
  return {
    status: payload?.status ?? 'failed',
    items: (payload?.items ?? []).map((item) => ({
      bucketName: item.bucket_name ?? '',
      bucketRole: item.bucket_role ?? '',
      status: item.status ?? 'failed',
      message: item.message ?? '',
    })),
  };
}

export async function fetchObjectStorageConfig() {
  const response = await http.get<{
    current?: StorageConfigSummaryResponse | null;
  }>('/api/admin/system/storage-config');
  return mapSummary(response.data?.current);
}

export async function fetchObjectStorageConfigHistory() {
  const response = await http.get<{ list?: StorageConfigHistoryResponse[] }>(
    '/api/admin/system/storage-config/history'
  );
  return (response.data?.list ?? []).map(mapHistoryItem);
}

export async function validateObjectStorageConfig(
  input: ObjectStorageConfigInput
) {
  const response = await http.post<{
    valid?: boolean;
    normalized?: StorageConfigSummaryResponse | null;
  }>('/api/admin/system/storage-config/validate', buildConfigPayload(input));

  return {
    valid: response.data?.valid ?? false,
    normalized: mapSummary(response.data?.normalized ?? null),
  };
}

export async function probeObjectStorageConfig(
  input: ObjectStorageConfigInput
) {
  const response = await http.post<{
    normalized?: StorageConfigSummaryResponse | null;
    probe?: StorageProbeResultResponse | null;
  }>('/api/admin/system/storage-config/probe', buildConfigPayload(input));

  return {
    normalized: mapSummary(response.data?.normalized ?? null),
    probe: mapProbeResult(response.data?.probe ?? null),
  };
}

export async function applyObjectStorageConfig(
  input: ObjectStorageConfigInput,
  changeNote?: string | null
) {
  const response = await http.post<{
    current?: StorageConfigSummaryResponse | null;
    version?: number | null;
    applied_at?: string | null;
  }>('/api/admin/system/storage-config/apply', {
    ...buildConfigPayload(input),
    change_note: changeNote ?? null,
  });

  return {
    current: mapSummary(response.data?.current ?? null),
    version: response.data?.version ?? null,
    appliedAt: response.data?.applied_at ?? null,
  };
}

export async function initObjectStorageBuckets() {
  const response = await http.post<{
    current?: StorageConfigSummaryResponse | null;
    result?: BucketInitResultResponse | null;
  }>('/api/admin/system/storage-config/init-bucket');

  return {
    current: mapSummary(response.data?.current ?? null),
    result: mapBucketInitResult(response.data?.result ?? null),
  };
}

export async function rollbackObjectStorageConfig(
  targetVersion: number,
  reason?: string | null
) {
  const response = await http.post<{
    current?: StorageConfigSummaryResponse | null;
    version?: number | null;
    rolled_back_from_version?: number | null;
    applied_at?: string | null;
  }>('/api/admin/system/storage-config/rollback', {
    target_version: targetVersion,
    reason: reason ?? null,
  });

  return {
    current: mapSummary(response.data?.current ?? null),
    version: response.data?.version ?? null,
    rolledBackFromVersion: response.data?.rolled_back_from_version ?? null,
    appliedAt: response.data?.applied_at ?? null,
  };
}
