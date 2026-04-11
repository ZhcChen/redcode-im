<template>
  <a-modal
    v-model:visible="visibleProxy"
    title="分配管理员角色"
    :on-before-ok="handleBeforeOk"
    @cancel="resetRoleIds"
  >
    <a-form :model="formModel" layout="vertical">
      <a-form-item label="管理员账号">
        <a-input :model-value="target?.username || ''" disabled />
      </a-form-item>
      <a-form-item label="角色列表">
        <a-select
          v-model="formModel.roleIds"
          multiple
          allow-clear
          placeholder="请选择角色"
        >
          <a-option v-for="role in roleOptions" :key="role.id" :value="role.id">
            {{ role.code }} - {{ role.name }}
          </a-option>
        </a-select>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { computed, reactive, watch } from 'vue';

  import type { RoleInfo } from '@/services/access-control';
  import type { AdminUserRow } from '../types';

  const props = defineProps<{
    visible: boolean;
    target: AdminUserRow | null;
    roleIds: string[];
    roleOptions: RoleInfo[];
    submit: (roleIds: string[]) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const formModel = reactive({
    roleIds: [] as string[],
  });

  function resetRoleIds() {
    formModel.roleIds = [...props.roleIds];
  }

  async function handleBeforeOk() {
    return props.submit([...formModel.roleIds]);
  }

  watch(
    () => [props.visible, props.roleIds, props.target?.id],
    () => {
      if (props.visible) {
        resetRoleIds();
      }
    },
    { immediate: true, deep: true }
  );
</script>
