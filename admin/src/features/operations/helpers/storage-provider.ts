export function getProviderTypeLabel(type: string) {
  const labels: Record<string, string> = {
    backblaze_b2: 'Backblaze B2',
    unknown: '未知',
  };

  return labels[type] || type;
}

export function getProviderTypeColor(type: string) {
  const colors: Record<string, string> = {
    backblaze_b2: 'arcoblue',
    unknown: 'gray',
  };

  return colors[type] || 'gray';
}
