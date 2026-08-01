export function getProviderTypeLabel(type: string) {
  const labels: Record<string, string> = {
    s3_compatible: 'S3 兼容对象存储',
    unknown: '未知',
  };

  return labels[type] || type;
}

export function getProviderTypeColor(type: string) {
  const colors: Record<string, string> = {
    s3_compatible: 'arcoblue',
    unknown: 'gray',
  };

  return colors[type] || 'gray';
}
