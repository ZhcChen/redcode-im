<template>
  <div class="user-list-container">
    <Breadcrumb :items="['menu.userManagement', 'menu.userManagement.list']" />
    <a-card
      class="general-card"
      :title="t('userManagement.title')"
      :bordered="false"
    >
      <div class="header-actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            :placeholder="t('userManagement.list.search.placeholder')"
            style="width: 300px"
            @search="handleSearch"
          />
          <a-select
            v-model="selectedStatus"
            :placeholder="t('userManagement.list.status.placeholder')"
            style="width: 150px"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="active">{{
              t('userManagement.status.active')
            }}</a-option>
            <a-option value="inactive">{{
              t('userManagement.status.inactive')
            }}</a-option>
            <a-option value="banned">{{
              t('userManagement.status.banned')
            }}</a-option>
          </a-select>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            {{ t('userManagement.list.refresh') }}
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
              :status="record.status === 'banned' ? 'normal' : 'danger'"
              :disabled="Boolean(record.deleted_at)"
              @click="handleBanUser(record)"
            >
              {{ getActionText(record) }}
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
  import { useI18n } from 'vue-i18n';
  import dayjs from 'dayjs';
  import useLoading from '@/hooks/loading';
  import { Message, Modal } from '@arco-design/web-vue';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    getUserList,
    updateUserStatus,
    type UserInfo,
    type UserListParams,
  } from '@/api/user';

  const { loading, setLoading } = useLoading(true);
  const { t } = useI18n();

  const searchKeyword = ref('');
  const selectedStatus = ref<'' | UserInfo['status']>('');

  const userList = ref<UserInfo[]>([]);
  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
    showJumper: true,
  });

  const columns = computed(() => [
    {
      title: t('userManagement.list.avatar'),
      dataIndex: 'avatar_url',
      slotName: 'avatar',
      width: 80,
    },
    {
      title: t('userManagement.list.username'),
      dataIndex: 'username',
      width: 150,
    },
    {
      title: t('userManagement.list.nickname'),
      dataIndex: 'nickname',
      width: 150,
    },
    {
      title: t('userManagement.list.email'),
      dataIndex: 'email',
      width: 200,
    },
    {
      title: t('userManagement.list.status'),
      dataIndex: 'status',
      slotName: 'status',
      width: 110,
    },
    {
      title: t('userManagement.list.createdAt'),
      dataIndex: 'created_at',
      width: 180,
      slotName: 'datetime',
    },
    {
      title: t('userManagement.list.updatedAt'),
      dataIndex: 'updated_at',
      width: 180,
      slotName: 'datetime',
    },
    {
      title: t('userManagement.list.deletedAt'),
      dataIndex: 'deleted_at',
      width: 180,
      slotName: 'deletedAt',
    },
    {
      title: t('userManagement.list.actions'),
      slotName: 'actions',
      width: 180,
      fixed: 'right' as const,
    },
  ]);

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
      return t('userManagement.status.deleted');
    }
    switch (record.status) {
      case 'active':
        return t('userManagement.status.active');
      case 'inactive':
        return t('userManagement.status.inactive');
      case 'banned':
        return t('userManagement.status.banned');
      default:
        return t('userManagement.status.unknown');
    }
  };

  const getActionText = (record: UserInfo) => {
    return record.status === 'banned'
      ? t('userManagement.action.unban')
      : t('userManagement.action.ban');
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

      const { data } = await getUserList(params, {
        suppressGlobalErrorMessage: true,
      });
      if (data) {
        userList.value = data.users;
        pagination.total = data.total;
      }
    } catch (error: any) {
      userList.value = [];
      pagination.total = 0;
      console.error('[user-management] fetch failed', error?.response ?? error);
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackKey: 'userManagement.fetch.error',
          fallbackMessage: t('userManagement.fetch.error'),
        })
      );
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

  const handleBanUser = (user: UserInfo) => {
    if (user.deleted_at) {
      Message.info(t('userManagement.action.deletedLocked'));
      return;
    }

    const isBanned = user.status === 'banned';
    const action = getActionText(user);
    const newStatus = isBanned ? 'active' : 'banned';
    const hintKey = isBanned
      ? 'userManagement.confirm.unbanHint'
      : 'userManagement.confirm.banHint';

    Modal.confirm({
      title: t('userManagement.confirm.title'),
      content: t('userManagement.confirm.content', {
        action,
        username: user.username,
        hint: t(hintKey),
      }),
      okText: t('userManagement.confirm.okText', { action }),
      cancelText: t('userManagement.confirm.cancelText'),
      okButtonProps: { status: isBanned ? 'normal' : 'danger' },
      onOk: async () => {
        try {
          await updateUserStatus(user.id, newStatus, {
            suppressGlobalErrorMessage: true,
          });
          Message.success(
            t('userManagement.action.success', {
              action,
            })
          );
          await fetchData();
        } catch (error: any) {
          Message.error(
            resolveHttpErrorMessage(error, {
              fallbackKey:
                error?.response?.status === 404
                  ? 'userManagement.action.notFound'
                  : undefined,
              fallbackParams: {
                username: user.username,
              },
              fallbackMessage: t('userManagement.action.error', {
                action,
              }),
            })
          );
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
    padding: 0 20px 20px;

    .general-card {
      .header-actions {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 16px;
      }
    }
  }
</style>
