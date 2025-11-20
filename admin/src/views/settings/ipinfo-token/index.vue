<template>
  <div class="ipinfo-token-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.ipinfoToken']" />
    <a-card class="token-card" title="ipinfo.io Token 管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="showCreateModal = true">
          <template #icon>
            <icon-plus />
          </template>
          新增Token
        </a-button>
      </template>

      <!-- Token列表 -->
      <a-table
        :columns="columns"
        :data="tokenList"
        :loading="loading"
        :pagination="pagination"
        row-key="id"
        :scroll="{ x: 1200 }"
        @page-change="handlePageChange"
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
      :confirm-loading="submitLoading"
      @ok="handleSubmit"
      @cancel="handleCancel"
    >
      <a-form ref="formRef" :model="form" :rules="rules" layout="vertical">
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

  import Breadcrumb from '@/components/breadcrumb/index.vue';
  import { request } from '@/hooks/request';

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
      width: 150,
    },
    {
      title: 'Token值',
      dataIndex: 'token',
      width: 200,
      ellipsis: true,
    },
    {
      title: '月额度',
      slotName: 'usage',
      width: 150,
    },
    {
      title: '状态',
      slotName: 'status',
      width: 80,
    },
    {
      title: '重置日期',
      dataIndex: 'resetDate',
      width: 120,
    },
    {
      title: '最后使用',
      dataIndex: 'lastUsedAt',
      width: 160,
    },
    {
      title: '创建时间',
      dataIndex: 'createdAt',
      width: 160,
    },
    {
      title: '操作',
      slotName: 'actions',
      width: 180,
      fixed: 'right',
    },
  ];

  // 获取Token列表
  const fetchTokenList = async () => {
    try {
      loading.value = true;
      const response = await request.get('/api/admin/ipinfo-tokens', {
        params: {
          page: currentPage.value,
          page_size: pageSize.value,
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

  // 分页变化处理
  const handlePageChange = (page: number, size: number) => {
    currentPage.value = page;
    pageSize.value = size;
    fetchTokenList();
  };

  // 创建Token
  const handleCreate = async () => {
    try {
      submitLoading.value = true;
      await request.post('/api/admin/ipinfo-tokens', form);
      Message.success('创建Token成功');
      showCreateModal.value = false;
      resetForm();
      fetchTokenList();
    } catch (error: any) {
      Message.error(error.response?.data?.message || '创建Token失败');
    } finally {
      submitLoading.value = false;
    }
  };

  // 更新Token
  const handleUpdate = async () => {
    try {
      submitLoading.value = true;
      await request.patch(
        `/api/admin/ipinfo-tokens/${currentEditId.value}`,
        form
      );
      Message.success('更新Token成功');
      showCreateModal.value = false;
      resetForm();
      fetchTokenList();
    } catch (error: any) {
      Message.error(error.response?.data?.message || '更新Token失败');
    } finally {
      submitLoading.value = false;
    }
  };

  // 提交表单
  const handleSubmit = async () => {
    try {
      const valid = await formRef.value?.validate();
      if (!valid) return;

      if (isEditing.value) {
        await handleUpdate();
      } else {
        await handleCreate();
      }
    } catch (error) {
      // 验证错误已由表单处理
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
          await request.delete(`/api/admin/ipinfo-tokens/${record.id}`);
          Message.success('删除Token成功');
          fetchTokenList();
        } catch (error: any) {
          Message.error(error.response?.data?.message || '删除Token失败');
        }
      },
    });
  };

  // 重置Token使用量
  const handleReset = async (record: TokenItem) => {
    try {
      await request.post(`/api/admin/ipinfo-tokens/${record.id}/reset`);
      Message.success('重置Token使用量成功');
      fetchTokenList();
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
    .token-card {
      margin-top: 16px;
    }

    .usage-text {
      margin-top: 4px;
      color: #666;
      font-size: 12px;
      text-align: center;
    }
  }

  :deep(.arco-table-th) {
    background-color: #f5f5f5;
  }

  :deep(.arco-table-td) {
    vertical-align: middle;
  }
</style>
