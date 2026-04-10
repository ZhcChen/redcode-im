<template>
  <a-modal
    v-model:visible="visibleProxy"
    title="新建管理员"
    :on-before-ok="handleBeforeOk"
    @cancel="resetForm"
  >
    <a-form :model="form" layout="vertical">
      <a-form-item label="用户名" required>
        <a-input v-model="form.username" placeholder="请输入管理员用户名" />
      </a-form-item>
      <a-form-item label="邮箱" required>
        <a-input v-model="form.email" placeholder="请输入管理员邮箱" />
      </a-form-item>
      <a-form-item label="密码" required>
        <a-input-password
          v-model="form.password"
          placeholder="请输入管理员密码"
        />
      </a-form-item>
      <a-form-item label="昵称">
        <a-input v-model="form.nickname" placeholder="请输入管理员昵称" />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { computed, reactive, watch } from 'vue';

  export type AdminUserCreateFormValue = {
    username: string;
    email: string;
    password: string;
    nickname: string;
  };

  const props = defineProps<{
    visible: boolean;
    submit: (payload: AdminUserCreateFormValue) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const form = reactive<AdminUserCreateFormValue>({
    username: '',
    email: '',
    password: '',
    nickname: '',
  });

  function resetForm() {
    form.username = '';
    form.email = '';
    form.password = '';
    form.nickname = '';
  }

  async function handleBeforeOk() {
    return props.submit({
      username: form.username,
      email: form.email,
      password: form.password,
      nickname: form.nickname,
    });
  }

  watch(
    () => props.visible,
    (visible, previous) => {
      if (visible && !previous) {
        resetForm();
      }
    }
  );
</script>
