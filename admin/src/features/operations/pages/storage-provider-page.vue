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
          <a-button :loading="listLoading" @click="fetchProviders">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-alert type="info" style="margin-bottom: 16px">
        <template #title>Backblaze B2 配置说明</template>
        当前后台仅保留 Backblaze B2。这里维护 Key ID、Application Key、Region、
        S3 Endpoint 与私有 Bucket。
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

      <StorageProviderFormModal
        v-model:visible="formVisible"
        :provider="editingProvider"
        :submitting="actionLoading"
        :submit="submitProvider"
      />
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { onMounted, ref } from 'vue';
  import { Message } from '@arco-design/web-vue';

  import {
    createStorageProvider,
    deleteStorageProvider,
    listStorageProviders,
    updateStorageProvider,
    type StorageProvider,
  } from '@/services/storage-providers';
  import {
    getProviderTypeColor,
    getProviderTypeLabel,
  } from '../helpers/storage-provider';
  import StorageProviderFormModal, {
    type StorageProviderFormPayload,
  } from '../components/storage-provider-form-modal.vue';

  const providers = ref<StorageProvider[]>([]);
  const formVisible = ref(false);
  const editingProvider = ref<StorageProvider | null>(null);
  const listLoading = ref(false);
  const actionLoading = ref(false);

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
      title: 'Region',
      dataIndex: 'region',
    },
    {
      title: 'S3 Endpoint',
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
      width: 220,
    },
  ];

  async function fetchProviders() {
    try {
      listLoading.value = true;
      const response = await listStorageProviders();
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
  }

  function handleCreate() {
    editingProvider.value = null;
    formVisible.value = true;
  }

  function handleEdit(record: StorageProvider) {
    editingProvider.value = record;
    formVisible.value = true;
  }

  async function submitProvider(payload: StorageProviderFormPayload) {
    try {
      actionLoading.value = true;
      if (editingProvider.value) {
        await updateStorageProvider(editingProvider.value.id, payload);
      } else {
        await createStorageProvider(payload);
      }

      Message.success(editingProvider.value ? '更新成功' : '创建成功');
      editingProvider.value = null;
      await fetchProviders();
      return true;
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingProvider.value ? '更新失败' : '创建失败');
      Message.error(errorMsg);
      return false;
    } finally {
      actionLoading.value = false;
    }
  }

  async function handleDelete(id: string) {
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
  }

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
