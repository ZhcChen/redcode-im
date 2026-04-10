import { DirectiveBinding } from 'vue';
import { useUserStore } from '@/store';
import { hasPermission } from '@/shared/access/route-access';

function checkPermission(el: HTMLElement, binding: DirectiveBinding) {
  const { value } = binding;
  const userStore = useUserStore();
  const access = {
    roleCodes: userStore.roleCodes,
    permissionKeys: userStore.permissionKeys,
    isSuperAdmin: userStore.isSuperAdmin,
    role: userStore.role,
  };

  let permissionValues: string[] = [];
  if (Array.isArray(value)) {
    permissionValues = value;
  } else if (typeof value === 'string') {
    permissionValues = [value];
  }

  if (!permissionValues.length) {
    throw new Error(`need permissions! Like v-permission="['role:manage']"`);
  }

  const allowed = permissionValues.some((permission) =>
    hasPermission(access, permission)
  );

  if (!allowed && el.parentNode) {
    el.parentNode.removeChild(el);
  }
}

export default {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
};
