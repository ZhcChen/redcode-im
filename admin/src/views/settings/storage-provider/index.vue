<template>
  <div class="storage-provider-settings-container">
    <Breadcrumb
      :items="['menu.operations', 'menu.operations.storageProvider']"
    />
    <a-card class="general-card" title="对象存储配置" :bordered="false">
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
            新增配置
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-alert type="info" style="margin-bottom: 16px">
        <template #title>Backblaze B2 配置说明</template>
        当前页优先维护 Backblaze B2 的 Key ID、Application Key、Region、S3
        Endpoint 与私有 Bucket。输入面默认按 B2 语义展示，便于直接复用 cartoon
        已验证过的配置方式。
      </a-alert>

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
            {{ record.is_active ? '启用' : '禁用' }}
          </a-tag>
        </template>

        <template #is_default="{ record }">
          <a-tag v-if="record.is_default" color="blue">默认</a-tag>
        </template>

        <template #operations="{ record }">
          <a-space size="mini">
            <a-button
              v-if="record.provider_type === 'tencent_cos'"
              type="text"
              size="small"
              @click="openCorsModal(record)"
            >
              配置跨域
            </a-button>
            <a-button type="text" size="small" @click="handleEdit(record)">
              编辑
            </a-button>
            <a-popconfirm
              content="确定要删除这个提供商配置吗？"
              @ok="handleDelete(record.id)"
            >
              <a-button type="text" size="small" status="danger">
                删除
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
          <a-form-item field="provider_type" label="提供商类型">
            <a-select
              v-model="formData.provider_type"
              placeholder="请选择提供商类型"
              :disabled="!!editingId"
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
            <a-input
              v-model="formData.region"
              :placeholder="regionPlaceholder"
            />
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

      <!-- 跨域配置对话框 -->
      <a-modal
        :visible="corsModalVisible"
        title="配置跨域规则"
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
          <a-form-item label="允许来源">
            <a-textarea
              v-model="corsForm.allowed_origins"
              :rows="3"
              placeholder="每行一个来源，例如：https://example.com"
            />
            <template #help> 可使用逗号或换行分隔多个域名 </template>
          </a-form-item>
          <a-form-item label="允许方法">
            <a-input
              v-model="corsForm.allowed_methods"
              placeholder="例如：PUT,GET,OPTIONS"
            />
            <template #help> 多个方法使用逗号或换行分隔 </template>
          </a-form-item>
          <a-form-item label="允许头部">
            <a-input
              v-model="corsForm.allowed_headers"
              placeholder="默认为 * 表示允许所有自定义头"
            />
          </a-form-item>
          <a-form-item label="暴露头部">
            <a-input
              v-model="corsForm.expose_headers"
              placeholder="例如：ETag"
            />
          </a-form-item>
          <a-form-item label="缓存时间 (秒)">
            <a-input-number
              v-model="corsForm.max_age_seconds"
              :min="0"
              :step="60"
              style="width: 100%"
              placeholder="例如：600"
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

  const providers = ref<StorageProvider[]>([]);
  const modalVisible = ref(false);
  const corsModalVisible = ref(false);
  const corsSubmitting = ref(false);
  const editingId = ref<string | null>(null);
  const currentCorsProvider = ref<StorageProvider | null>(null);
  const editingProvider = ref<StorageProvider | null>(null);
  const formRef = ref<FormInstance>();
  const listLoading = ref(false);
  const actionLoading = ref(false);

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

  const corsForm = reactive({
    allowed_origins: 'http://localhost:8011',
    allowed_methods: 'PUT,GET,OPTIONS',
    allowed_headers: '*',
    expose_headers: 'ETag',
    max_age_seconds: 600,
  });

  const isBackblazeB2 = computed(
    () => formData.provider_type === 'backblaze_b2'
  );
  const isEditing = computed(() => Boolean(editingId.value));

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

  const columns = [
    {
      title: '提供商类型',
      dataIndex: 'provider_type',
      slotName: 'provider_type',
    },
    {
      title: '名称',
      dataIndex: 'name',
    },
    {
      title: '地域',
      dataIndex: 'region',
    },
    {
      title: '端点',
      dataIndex: 'endpoint',
      ellipsis: true,
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      slotName: 'is_active',
    },
    {
      title: '默认',
      dataIndex: 'is_default',
      slotName: 'is_default',
    },
    {
      title: '操作',
      slotName: 'operations',
      width: 260,
    },
  ];

  const modalTitle = computed(() => {
    return editingId.value ? '编辑对象存储配置' : '新增对象存储配置';
  });

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

  const getProviderTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      backblaze_b2: 'Backblaze B2',
      tencent_cos: '腾讯云COS',
      aliyun_oss: '阿里云OSS',
      aws_s3: 'AWS S3',
      minio: 'MinIO',
      unknown: '未知',
    };
    return labels[type] || type;
  };

  const getProviderTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      backblaze_b2: 'arcoblue',
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
        '获取提供商列表失败';
      Message.error(errorMsg);
    } finally {
      listLoading.value = false;
    }
  };

  const handleCreate = () => {
    editingId.value = null;
    editingProvider.value = null;
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
    modalVisible.value = true;
    nextTick(() => {
      formRef.value?.clearValidate?.();
    });
  };

  const handleEdit = (record: StorageProvider) => {
    editingId.value = record.id;
    editingProvider.value = record;
    Object.assign(formData, {
      provider_type: record.provider_type,
      name: record.name,
      secret_id: '',
      secret_key: '',
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
      Message.warning('当前提供商不支持跨域配置');
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
      Message.error('请至少配置一个允许来源');
      return;
    }

    const allowedMethods = splitInput(corsForm.allowed_methods, true);
    if (allowedMethods.length === 0) {
      Message.error('请至少配置一个允许方法');
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
        Message.success(data.message || '跨域规则配置成功');
        corsModalVisible.value = false;
      } else {
        Message.error(data.message || '跨域规则配置失败');
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '跨域规则配置失败';
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

      Message.success(editingId.value ? '更新成功' : '创建成功');
      // 刷新列表
      await fetchProviders();
      return true; // 允许 Modal 关闭
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingId.value ? '更新失败' : '创建失败');
      Message.error(errorMsg);
      return false; // 阻止 Modal 关闭
    } finally {
      actionLoading.value = false;
    }
  };

  const handleBeforeOk = async (done: (closed: boolean) => void) => {
    const result = await handleSubmit();
    done(result); // result 为 true 时关闭 Modal，false 时不关闭
  };

  const handleDelete = async (id: string) => {
    try {
      actionLoading.value = true;
      await deleteStorageProvider(id);
      Message.success('删除成功');
      await fetchProviders();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '删除失败';
      Message.error(errorMsg);
    } finally {
      actionLoading.value = false;
    }
  };

  const handleCancel = () => {
    modalVisible.value = false;
    editingId.value = null;
    editingProvider.value = null;
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
