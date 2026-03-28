<template>
  <div class="ipinfo-token-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.ipinfoToken']" />
    <a-card
      class="general-card"
      :title="t('ipinfoToken.title')"
      :bordered="false"
    >
      <div class="actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            :placeholder="t('ipinfoToken.search.placeholder')"
            style="width: 300px"
            allow-clear
            @search="handleSearch"
            @clear="handleSearchClear"
          />
          <a-button
            type="primary"
            :loading="submitLoading"
            @click="showCreateModal = true"
          >
            <template #icon>
              <icon-plus />
            </template>
            {{ t('ipinfoToken.create') }}
          </a-button>
          <a-button :loading="loading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            {{ t('ipinfoToken.refresh') }}
          </a-button>
        </a-space>
      </div>

      <!-- Token列表 -->
      <a-table
        :columns="columns"
        :data="tokenList"
        :loading="loading"
        :pagination="false"
        :scroll="{ x: 'max-content' }"
        class="token-table"
      >
        <template #status="{ record }">
          <a-tag
            :color="record.status === 'active' ? 'green' : 'red'"
            size="small"
          >
            {{
              record.status === 'active'
                ? t('ipinfoToken.status.active')
                : t('ipinfoToken.status.exhausted')
            }}
          </a-tag>
        </template>

        <template #usage="{ record }">
          <a-progress
            :percent="(record.usedCount / record.monthlyLimit) * 100"
            :stroke-width="8"
            :show-text="false"
            :color="
              record.usedCount >= record.monthlyLimit ? '#f56c6c' : '#52c41a'
            "
          />
          <div class="usage-text">
            {{ record.usedCount }} / {{ record.monthlyLimit }}
          </div>
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              :disabled="record.status === 'active'"
              @click="handleReset(record)"
            >
              {{ t('ipinfoToken.reset') }}
            </a-button>
            <a-button type="text" size="small" @click="handleEdit(record)">
              {{ t('ipinfoToken.edit') }}
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="handleDelete(record)"
            >
              {{ t('ipinfoToken.delete') }}
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 创建/编辑Token模态框 -->
    <a-modal
      v-model:visible="showCreateModal"
      :title="isEditing ? t('ipinfoToken.edit') : t('ipinfoToken.create')"
      :width="600"
      :confirm-loading="submitLoading"
      @before-ok="handleBeforeOk"
      @cancel="handleCancel"
    >
      <a-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-align="left"
        :label-col-props="{ span: 6 }"
        :wrapper-col-props="{ span: 18 }"
      >
        <a-form-item field="name" :label="t('ipinfoToken.name.label')" required>
          <a-input
            v-model="form.name"
            :placeholder="t('ipinfoToken.name.placeholder')"
            maxlength="50"
            show-word-limit
          />
        </a-form-item>

        <a-form-item field="token" :label="t('ipinfoToken.token.label')" required>
          <a-input
            v-model="form.token"
            :placeholder="t('ipinfoToken.token.placeholder')"
            maxlength="200"
            show-word-limit
          />
        </a-form-item>

        <a-form-item
          field="monthlyLimit"
          :label="t('ipinfoToken.monthlyLimit.label')"
        >
          <a-input-number
            v-model="form.monthlyLimit"
            :min="1000"
            :max="100000"
            :step="1000"
            :placeholder="t('ipinfoToken.monthlyLimit.placeholder')"
          />
          <template #help>
            {{ t('ipinfoToken.monthlyLimit.help') }}
          </template>
        </a-form-item>

        <a-form-item
          v-if="isEditing"
          field="status"
          :label="t('ipinfoToken.status.label')"
        >
          <a-select
            v-model="form.status"
            :placeholder="t('ipinfoToken.status.placeholder')"
          >
            <a-option value="active">{{
              t('ipinfoToken.status.active')
            }}</a-option>
            <a-option value="exhausted">{{
              t('ipinfoToken.status.exhausted')
            }}</a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted, computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { Message, Modal } from '@arco-design/web-vue';
  import axios from 'axios';
  import type { AxiosRequestConfig } from 'axios';
  import { resolveHttpErrorMessage } from '@/utils/i18n';

  import Breadcrumb from '@/components/breadcrumb/index.vue';

  interface TokenItem {
    id: string;
    name: string;
    token: string;
    monthlyLimit: number;
    usedCount: number;
    resetDate: string;
    status: string;
    lastUsedAt?: string;
    createdAt: string;
    updatedAt: string;
  }

  interface TokenForm {
    name: string;
    token: string;
    monthlyLimit: number;
    status: string;
  }

  type AdminRequestConfig = AxiosRequestConfig & {
    suppressGlobalErrorMessage?: boolean;
  };

  const { t } = useI18n();
  const loading = ref(false);
  const submitLoading = ref(false);
  const showCreateModal = ref(false);
  const isEditing = ref(false);
  const currentEditId = ref('');
  const tokenList = ref<TokenItem[]>([]);
  const total = ref(0);
  const searchKeyword = ref('');
  const currentPage = ref(1);
  const pageSize = ref(10);
  const requestConfig: AdminRequestConfig = {
    suppressGlobalErrorMessage: true,
  };

  const pagination = computed(() => ({
    current: currentPage.value,
    pageSize: pageSize.value,
    total: total.value,
    showTotal: true,
    showJumper: true,
    showPageSize: true,
    pageSizeOptions: [10, 20, 50],
  }));

  const form = reactive<TokenForm>({
    name: '',
    token: '',
    monthlyLimit: 50000,
    status: 'active',
  });

  const formRef = ref();

  const rules = computed(() => ({
    name: [
      { required: true, message: t('ipinfoToken.validation.name.required') },
      { maxLength: 50, message: t('ipinfoToken.validation.name.maxLength') },
    ],
    token: [
      { required: true, message: t('ipinfoToken.validation.token.required') },
      { maxLength: 200, message: t('ipinfoToken.validation.token.maxLength') },
    ],
    monthlyLimit: [
      {
        required: true,
        message: t('ipinfoToken.validation.monthlyLimit.required'),
      },
      {
        type: 'number',
        min: 1000,
        max: 100000,
        message: t('ipinfoToken.validation.monthlyLimit.range'),
      },
    ],
  }));

  const columns = computed(() => [
    {
      title: t('ipinfoToken.table.name'),
      dataIndex: 'name',
      width: 200,
      ellipsis: true,
    },
    {
      title: t('ipinfoToken.table.token'),
      dataIndex: 'token',
      width: 300,
      ellipsis: true,
    },
    {
      title: t('ipinfoToken.table.usage'),
      slotName: 'usage',
      width: 180,
    },
    {
      title: t('ipinfoToken.table.status'),
      slotName: 'status',
      width: 100,
    },
    {
      title: t('ipinfoToken.table.resetDate'),
      dataIndex: 'resetDate',
      width: 140,
    },
    {
      title: t('ipinfoToken.table.lastUsed'),
      dataIndex: 'lastUsedAt',
      width: 180,
    },
    {
      title: t('ipinfoToken.table.createdAt'),
      dataIndex: 'createdAt',
      width: 180,
    },
    {
      title: t('ipinfoToken.table.actions'),
      slotName: 'actions',
      width: 220,
      fixed: 'right' as const,
    },
  ]);

  const fetchTokenList = async (keyword?: string) => {
    try {
      loading.value = true;
      const response = await axios.get('/api/admin/ipinfo-tokens', {
        ...requestConfig,
        params: {
          page: currentPage.value,
          page_size: pageSize.value,
          search: keyword,
        },
      });
      tokenList.value = response.data.list;
      total.value = response.data.total;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackKey: 'ipinfoToken.error.fetch',
          fallbackMessage: t('ipinfoToken.error.fetch'),
        })
      );
    } finally {
      loading.value = false;
    }
  };

  const resetForm = () => {
    form.name = '';
    form.token = '';
    form.monthlyLimit = 50000;
    form.status = 'active';
    isEditing.value = false;
    currentEditId.value = '';
    formRef.value?.resetFields();
  };

  const handleSearch = (value: string) => {
    currentPage.value = 1;
    fetchTokenList(value);
  };

  const handleSearchClear = () => {
    searchKeyword.value = '';
    currentPage.value = 1;
    fetchTokenList();
  };

  const handleRefresh = () => {
    fetchTokenList(searchKeyword.value || undefined);
  };

  const handlePageChange = (page: number, size: number) => {
    currentPage.value = page;
    pageSize.value = size;
    fetchTokenList(searchKeyword.value || undefined);
  };

  const handleCreate = async () => {
    await axios.post('/api/admin/ipinfo-tokens', form, requestConfig);
    Message.success(t('ipinfoToken.success.create'));
    showCreateModal.value = false;
    resetForm();
    fetchTokenList(searchKeyword.value || undefined);
  };

  const handleUpdate = async () => {
    await axios.patch(
      `/api/admin/ipinfo-tokens/${currentEditId.value}`,
      form,
      requestConfig
    );
    Message.success(t('ipinfoToken.success.update'));
    showCreateModal.value = false;
    resetForm();
    fetchTokenList(searchKeyword.value || undefined);
  };

  const handleBeforeOk = async (done: (closed: boolean) => void) => {
    if (!formRef.value) {
      done(false);
      return;
    }

    try {
      const errors = await formRef.value.validate();
      if (errors) {
        done(false);
        return;
      }
    } catch (error) {
      done(false);
      return;
    }

    try {
      submitLoading.value = true;
      if (isEditing.value) {
        await handleUpdate();
      } else {
        await handleCreate();
      }
      done(true);
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackKey:
            isEditing.value
              ? 'ipinfoToken.error.update'
              : 'ipinfoToken.error.create',
          fallbackMessage: t('ipinfoToken.error.submit'),
        })
      );
      done(false);
    } finally {
      submitLoading.value = false;
    }
  };

  const handleEdit = (record: TokenItem) => {
    isEditing.value = true;
    currentEditId.value = record.id;
    form.name = record.name;
    form.token = record.token;
    form.monthlyLimit = record.monthlyLimit;
    form.status = record.status;
    showCreateModal.value = true;
  };

  const handleDelete = (record: TokenItem) => {
    Modal.confirm({
      title: t('ipinfoToken.confirm.delete.title'),
      content: t('ipinfoToken.confirm.delete', { name: record.name }),
      okText: t('ipinfoToken.confirm.delete.okText'),
      cancelText: t('ipinfoToken.confirm.cancel'),
      okButtonProps: { status: 'danger' },
      onOk: async () => {
        try {
          await axios.delete(`/api/admin/ipinfo-tokens/${record.id}`, requestConfig);
          Message.success(t('ipinfoToken.success.delete'));
          fetchTokenList(searchKeyword.value || undefined);
        } catch (error: any) {
          Message.error(
            resolveHttpErrorMessage(error, {
              fallbackKey: 'ipinfoToken.error.delete',
              fallbackMessage: t('ipinfoToken.error.delete'),
            })
          );
        }
      },
    });
  };

  const handleReset = async (record: TokenItem) => {
    try {
      await axios.post(
        `/api/admin/ipinfo-tokens/${record.id}/reset`,
        undefined,
        requestConfig
      );
      Message.success(t('ipinfoToken.success.reset'));
      fetchTokenList(searchKeyword.value || undefined);
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackKey: 'ipinfoToken.error.reset',
          fallbackMessage: t('ipinfoToken.error.reset'),
        })
      );
    }
  };

  const handleCancel = () => {
    showCreateModal.value = false;
    resetForm();
  };

  onMounted(() => {
    fetchTokenList();
  });
</script>

<style lang="less" scoped>
  .ipinfo-token-container {
    padding: 0 20px 20px;
  }

  .actions {
    margin-bottom: 16px;
  }

  .token-card {
    margin-top: 16px;
  }

  .usage-text {
    margin-top: 4px;
    color: #666;
    font-size: 12px;
    text-align: center;
  }

  :deep(.arco-table-th) {
    background-color: #f5f5f5;
  }

  :deep(.arco-table-td) {
    vertical-align: middle;
  }
</style>
