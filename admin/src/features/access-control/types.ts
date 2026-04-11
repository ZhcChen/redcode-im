import type { AdminUserInfo } from '@/services/access-control';

export type AdminUserRow = AdminUserInfo & {
  roleCodes: string[];
};
