<template>
  <div class="user-list-container">
    <Breadcrumb :items="['menu.userManagement', 'menu.userManagement.list']" />
    <a-card class="general-card" title="用户管理" :bordered="false">
      <div class="header-actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            placeholder="搜索用户名"
            style="width: 300px"
            @search="handleSearch"
          />
          <a-select
            v-model="selectedStatus"
            placeholder="用户状态"
            style="width: 150px"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="active">正常</a-option>
            <a-option value="inactive">禁用</a-option>
            <a-option value="banned">已封禁</a-option>
          </a-select>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="userList"
        :columns="columns"
        :pagination="pagination"
        :loading="loading"
        row-key="id"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #avatar="{ record }">
          <a-avatar>
            <img
              v-if="record.avatar_url"
              :src="record.avatar_url"
              alt="avatar"
            />
            <icon-user v-else />
          </a-avatar>
        </template>

        <template #status="{ record }">
          <a-tag :color="getStatusColor(record)">
            {{ getStatusText(record) }}
          </a-tag>
        </template>

        <template #datetime="{ record, column }">
          <span>{{ formatDate(record[column.dataIndex]) }}</span>
        </template>

        <template #deletedAt="{ record }">
          <span>
            {{ record.deleted_at ? formatDate(record.deleted_at) : '-' }}
          </span>
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              :disabled="Boolean(record.deleted_at)"
              @click="
                handleUpdateStatus(
                  record,
                  record.status === 'active' ? 'inactive' : 'active'
                )
              "
            >
              {{ record.status === 'active' ? '禁用' : '启用' }}
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              :disabled="Boolean(record.deleted_at)"
              @click="handleBanUser(record)"
            >
              封禁
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import dayjs from 'dayjs';
  import useLoading from '@/hooks/loading';
  import { Message, Modal } from '@arco-design/web-vue';
  import {
    getUserList,
    updateUserStatus,
    type UserInfo,
    type UserListParams,
  } from '@/api/user';

  const { loading, setLoading } = useLoading(true);

  const searchKeyword = ref('');
  const selectedStatus = ref('');

  const userList = ref<UserInfo[]>([]);
  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
    showJumper: true,
  });

  const columns = [
    {
      title: '头像',
      dataIndex: 'avatar_url',
      slotName: 'avatar',
      width: 80,
    },
    {
      title: '用户名',
      dataIndex: 'username',
      width: 150,
    },
    {
      title: '昵称',
      dataIndex: 'nickname',
      width: 150,
    },
    {
      title: '邮箱',
      dataIndex: 'email',
      width: 200,
    },
    {
      title: '状态',
      dataIndex: 'status',
      slotName: 'status',
      width: 110,
    },
    {
      title: '注册时间',
      dataIndex: 'created_at',
      width: 180,
      slotName: 'datetime',
    },
    {
      title: '最后更新',
      dataIndex: 'updated_at',
      width: 180,
      slotName: 'datetime',
    },
    {
      title: '注销时间',
      dataIndex: 'deleted_at',
      width: 180,
      slotName: 'deletedAt',
    },
    {
      title: '操作',
      slotName: 'actions',
      width: 180,
      fixed: 'right',
    },
  ];

  const getStatusColor = (record: UserInfo): string => {
    if (record.deleted_at) {
      return 'gray';
    }
    switch (record.status) {
      case 'active':
        return 'green';
      case 'inactive':
        return 'orange';
      case 'banned':
        return 'red';
      default:
        return 'gray';
    }
  };

  const getStatusText = (record: UserInfo): string => {
    if (record.deleted_at) {
      return '已注销';
    }
    switch (record.status) {
      case 'active':
        return '正常';
      case 'inactive':
        return '禁用';
      case 'banned':
        return '已封禁';
      default:
        return '未知';
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const params: UserListParams = {
        page: pagination.current,
        pageSize: pagination.pageSize,
        username: searchKeyword.value || undefined,
        status: selectedStatus.value || undefined,
      };

      const { data } = await getUserList(params);
      if (data) {
        userList.value = data.users;
        pagination.total = data.total;
      }
    } catch (error) {
      userList.value = [];
      pagination.total = 0;
      Message.error('获取用户列表失败');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    pagination.current = 1;
    fetchData();
  };

  const handleRefresh = () => {
    fetchData();
  };

  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchData();
  };

  const handlePageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    pagination.current = 1;
    fetchData();
  };

  const handleUpdateStatus = async (
    user: UserInfo,
    status: 'active' | 'inactive'
  ) => {
    if (user.deleted_at) {
      Message.info('已注销账号无法变更状态');
      return;
    }
    try {
      await updateUserStatus(user.id, status);
      Message.success('操作成功');
      await fetchData();
    } catch (error) {
      Message.error('操作失败，请重试');
    }
  };

  const handleBanUser = (user: UserInfo) => {
    if (user.deleted_at) {
      Message.info('已注销账号无法封禁');
      return;
    }

    Modal.confirm({
      title: '确认操作',
      content: `确定要封禁用户 "${user.username}" 吗？封禁后用户将无法登录系统。`,
      okText: '确认封禁',
      cancelText: '取消',
      okButtonProps: { status: 'danger' },
      onOk: async () => {
        try {
          await updateUserStatus(user.id, 'banned');
          Message.success('操作成功');
          await fetchData();
        } catch (error) {
          Message.error('操作失败，请重试');
        }
      },
    });
  };

  onMounted(() => {
    fetchData();
  });

  const formatDate = (value?: string) => {
    if (!value) return '-';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };
</script>

<style lang="less" scoped>
  .user-list-container {
    padding: 0 20px 20px 20px;

    .general-card {
      .header-actions {
        margin-bottom: 16px;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
    }
  }
</style>
