import type { AdminUserInfo } from '@/api/user';

export type AdminUserRow = AdminUserInfo & {
  roleCodes: string[];
};
