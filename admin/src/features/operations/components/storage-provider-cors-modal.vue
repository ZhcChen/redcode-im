<template>
  <a-modal
    v-model:visible="visibleProxy"
    title="配置跨域规则"
    :width="600"
    :confirm-loading="submitting"
    :on-before-ok="handleBeforeOk"
  >
    <a-form
      :model="formData"
      label-align="left"
      :label-col-props="{ span: 6 }"
      :wrapper-col-props="{ span: 18 }"
    >
      <a-form-item label="允许来源">
        <a-textarea
          v-model="formData.allowed_origins"
          :rows="3"
          placeholder="每行一个来源，例如：https://example.com"
        />
        <template #help> 可使用逗号或换行分隔多个域名 </template>
      </a-form-item>
      <a-form-item label="允许方法">
        <a-input
          v-model="formData.allowed_methods"
          placeholder="例如：PUT,GET,OPTIONS"
        />
        <template #help> 多个方法使用逗号或换行分隔 </template>
      </a-form-item>
      <a-form-item label="允许头部">
        <a-input
          v-model="formData.allowed_headers"
          placeholder="默认为 * 表示允许所有自定义头"
        />
      </a-form-item>
      <a-form-item label="暴露头部">
        <a-input v-model="formData.expose_headers" placeholder="例如：ETag" />
      </a-form-item>
      <a-form-item label="缓存时间 (秒)">
        <a-input-number
          v-model="formData.max_age_seconds"
          :min="0"
          :step="60"
          style="width: 100%"
          placeholder="例如：600"
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { computed, reactive, watch } from 'vue';
  import { Message } from '@arco-design/web-vue';

  import type { SetCosCorsRequest, StorageProvider } from '@/api/settings';
  import {
    resolveDefaultCorsOrigin,
    splitMultiValueInput,
  } from '../helpers/storage-provider';

  const props = defineProps<{
    visible: boolean;
    provider: StorageProvider | null;
    submitting: boolean;
    submit: (payload: SetCosCorsRequest) => Promise<boolean> | boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:visible', value: boolean): void;
  }>();

  const visibleProxy = computed({
    get: () => props.visible,
    set: (value: boolean) => emit('update:visible', value),
  });

  const formData = reactive({
    allowed_origins: '',
    allowed_methods: 'PUT,GET,OPTIONS',
    allowed_headers: '*',
    expose_headers: 'ETag',
    max_age_seconds: 600,
  });

  function resetForm() {
    formData.allowed_origins = resolveDefaultCorsOrigin();
    formData.allowed_methods = 'PUT,GET,OPTIONS';
    formData.allowed_headers = '*';
    formData.expose_headers = 'ETag';
    formData.max_age_seconds = 600;
  }

  async function handleBeforeOk() {
    if (!props.provider) {
      return false;
    }

    const allowedOrigins = splitMultiValueInput(formData.allowed_origins);
    if (allowedOrigins.length === 0) {
      Message.error('请至少配置一个允许来源');
      return false;
    }

    const allowedMethods = splitMultiValueInput(formData.allowed_methods, true);
    if (allowedMethods.length === 0) {
      Message.error('请至少配置一个允许方法');
      return false;
    }

    return props.submit({
      provider_id: props.provider.id,
      rules: [
        {
          allowed_origins: allowedOrigins,
          allowed_methods: allowedMethods,
          allowed_headers: splitMultiValueInput(formData.allowed_headers),
          expose_headers: splitMultiValueInput(formData.expose_headers),
          max_age_seconds:
            typeof formData.max_age_seconds === 'number'
              ? formData.max_age_seconds
              : undefined,
        },
      ],
    });
  }

  watch(
    () => props.visible,
    (visible) => {
      if (visible) {
        resetForm();
      }
    },
    { immediate: true }
  );
</script>
