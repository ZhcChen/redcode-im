<template>
  <a-modal
    v-model:visible="visibleProxy"
    :title="editingRole ? '编辑角色' : '新建角色'"
    :on-before-ok="handleBeforeOk"
    @cancel="syncForm"
  >
    <a-form :model="formModel" layout="vertical">
      <a-form-item label="角色名称" required>
        <a-input v-model="formModel.name" placeholder="请输入角色名称" />
      </a-form-item>
      <a-form-item label="角色代码" required>
        <a-input
          v-model="formModel.code"
          placeholder="请输入角色代码"
          :disabled="Boolean(editingRole)"
        />
      </a-form-item>
      <a-form-item label="描述">
        <a-textarea v-model="formModel.description" placeholder="请输入描述" />
      </a-form-item>
      <a-form-item v-if="!editingRole" label="初始权限">
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

  import type { PermissionInfo, RoleInfo } from '@/services/access-control';

  export type RoleFormValue = {
    name: string;
    code: string;
    description: string;
    permissionIds: string[];
  };

  const props = defineProps<{
    visible: boolean;
    editingRole: RoleInfo | null;
    permissions: PermissionInfo[];
    submit: (payload: RoleFormValue) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const formModel = reactive<RoleFormValue>({
    name: '',
    code: '',
    description: '',
    permissionIds: [],
  });

  function syncForm() {
    formModel.name = props.editingRole?.name || '';
    formModel.code = props.editingRole?.code || '';
    formModel.description = props.editingRole?.description || '';
    formModel.permissionIds = props.editingRole
      ? props.editingRole.permissions.map((item) => item.id)
      : [];
  }

  async function handleBeforeOk() {
    return props.submit({
      name: formModel.name,
      code: formModel.code,
      description: formModel.description,
      permissionIds: [...formModel.permissionIds],
    });
  }

  watch(
    () => [props.visible, props.editingRole?.id],
    () => {
      if (props.visible) {
        syncForm();
      }
    },
    { immediate: true }
  );
</script>
