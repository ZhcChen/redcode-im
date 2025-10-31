<template>
  <div class="storage-provider-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.storageProvider']" />
    <a-card class="general-card" title="文件上传提供商设置" :bordered="false">
      <div class="actions">
        <a-space>
          <a-button type="primary" @click="handleCreate">
            <template #icon>
              <icon-plus />
            </template>
            新增提供商
          </a-button>
          <a-button @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="columns"
        :data="providers"
        :loading="loading"
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
          <a-button
            type="text"
            size="small"
            @click="handleEdit(record)"
            style="margin-right: 8px"
          >
            编辑
          </a-button>
          <a-popconfirm
            content="确定要删除这个提供商配置吗？"
            @ok="handleDelete(record.id)"
          >
            <a-button type="text" size="small" status="danger"> 删除 </a-button>
          </a-popconfirm>
        </template>
      </a-table>

      <!-- 创建/编辑对话框 -->
      <a-modal
        v-model:visible="modalVisible"
        :title="modalTitle"
        :width="600"
        @before-ok="handleSubmit"
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
              <a-option value="tencent_cos">腾讯云COS</a-option>
              <a-option value="aliyun_oss">阿里云OSS</a-option>
              <a-option value="aws_s3">AWS S3</a-option>
              <a-option value="minio">MinIO</a-option>
            </a-select>
          </a-form-item>

          <a-form-item field="name" label="提供商名称">
            <a-input
              v-model="formData.name"
              placeholder="请输入提供商名称（用于显示）"
            />
          </a-form-item>

          <a-form-item field="secret_id" label="密钥ID">
            <a-input
              v-model="formData.secret_id"
              placeholder="请输入密钥ID（Secret ID / Access Key ID）"
            />
          </a-form-item>

          <a-form-item field="secret_key" label="密钥Key">
            <a-input-password
              v-model="formData.secret_key"
              placeholder="请输入密钥Key（Secret Key / Secret Access Key）"
            />
          </a-form-item>

          <a-form-item field="region" label="地域">
            <a-input
              v-model="formData.region"
              placeholder="请输入地域（如：ap-beijing）"
            />
            <template #help>
              地域代码，如：ap-beijing（北京）、ap-shanghai（上海）等
            </template>
          </a-form-item>

          <a-form-item field="endpoint" label="端点域名">
            <a-input
              v-model="formData.endpoint"
              placeholder="请输入端点域名（如：cos.ap-beijing.myqcloud.com）"
            />
            <template #help> API端点地址，不同提供商格式不同 </template>
          </a-form-item>

          <a-form-item field="bucket_name" label="存储桶名称">
            <a-input
              v-model="formData.bucket_name"
              placeholder="请输入存储桶名称（可选）"
            />
            <template #help> 某些场景下需要指定存储桶名称 </template>
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

          <a-form-item field="description" label="描述说明">
            <a-textarea
              v-model="formData.description"
              placeholder="请输入描述信息（可选）"
              :rows="3"
              maxlength="200"
            />
          </a-form-item>
        </a-form>
      </a-modal>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import {
    listStorageProviders,
    createStorageProvider,
    updateStorageProvider,
    deleteStorageProvider,
    type StorageProvider,
    type CreateStorageProviderPayload,
  } from '@/api/settings';

  const { loading, setLoading } = useLoading(false);

  const providers = ref<StorageProvider[]>([]);
  const modalVisible = ref(false);
  const editingId = ref<string | null>(null);
  const formRef = ref();

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

  const formRules = {
    provider_type: [{ required: true, message: '请选择提供商类型' }],
    name: [{ required: true, message: '请输入提供商名称' }],
    secret_id: [{ required: true, message: '请输入密钥ID' }],
    secret_key: [{ required: true, message: '请输入密钥Key' }],
    region: [{ required: true, message: '请输入地域' }],
    endpoint: [{ required: true, message: '请输入端点域名' }],
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
      width: 150,
    },
  ];

  const modalTitle = computed(() => {
    return editingId.value ? '编辑提供商配置' : '新增提供商配置';
  });

  const getProviderTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
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
      setLoading(true);
      const response = await listStorageProviders();
      console.log('列表响应:', response);
      console.log('响应数据:', response.data);
      // 处理不同的响应格式
      const data = response.data?.data || response.data;
      providers.value = data?.providers || [];
      console.log('提供商列表:', providers.value);
    } catch (error: any) {
      console.error('获取提供商列表失败:', error);
      console.error('错误详情:', error?.response);
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '获取提供商列表失败';
      Message.error(errorMsg);
    } finally {
      setLoading(false);
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
  };

  const handleSubmit = async () => {
    const valid = await formRef.value?.validate();
    if (!valid) {
      return false; // 阻止 Modal 关闭
    }

    try {
      setLoading(true);
      const payload = {
        ...formData,
        bucket_name: formData.bucket_name || undefined,
        description: formData.description || undefined,
      };
      console.log('提交数据:', payload);

      let response;
      if (editingId.value) {
        response = await updateStorageProvider(editingId.value, payload);
        console.log('更新响应:', response);
      } else {
        response = await createStorageProvider(payload);
        console.log('创建响应:', response);
      }

      Message.success(editingId.value ? '更新成功' : '创建成功');
      modalVisible.value = false;
      // 刷新列表
      await fetchProviders();
      return true; // 允许 Modal 关闭
    } catch (error: any) {
      console.error('保存失败:', error);
      console.error('错误响应:', error?.response);
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingId.value ? '更新失败' : '创建失败');
      Message.error(errorMsg);
      return false; // 阻止 Modal 关闭
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      setLoading(true);
      await deleteStorageProvider(id);
      Message.success('删除成功');
      await fetchProviders();
    } catch (error: any) {
      console.error('删除失败:', error);
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '删除失败';
      Message.error(errorMsg);
    } finally {
      setLoading(false);
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

<style lang="less" scoped>
  .storage-provider-settings-container {
    padding: 0 20px 20px 20px;

    .general-card {
      .actions {
        margin-bottom: 16px;
      }

      .provider-table {
        margin-top: 16px;
      }
    }
  }
</style>
