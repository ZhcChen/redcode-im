export function getProviderTypeLabel(type: string) {
  const labels: Record<string, string> = {
    backblaze_b2: 'Backblaze B2',
    tencent_cos: '腾讯云COS',
    aliyun_oss: '阿里云OSS',
    aws_s3: 'AWS S3',
    minio: 'MinIO',
    unknown: '未知',
  };

  return labels[type] || type;
}

export function getProviderTypeColor(type: string) {
  const colors: Record<string, string> = {
    backblaze_b2: 'arcoblue',
    tencent_cos: 'blue',
    aliyun_oss: 'orange',
    aws_s3: 'purple',
    minio: 'cyan',
    unknown: 'gray',
  };

  return colors[type] || 'gray';
}

export function splitMultiValueInput(input: string, toUpper = false) {
  return input
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .map((item) => (toUpper ? item.toUpperCase() : item));
}

export function resolveDefaultCorsOrigin() {
  if (typeof window !== 'undefined') {
    return window.location.origin;
  }

  return 'http://localhost:8011';
}
