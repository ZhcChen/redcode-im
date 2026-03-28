<template>
  <div class="storage-provider-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.storageProvider']" />
    <a-card
      class="general-card"
      :title="t('storageProvider.title')"
      :bordered="false"
    >
      <div class="actions">
        <a-space>
          <a-button
            type="primary"
            :loading="actionLoading"
            @click="handleCreate"
          >
            <template #icon>
              <icon-plus />
            </template>
            {{ t('storageProvider.create') }}
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            {{ t('storageProvider.refresh') }}
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="columns"
        :data="providers"
        :loading="listLoading"
        :pagination="false"
        class="provider-table"
      >
        <template #provider_type="{ record }">
          <a-tag :color="getProviderTypeColor(record.provider_type)">
            {{ getProviderTypeLabel(record.provider_type) }}
          </a-tag>
        </template>

        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{
              record.is_active
                ? t('storageProvider.status.active')
                : t('storageProvider.status.inactive')
            }}
          </a-tag>
        </template>

        <template #is_default="{ record }">
          <a-tag v-if="record.is_default" color="blue">
            {{ t('storageProvider.defaultTag') }}
          </a-tag>
        </template>

        <template #operations="{ record }">
          <a-space size="mini">
            <a-button
              v-if="record.provider_type === 'tencent_cos'"
              type="text"
              size="small"
              @click="openCorsModal(record)"
            >
              {{ t('storageProvider.corsConfig') }}
            </a-button>
            <a-button type="text" size="small" @click="handleEdit(record)">
              {{ t('storageProvider.edit') }}
            </a-button>
            <a-popconfirm
              :content="t('storageProvider.deleteConfirm')"
              @ok="handleDelete(record.id)"
            >
              <a-button type="text" size="small" status="danger">
                {{ t('storageProvider.delete') }}
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>

      <!-- 创建/编辑对话框 -->
      <a-modal
        :visible="modalVisible"
        :title="modalTitle"
        :width="600"
        :confirm-loading="actionLoading"
        @update:visible="modalVisible = $event"
        @before-ok="handleBeforeOk"
        @cancel="handleCancel"
      >
        <a-form
          ref="formRef"
          :model="formData"
          :rules="formRules"
          label-align="left"
          :label-col-props="{ span: 6 }"
          :wrapper-col-props="{ span: 18 }"
        >
          <a-form-item
            field="provider_type"
            :label="t('storageProvider.form.providerType.label')"
          >
            <a-select
              v-model="formData.provider_type"
              :placeholder="t('storageProvider.form.providerType.placeholder')"
              :disabled="!!editingId"
            >
              <a-option value="tencent_cos">
                {{ t('storageProvider.providerType.tencentCos') }}
              </a-option>
              <a-option value="aliyun_oss">
                {{ t('storageProvider.providerType.aliyunOss') }}
              </a-option>
              <a-option value="aws_s3">
                {{ t('storageProvider.providerType.awsS3') }}
              </a-option>
              <a-option value="minio">
                {{ t('storageProvider.providerType.minio') }}
              </a-option>
            </a-select>
          </a-form-item>

          <a-form-item
            field="name"
            :label="t('storageProvider.form.name.label')"
          >
            <a-input
              v-model="formData.name"
              :placeholder="t('storageProvider.form.name.placeholder')"
            />
          </a-form-item>

          <a-form-item
            field="secret_id"
            :label="t('storageProvider.form.secretId.label')"
          >
            <a-input
              v-model="formData.secret_id"
              :placeholder="t('storageProvider.form.secretId.placeholder')"
            />
          </a-form-item>

          <a-form-item
            field="secret_key"
            :label="t('storageProvider.form.secretKey.label')"
          >
            <a-input-password
              v-model="formData.secret_key"
              :placeholder="t('storageProvider.form.secretKey.placeholder')"
            />
          </a-form-item>

          <a-form-item
            field="region"
            :label="t('storageProvider.form.region.label')"
          >
            <a-input
              v-model="formData.region"
              :placeholder="t('storageProvider.form.region.placeholder')"
            />
            <template #help>
              {{ t('storageProvider.form.region.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="endpoint"
            :label="t('storageProvider.form.endpoint.label')"
          >
            <a-input
              v-model="formData.endpoint"
              :placeholder="t('storageProvider.form.endpoint.placeholder')"
            />
            <template #help>
              {{ t('storageProvider.form.endpoint.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="bucket_name"
            :label="t('storageProvider.form.bucketName.label')"
          >
            <a-input
              v-model="formData.bucket_name"
              :placeholder="t('storageProvider.form.bucketName.placeholder')"
            />
            <template #help>
              {{ t('storageProvider.form.bucketName.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="is_active"
            :label="t('storageProvider.form.isActive.label')"
          >
            <a-switch
              v-model="formData.is_active"
              :checked-text="t('storageProvider.form.isActive.checked')"
              :unchecked-text="t('storageProvider.form.isActive.unchecked')"
            />
          </a-form-item>

          <a-form-item
            field="is_default"
            :label="t('storageProvider.form.isDefault.label')"
          >
            <a-switch
              v-model="formData.is_default"
              :checked-text="t('storageProvider.form.isDefault.checked')"
              :unchecked-text="t('storageProvider.form.isDefault.unchecked')"
            />
            <template #help>
              {{ t('storageProvider.form.isDefault.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="description"
            :label="t('storageProvider.form.description.label')"
          >
            <a-textarea
              v-model="formData.description"
              :placeholder="t('storageProvider.form.description.placeholder')"
              :rows="3"
              maxlength="200"
            />
          </a-form-item>
        </a-form>
      </a-modal>

      <!-- 跨域配置对话框 -->
      <a-modal
        :visible="corsModalVisible"
        :title="t('storageProvider.corsModal.title')"
        :width="600"
        :confirm-loading="corsSubmitting"
        @update:visible="corsModalVisible = $event"
        @ok="handleCorsSubmit"
        @cancel="handleCorsCancel"
      >
        <a-form
          :model="corsForm"
          label-align="left"
          :label-col-props="{ span: 6 }"
          :wrapper-col-props="{ span: 18 }"
        >
          <a-form-item :label="t('storageProvider.cors.allowedOrigins.label')">
            <a-textarea
              v-model="corsForm.allowed_origins"
              :rows="3"
              :placeholder="t('storageProvider.cors.allowedOrigins.placeholder')"
            />
            <template #help>
              {{ t('storageProvider.cors.allowedOrigins.help') }}
            </template>
          </a-form-item>
          <a-form-item :label="t('storageProvider.cors.allowedMethods.label')">
            <a-input
              v-model="corsForm.allowed_methods"
              :placeholder="t('storageProvider.cors.allowedMethods.placeholder')"
            />
            <template #help>
              {{ t('storageProvider.cors.allowedMethods.help') }}
            </template>
          </a-form-item>
          <a-form-item :label="t('storageProvider.cors.allowedHeaders.label')">
            <a-input
              v-model="corsForm.allowed_headers"
              :placeholder="t('storageProvider.cors.allowedHeaders.placeholder')"
            />
          </a-form-item>
          <a-form-item :label="t('storageProvider.cors.exposeHeaders.label')">
            <a-input
              v-model="corsForm.expose_headers"
              :placeholder="t('storageProvider.cors.exposeHeaders.placeholder')"
            />
          </a-form-item>
          <a-form-item :label="t('storageProvider.cors.maxAge.label')">
            <a-input-number
              v-model="corsForm.max_age_seconds"
              :min="0"
              :step="60"
              style="width: 100%"
              :placeholder="t('storageProvider.cors.maxAge.placeholder')"
            />
          </a-form-item>
        </a-form>
      </a-modal>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, computed, onMounted, nextTick } from 'vue';
  import { Message, type FormInstance } from '@arco-design/web-vue';
  import { useI18n } from 'vue-i18n';
  import {
    listStorageProviders,
    createStorageProvider,
    updateStorageProvider,
    deleteStorageProvider,
    setCosCors,
    type StorageProvider,
    type CreateStorageProviderPayload,
    type SetCosCorsRequest,
  } from '@/api/settings';

  const { t } = useI18n();
  const providers = ref<StorageProvider[]>([]);
  const modalVisible = ref(false);
  const corsModalVisible = ref(false);
  const corsSubmitting = ref(false);
  const editingId = ref<string | null>(null);
  const currentCorsProvider = ref<StorageProvider | null>(null);
  const formRef = ref<FormInstance>();
  const listLoading = ref(false);
  const actionLoading = ref(false);

  const formData = reactive<
    CreateStorageProviderPayload & { description?: string }
  >({
    provider_type: 'tencent_cos',
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

  const corsForm = reactive({
    allowed_origins: 'http://localhost:8011',
    allowed_methods: 'PUT,GET,OPTIONS',
    allowed_headers: '*',
    expose_headers: 'ETag',
    max_age_seconds: 600,
  });

  const formRules = computed(() => ({
    provider_type: [
      {
        required: true,
        message: t('storageProvider.validation.providerType.required'),
      },
    ],
    name: [
      { required: true, message: t('storageProvider.validation.name.required') },
    ],
    secret_id: [
      {
        required: true,
        message: t('storageProvider.validation.secretId.required'),
      },
    ],
    secret_key: [
      {
        required: true,
        message: t('storageProvider.validation.secretKey.required'),
      },
    ],
    region: [
      {
        required: true,
        message: t('storageProvider.validation.region.required'),
      },
    ],
    endpoint: [
      {
        required: true,
        message: t('storageProvider.validation.endpoint.required'),
      },
    ],
  }));

  const columns = computed(() => [
    {
      title: t('storageProvider.table.providerType'),
      dataIndex: 'provider_type',
      slotName: 'provider_type',
    },
    {
      title: t('storageProvider.table.name'),
      dataIndex: 'name',
    },
    {
      title: t('storageProvider.table.region'),
      dataIndex: 'region',
    },
    {
      title: t('storageProvider.table.endpoint'),
      dataIndex: 'endpoint',
      ellipsis: true,
    },
    {
      title: t('storageProvider.table.status'),
      dataIndex: 'is_active',
      slotName: 'is_active',
    },
    {
      title: t('storageProvider.table.default'),
      dataIndex: 'is_default',
      slotName: 'is_default',
    },
    {
      title: t('storageProvider.table.actions'),
      slotName: 'operations',
      width: 260,
    },
  ]);

  const modalTitle = computed(() => {
    return editingId.value
      ? t('storageProvider.modal.edit')
      : t('storageProvider.modal.create');
  });

  const getProviderTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      tencent_cos: 'storageProvider.providerType.tencentCos',
      aliyun_oss: 'storageProvider.providerType.aliyunOss',
      aws_s3: 'storageProvider.providerType.awsS3',
      minio: 'storageProvider.providerType.minio',
      unknown: 'storageProvider.providerType.unknown',
    };
    const labelKey = labels[type];
    return labelKey ? t(labelKey) : type;
  };

  const getProviderTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      tencent_cos: 'blue',
      aliyun_oss: 'orange',
      aws_s3: 'purple',
      minio: 'cyan',
      unknown: 'gray',
    };
    return colors[type] || 'gray';
  };

  const fetchProviders = async () => {
    try {
      listLoading.value = true;
      const response = await listStorageProviders();
      // 处理不同的响应格式
      const data = response.data?.data || response.data;
      providers.value = data?.providers || [];
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('storageProvider.error.fetch');
      Message.error(errorMsg);
    } finally {
      listLoading.value = false;
    }
  };

  const handleCreate = () => {
    editingId.value = null;
    Object.assign(formData, {
      provider_type: 'tencent_cos',
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
    modalVisible.value = true;
    nextTick(() => {
      formRef.value?.clearValidate?.();
    });
  };

  const handleEdit = (record: StorageProvider) => {
    editingId.value = record.id;
    Object.assign(formData, {
      provider_type: record.provider_type,
      name: record.name,
      secret_id: record.secret_id,
      secret_key: record.secret_key,
      region: record.region,
      endpoint: record.endpoint,
      bucket_name: record.bucket_name || '',
      is_active: record.is_active,
      is_default: record.is_default,
      description: record.description || '',
    });
    modalVisible.value = true;
    nextTick(() => {
      formRef.value?.clearValidate?.();
    });
  };

  const openCorsModal = (record: StorageProvider) => {
    if (record.provider_type !== 'tencent_cos') {
      Message.warning(t('storageProvider.error.corsUnsupported'));
      return;
    }
    currentCorsProvider.value = record;
    const defaultOrigin =
      typeof window !== 'undefined'
        ? window.location.origin
        : 'http://localhost:8011';
    corsForm.allowed_origins = defaultOrigin;
    corsForm.allowed_methods = 'PUT,GET,OPTIONS';
    corsForm.allowed_headers = '*';
    corsForm.expose_headers = 'ETag';
    corsForm.max_age_seconds = 600;
    corsModalVisible.value = true;
  };

  const handleCorsCancel = () => {
    corsModalVisible.value = false;
    corsSubmitting.value = false;
  };

  const splitInput = (input: string, toUpper = false) => {
    return input
      .split(/[\n,]/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0)
      .map((item) => (toUpper ? item.toUpperCase() : item));
  };

  const handleCorsSubmit = async () => {
    if (!currentCorsProvider.value) {
      return;
    }

    const allowedOrigins = splitInput(corsForm.allowed_origins);
    if (allowedOrigins.length === 0) {
      Message.error(t('storageProvider.validation.allowedOrigins.required'));
      return;
    }

    const allowedMethods = splitInput(corsForm.allowed_methods, true);
    if (allowedMethods.length === 0) {
      Message.error(t('storageProvider.validation.allowedMethods.required'));
      return;
    }

    const payload: SetCosCorsRequest = {
      provider_id: currentCorsProvider.value.id,
      rules: [
        {
          allowed_origins: allowedOrigins,
          allowed_methods: allowedMethods,
          allowed_headers: splitInput(corsForm.allowed_headers),
          expose_headers: splitInput(corsForm.expose_headers),
          max_age_seconds:
            typeof corsForm.max_age_seconds === 'number'
              ? corsForm.max_age_seconds
              : undefined,
        },
      ],
    };

    try {
      corsSubmitting.value = true;
      const response = await setCosCors(payload);
      const { data } = response;
      if (data.success) {
        Message.success(data.message || t('storageProvider.success.corsSubmit'));
        corsModalVisible.value = false;
      } else {
        Message.error(data.message || t('storageProvider.error.corsSubmit'));
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('storageProvider.error.corsSubmit');
      Message.error(errorMsg);
    } finally {
      corsSubmitting.value = false;
    }
  };

  const handleSubmit = async () => {
    if (!formRef.value) {
      return false;
    }

    try {
      const errors = await formRef.value.validate();
      if (errors) {
        return false;
      }
    } catch (error) {
      return false; // 阻止 Modal 关闭
    }

    try {
      actionLoading.value = true;
      const payload = {
        ...formData,
        bucket_name: formData.bucket_name || undefined,
        description: formData.description || undefined,
      };

      if (editingId.value) {
        await updateStorageProvider(editingId.value, payload);
      } else {
        await createStorageProvider(payload);
      }

      Message.success(
        editingId.value
          ? t('storageProvider.success.update')
          : t('storageProvider.success.create')
      );
      await fetchProviders();
      return true;
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingId.value
          ? t('storageProvider.error.update')
          : t('storageProvider.error.create'));
      Message.error(errorMsg);
      return false;
    } finally {
      actionLoading.value = false;
    }
  };

  const handleBeforeOk = async (done: (closed: boolean) => void) => {
    const result = await handleSubmit();
    done(result);
  };

  const handleDelete = async (id: string) => {
    try {
      actionLoading.value = true;
      await deleteStorageProvider(id);
      Message.success(t('storageProvider.success.delete'));
      await fetchProviders();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('storageProvider.error.delete');
      Message.error(errorMsg);
    } finally {
      actionLoading.value = false;
    }
  };

  const handleCancel = () => {
    modalVisible.value = false;
    editingId.value = null;
  };

  const handleRefresh = () => {
    fetchProviders();
  };

  onMounted(() => {
    fetchProviders();
  });
</script>

<style scoped>
  .storage-provider-settings-container {
    padding: 0 20px 20px;
  }

  .storage-provider-settings-container .general-card .actions {
    margin-bottom: 16px;
  }

  .storage-provider-settings-container .general-card .provider-table {
    margin-top: 16px;
  }
</style>
