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
        <a-select
          v-model="formData.provider_type"
          placeholder="请选择提供商类型"
          :disabled="isEditing"
        >
          <a-option value="backblaze_b2">Backblaze B2</a-option>
          <a-option value="tencent_cos">腾讯云COS</a-option>
          <a-option value="aliyun_oss">阿里云OSS</a-option>
          <a-option value="aws_s3">AWS S3</a-option>
          <a-option value="minio">MinIO</a-option>
        </a-select>
      </a-form-item>

      <a-form-item field="name" :label="nameLabel">
        <a-input v-model="formData.name" :placeholder="namePlaceholder" />
      </a-form-item>

      <a-form-item field="secret_id" :label="secretIdLabel">
        <a-input
          v-model="formData.secret_id"
          :placeholder="secretIdPlaceholder"
        />
        <template v-if="isBackblazeB2" #help>
          {{
            editingProvider?.secret_id_configured
              ? '当前已配置 Key ID；如需替换请输入新值，留空则沿用当前配置。'
              : '如需配置或替换 Key ID，请输入新值。'
          }}
        </template>
      </a-form-item>

      <a-form-item field="secret_key" :label="secretKeyLabel">
        <a-input-password
          v-model="formData.secret_key"
          :placeholder="secretKeyPlaceholder"
        />
        <template v-if="isBackblazeB2" #help>
          {{
            editingProvider?.secret_key_configured
              ? '当前已配置 Application Key；输入新值才会替换，留空则沿用当前配置。'
              : '当前页只维护 B2 凭证，不回显历史明文。'
          }}
        </template>
      </a-form-item>

      <a-form-item field="region" :label="regionLabel">
        <a-input v-model="formData.region" :placeholder="regionPlaceholder" />
        <template #help>
          {{ regionHelp }}
        </template>
      </a-form-item>

      <a-form-item field="endpoint" :label="endpointLabel">
        <a-input
          v-model="formData.endpoint"
          :placeholder="endpointPlaceholder"
        />
        <template #help>
          {{ endpointHelp }}
        </template>
      </a-form-item>

      <a-form-item field="bucket_name" :label="bucketLabel">
        <a-input
          v-model="formData.bucket_name"
          :placeholder="bucketPlaceholder"
        />
        <template #help>
          {{ bucketHelp }}
        </template>
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
        <template #help> 设为默认后，系统将优先使用此提供商 </template>
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
  } from '@/api/settings';

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
  const isBackblazeB2 = computed(
    () => formData.provider_type === 'backblaze_b2'
  );

  const formRules = {
    provider_type: [{ required: true, message: '请选择提供商类型' }],
    name: [{ required: true, message: '请输入提供商名称' }],
    secret_id: [
      {
        validator: (
          value: string | undefined,
          callback: (message?: string) => void
        ) => {
          if (!isEditing.value && !String(value || '').trim()) {
            callback(isBackblazeB2.value ? '请输入 Key ID' : '请输入密钥ID');
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
            callback(
              isBackblazeB2.value ? '请输入 Application Key' : '请输入密钥Key'
            );
            return;
          }
          callback();
        },
      },
    ],
    region: [{ required: true, message: '请输入地域' }],
    endpoint: [{ required: true, message: '请输入端点域名' }],
    bucket_name: [
      {
        validator: (
          value: string | undefined,
          callback: (message?: string) => void
        ) => {
          if (isBackblazeB2.value && !String(value || '').trim()) {
            callback('请输入私有 Bucket');
            return;
          }
          callback();
        },
      },
    ],
  };

  const modalTitle = computed(() =>
    isEditing.value ? '编辑对象存储配置' : '新增对象存储配置'
  );
  const nameLabel = computed(() =>
    isBackblazeB2.value ? '配置名称' : '提供商名称'
  );
  const namePlaceholder = computed(() =>
    isBackblazeB2.value
      ? '请输入配置名称（如：生产 B2）'
      : '请输入提供商名称（用于显示）'
  );
  const secretIdLabel = computed(() =>
    isBackblazeB2.value ? 'Key ID' : '密钥ID'
  );
  const secretIdPlaceholder = computed(() => {
    if (isEditing.value) {
      return isBackblazeB2.value
        ? '留空表示沿用当前 Key ID'
        : '留空表示沿用当前密钥ID';
    }

    return isBackblazeB2.value
      ? '请输入 Backblaze B2 Key ID'
      : '请输入密钥ID（Secret ID / Access Key ID）';
  });
  const secretKeyLabel = computed(() =>
    isBackblazeB2.value ? 'Application Key' : '密钥Key'
  );
  const secretKeyPlaceholder = computed(() => {
    if (isEditing.value) {
      return isBackblazeB2.value
        ? '留空表示沿用当前 Application Key'
        : '留空表示沿用当前密钥Key';
    }

    return isBackblazeB2.value
      ? '请输入 Backblaze B2 Application Key'
      : '请输入密钥Key（Secret Key / Secret Access Key）';
  });
  const regionLabel = computed(() => (isBackblazeB2.value ? 'Region' : '地域'));
  const regionPlaceholder = computed(() =>
    isBackblazeB2.value ? 'us-east-005' : '请输入地域（如：ap-beijing）'
  );
  const regionHelp = computed(() =>
    isBackblazeB2.value
      ? 'B2 Region，例如：us-east-005。'
      : '地域代码，如：ap-beijing（北京）、ap-shanghai（上海）等'
  );
  const endpointLabel = computed(() =>
    isBackblazeB2.value ? 'S3 Endpoint' : '端点域名'
  );
  const endpointPlaceholder = computed(() =>
    isBackblazeB2.value
      ? 'https://s3.us-east-005.backblazeb2.com'
      : '请输入端点域名（如：cos.ap-beijing.myqcloud.com）'
  );
  const endpointHelp = computed(() =>
    isBackblazeB2.value
      ? 'B2 使用 S3 兼容 Endpoint，例如：https://s3.us-east-005.backblazeb2.com'
      : 'API 端点地址，不同提供商格式不同'
  );
  const bucketLabel = computed(() =>
    isBackblazeB2.value ? '私有 Bucket' : '存储桶名称'
  );
  const bucketPlaceholder = computed(() =>
    isBackblazeB2.value ? '请输入私有 Bucket 名称' : '请输入存储桶名称（可选）'
  );
  const bucketHelp = computed(() =>
    isBackblazeB2.value
      ? '当前页优先维护 B2 私有 Bucket；公开桶与其他运行参数后续再补到运行时配置。'
      : '某些场景下需要指定存储桶名称'
  );

  function syncForm() {
    if (props.provider) {
      Object.assign(formData, {
        provider_type: props.provider.provider_type,
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
      provider_type: formData.provider_type,
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
