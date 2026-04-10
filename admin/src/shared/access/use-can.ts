import { computed } from 'vue';
import { useUserStore } from '@/store';
import { hasPermission } from './route-access';

export default function useCan(
  permission?: string,
  options?: { superAdminOnly?: boolean }
) {
  const userStore = useUserStore();

  return computed(() =>
    hasPermission(
      {
        roleCodes: userStore.roleCodes,
        permissionKeys: userStore.permissionKeys,
        isSuperAdmin: userStore.isSuperAdmin,
        role: userStore.role,
      },
      permission,
      options
    )
  );
}
