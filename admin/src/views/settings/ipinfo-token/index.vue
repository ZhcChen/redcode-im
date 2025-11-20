<template>
  <div class="ipinfo-token-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.ipinfoToken']" />
    <a-card class="general-card" title="ipinfo.io Token 管理" :bordered="false">
      <div class="actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            placeholder="搜索Token名称"
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
            新增Token
          </a-button>
          <a-button :loading="loading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
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
            {{ record.status === 'active' ? '可用' : '已耗尽' }}
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
              重置
            </a-button>
            <a-button type="text" size="small" @click="handleEdit(record)">
              编辑
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="handleDelete(record)"
            >
              删除
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 创建/编辑Token模态框 -->
    <a-modal
      v-model:visible="showCreateModal"
      :title="isEditing ? '编辑Token' : '新增Token'"
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
        <a-form-item field="name" label="Token名称" required>
          <a-input
            v-model="form.name"
            placeholder="请输入Token名称"
            maxlength="50"
            show-word-limit
          />
        </a-form-item>

        <a-form-item field="token" label="Token值" required>
          <a-input
            v-model="form.token"
            placeholder="请输入ipinfo.io Token"
            maxlength="200"
            show-word-limit
          />
        </a-form-item>

        <a-form-item field="monthlyLimit" label="月额度限制">
          <a-input-number
            v-model="form.monthlyLimit"
            :min="1000"
            :max="100000"
            :step="1000"
            placeholder="请输入月额度限制"
          />
          <template #help> ipinfo.io的月调用额度，默认50000次 </template>
        </a-form-item>

        <a-form-item v-if="isEditing" field="status" label="状态">
          <a-select v-model="form.status" placeholder="请选择状态">
            <a-option value="active">可用</a-option>
            <a-option value="exhausted">已耗尽</a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted, computed } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import { IconPlus } from '@arco-design/web-vue/es/icon';
  import axios from 'axios';

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

  // 响应式数据
  const loading = ref(false);
  const submitLoading = ref(false);
  const showCreateModal = ref(false);
  const isEditing = ref(false);
  const currentEditId = ref('');
  const tokenList = ref<TokenItem[]>([]);
  const total = ref(0);
  const searchKeyword = ref('');

  // 分页配置
  const currentPage = ref(1);
  const pageSize = ref(10);

  const pagination = computed(() => ({
    current: currentPage.value,
    pageSize: pageSize.value,
    total: total.value,
    showTotal: true,
    showJumper: true,
    showPageSize: true,
    pageSizeOptions: [10, 20, 50],
  }));

  // 表单数据
  const form = reactive<TokenForm>({
    name: '',
    token: '',
    monthlyLimit: 50000,
    status: 'active',
  });

  const formRef = ref();

  // 表单验证规则
  const rules = {
    name: [
      { required: true, message: '请输入Token名称' },
      { maxLength: 50, message: 'Token名称不能超过50个字符' },
    ],
    token: [
      { required: true, message: '请输入Token值' },
      { maxLength: 200, message: 'Token值不能超过200个字符' },
    ],
    monthlyLimit: [
      { required: true, message: '请输入月额度限制' },
      {
        type: 'number',
        min: 1000,
        max: 100000,
        message: '月额度限制应在1000-100000之间',
      },
    ],
  };

  // 表格列配置
  const columns = [
    {
      title: 'Token名称',
      dataIndex: 'name',
      width: 200,
      ellipsis: true,
    },
    {
      title: 'Token值',
      dataIndex: 'token',
      width: 300,
      ellipsis: true,
    },
    {
      title: '月额度',
      slotName: 'usage',
      width: 180,
    },
    {
      title: '状态',
      slotName: 'status',
      width: 100,
    },
    {
      title: '重置日期',
      dataIndex: 'resetDate',
      width: 140,
    },
    {
      title: '最后使用',
      dataIndex: 'lastUsedAt',
      width: 180,
    },
    {
      title: '创建时间',
      dataIndex: 'createdAt',
      width: 180,
    },
    {
      title: '操作',
      slotName: 'actions',
      width: 220,
      fixed: 'right',
    },
  ];

  // 获取Token列表
  const fetchTokenList = async (keyword?: string) => {
    try {
      loading.value = true;
      const response = await axios.get('/api/admin/ipinfo-tokens', {
        params: {
          page: currentPage.value,
          page_size: pageSize.value,
          search: keyword,
        },
      });
      tokenList.value = response.data.list;
      total.value = response.data.total;
    } catch (error) {
      Message.error('获取Token列表失败');
    } finally {
      loading.value = false;
    }
  };

  // 重置表单
  const resetForm = () => {
    form.name = '';
    form.token = '';
    form.monthlyLimit = 50000;
    form.status = 'active';
    isEditing.value = false;
    currentEditId.value = '';
    formRef.value?.resetFields();
  };

  // 搜索处理
  const handleSearch = (value: string) => {
    currentPage.value = 1;
    fetchTokenList(value);
  };

  // 清除搜索
  const handleSearchClear = () => {
    searchKeyword.value = '';
    currentPage.value = 1;
    fetchTokenList();
  };

  // 刷新
  const handleRefresh = () => {
    fetchTokenList(searchKeyword.value || undefined);
  };

  // 分页变化处理
  const handlePageChange = (page: number, size: number) => {
    currentPage.value = page;
    pageSize.value = size;
    fetchTokenList(searchKeyword.value || undefined);
  };

  // 创建Token
  const handleCreate = async () => {
    await axios.post('/api/admin/ipinfo-tokens', form);
    Message.success('创建Token成功');
    showCreateModal.value = false;
    resetForm();
    fetchTokenList(searchKeyword.value || undefined);
  };

  // 更新Token
  const handleUpdate = async () => {
    await axios.patch(`/api/admin/ipinfo-tokens/${currentEditId.value}`, form);
    Message.success('更新Token成功');
    showCreateModal.value = false;
    resetForm();
    fetchTokenList(searchKeyword.value || undefined);
  };

  // 表单提交前验证
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
      Message.error(error.response?.data?.message || '操作失败');
      done(false);
    } finally {
      submitLoading.value = false;
    }
  };

  // 编辑Token
  const handleEdit = (record: TokenItem) => {
    isEditing.value = true;
    currentEditId.value = record.id;
    form.name = record.name;
    form.token = record.token;
    form.monthlyLimit = record.monthlyLimit;
    form.status = record.status;
    showCreateModal.value = true;
  };

  // 删除Token
  const handleDelete = (record: TokenItem) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除Token "${record.name}" 吗？此操作不可恢复。`,
      okText: '确认删除',
      cancelText: '取消',
      okButtonProps: { status: 'danger' },
      onOk: async () => {
        try {
          await axios.delete(`/api/admin/ipinfo-tokens/${record.id}`);
          Message.success('删除Token成功');
          fetchTokenList(searchKeyword.value || undefined);
        } catch (error: any) {
          Message.error(error.response?.data?.message || '删除Token失败');
        }
      },
    });
  };

  // 重置Token使用量
  const handleReset = async (record: TokenItem) => {
    try {
      await axios.post(`/api/admin/ipinfo-tokens/${record.id}/reset`);
      Message.success('重置Token使用量成功');
      fetchTokenList(searchKeyword.value || undefined);
    } catch (error: any) {
      Message.error('重置Token使用量失败');
    }
  };

  // 取消操作
  const handleCancel = () => {
    showCreateModal.value = false;
    resetForm();
  };

  // 组件挂载时获取数据
  onMounted(() => {
    fetchTokenList();
  });
</script>

<style lang="less" scoped>
  .ipinfo-token-container {
    padding: 0 20px 20px;
  }

  .general-card {
    margin-top: 16px;
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
