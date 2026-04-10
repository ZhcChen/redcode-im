import dayjs from 'dayjs';

export function formatDate(value?: string | null) {
  if (!value) return '-';
  return dayjs(value).format('YYYY-MM-DD HH:mm');
}

export function adminStatusColor(status: string) {
  switch (status) {
    case 'active':
      return 'green';
    case 'inactive':
      return 'orange';
    case 'banned':
      return 'red';
    case 'locked':
      return 'purple';
    default:
      return 'gray';
  }
}

export function adminStatusText(status: string) {
  switch (status) {
    case 'active':
      return '正常';
    case 'inactive':
      return '停用';
    case 'banned':
      return '封禁';
    case 'locked':
      return '锁定';
    default:
      return status;
  }
}
