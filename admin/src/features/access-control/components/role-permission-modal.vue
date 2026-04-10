<template>
  <a-modal
    v-model:visible="visibleProxy"
    title="配置角色权限"
    :on-before-ok="handleBeforeOk"
    @cancel="syncPermissionIds"
  >
    <a-form :model="formModel" layout="vertical">
      <a-form-item label="角色">
        <a-input :model-value="target?.name || ''" disabled />
      </a-form-item>
      <a-form-item label="权限列表">
        <a-select
          v-model="formModel.permissionIds"
          multiple
          allow-clear
          placeholder="请选择权限"
        >
          <a-option
            v-for="permission in permissions"
            :key="permission.id"
            :value="permission.id"
          >
            {{ permission.code }} - {{ permission.name }}
          </a-option>
        </a-select>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { computed, reactive, watch } from 'vue';

  import type { PermissionInfo, RoleInfo } from '@/api/rbac';

  const props = defineProps<{
    visible: boolean;
    target: RoleInfo | null;
    permissionIds: string[];
    permissions: PermissionInfo[];
    submit: (permissionIds: string[]) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const formModel = reactive({
    permissionIds: [] as string[],
  });

  function syncPermissionIds() {
    formModel.permissionIds = [...props.permissionIds];
  }

  async function handleBeforeOk() {
    return props.submit([...formModel.permissionIds]);
  }

  watch(
    () => [props.visible, props.permissionIds, props.target?.id],
    () => {
      if (props.visible) {
        syncPermissionIds();
      }
    },
    { immediate: true, deep: true }
  );
</script>
