<template>
  <a-modal
    v-model:visible="visibleProxy"
    :title="modalTitle"
    :width="600"
    :confirm-loading="submitting"
    :on-before-ok="handleBeforeOk"
  >
    <a-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-align="left"
      :label-col-props="{ span: 6 }"
      :wrapper-col-props="{ span: 18 }"
    >
      <a-form-item field="provider_type" label="提供商类型">
        <a-input value="Backblaze B2" disabled />
      </a-form-item>

      <a-form-item field="name" label="配置名称">
        <a-input
          v-model="formData.name"
          placeholder="请输入配置名称（如：生产 B2）"
        />
      </a-form-item>

      <a-form-item field="secret_id" label="Key ID">
        <a-input
          v-model="formData.secret_id"
          :placeholder="
            isEditing ? '留空表示沿用当前 Key ID' : '请输入 Backblaze B2 Key ID'
          "
        />
        <template #help>
          {{
            editingProvider?.secret_id_configured
              ? '当前已配置 Key ID；如需替换请输入新值，留空则沿用当前配置。'
              : '如需配置或替换 Key ID，请输入新值。'
          }}
        </template>
      </a-form-item>

      <a-form-item field="secret_key" label="Application Key">
        <a-input-password
          v-model="formData.secret_key"
          :placeholder="
            isEditing
              ? '留空表示沿用当前 Application Key'
              : '请输入 Backblaze B2 Application Key'
          "
        />
        <template #help>
          {{
            editingProvider?.secret_key_configured
              ? '当前已配置 Application Key；输入新值才会替换，留空则沿用当前配置。'
              : '当前页只维护 B2 凭证，不回显历史明文。'
          }}
        </template>
      </a-form-item>

      <a-form-item field="region" label="Region">
        <a-input v-model="formData.region" placeholder="us-east-005" />
        <template #help>B2 Region，例如：us-east-005。</template>
      </a-form-item>

      <a-form-item field="endpoint" label="S3 Endpoint">
        <a-input
          v-model="formData.endpoint"
          placeholder="https://s3.us-east-005.backblazeb2.com"
        />
        <template #help>
          B2 使用 S3 兼容 Endpoint，例如：https://s3.us-east-005.backblazeb2.com
        </template>
      </a-form-item>

      <a-form-item field="bucket_name" label="私有 Bucket">
        <a-input
          v-model="formData.bucket_name"
          placeholder="请输入私有 Bucket 名称"
        />
        <template #help>当前仅支持 Backblaze B2 私有 Bucket。</template>
      </a-form-item>

      <a-form-item field="is_active" label="启用状态">
        <a-switch
          v-model="formData.is_active"
          checked-text="启用"
          unchecked-text="禁用"
        />
      </a-form-item>

      <a-form-item field="is_default" label="设为默认">
        <a-switch
          v-model="formData.is_default"
          checked-text="是"
          unchecked-text="否"
        />
        <template #help>设为默认后，系统将优先使用此提供商。</template>
      </a-form-item>

      <a-form-item field="description" label="变更说明">
        <a-textarea
          v-model="formData.description"
          placeholder="记录本次切换原因、涉及账号或回滚背景（可选）"
          :rows="3"
          maxlength="200"
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { computed, nextTick, reactive, ref, watch } from 'vue';
  import type { FormInstance } from '@arco-design/web-vue';

  import type {
    CreateStorageProviderPayload,
    StorageProvider,
  } from '@/services/storage-providers';

  export type StorageProviderFormPayload = CreateStorageProviderPayload & {
    description?: string;
  };

  const props = defineProps<{
    visible: boolean;
    provider: StorageProvider | null;
    submitting: boolean;
    submit: (payload: StorageProviderFormPayload) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const formRef = ref<FormInstance>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const formData = reactive<
    CreateStorageProviderPayload & { description?: string }
  >({
    provider_type: 'backblaze_b2',
    name: '',
    secret_id: '',
    secret_key: '',
    region: '',
    endpoint: '',
    bucket_name: '',
    is_active: false,
    is_default: false,
    description: '',
  });

  const editingProvider = computed(() => props.provider);
  const isEditing = computed(() => Boolean(props.provider));

  const formRules = {
    name: [{ required: true, message: '请输入配置名称' }],
    secret_id: [
      {
        validator: (
          value: string | undefined,
          callback: (message?: string) => void
        ) => {
          if (!isEditing.value && !String(value || '').trim()) {
            callback('请输入 Key ID');
            return;
          }
          callback();
        },
      },
    ],
    secret_key: [
      {
        validator: (
          value: string | undefined,
          callback: (message?: string) => void
        ) => {
          if (!isEditing.value && !String(value || '').trim()) {
            callback('请输入 Application Key');
            return;
          }
          callback();
        },
      },
    ],
    region: [{ required: true, message: '请输入 Region' }],
    endpoint: [{ required: true, message: '请输入 S3 Endpoint' }],
    bucket_name: [
      {
        validator: (
          value: string | undefined,
          callback: (message?: string) => void
        ) => {
          if (!String(value || '').trim()) {
            callback('请输入私有 Bucket');
            return;
          }
          callback();
        },
      },
    ],
  };

  const modalTitle = computed(() =>
    isEditing.value ? '编辑 B2 存储配置' : '新增 B2 存储配置'
  );

  function syncForm() {
    if (props.provider) {
      Object.assign(formData, {
        provider_type: 'backblaze_b2',
        name: props.provider.name,
        secret_id: '',
        secret_key: '',
        region: props.provider.region,
        endpoint: props.provider.endpoint,
        bucket_name: props.provider.bucket_name || '',
        is_active: props.provider.is_active,
        is_default: props.provider.is_default,
        description: props.provider.description || '',
      });
      return;
    }

    Object.assign(formData, {
      provider_type: 'backblaze_b2',
      name: '',
      secret_id: '',
      secret_key: '',
      region: '',
      endpoint: '',
      bucket_name: '',
      is_active: false,
      is_default: false,
      description: '',
    });
  }

  async function handleBeforeOk() {
    if (!formRef.value) {
      return false;
    }

    try {
      const errors = await formRef.value.validate();
      if (errors) {
        return false;
      }
    } catch {
      return false;
    }

    return props.submit({
      provider_type: 'backblaze_b2',
      name: formData.name,
      secret_id: formData.secret_id,
      secret_key: formData.secret_key,
      region: formData.region,
      endpoint: formData.endpoint,
      bucket_name: formData.bucket_name || undefined,
      is_active: formData.is_active,
      is_default: formData.is_default,
      description: formData.description || undefined,
    });
  }

  watch(
    () => [props.visible, props.provider?.id],
    async () => {
      if (!props.visible) {
        return;
      }

      syncForm();
      await nextTick();
      formRef.value?.clearValidate?.();
    },
    { immediate: true }
  );
</script>
