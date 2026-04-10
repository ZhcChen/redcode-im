<template>
  <div class="data-cleanup-container">
    <Breadcrumb :items="['menu.operations', 'menu.operations.dataCleanup']" />

    <div class="warning-banner">
      <a-alert type="warning" :closable="false">
        <template #icon>
          <icon-warning />
        </template>
        <template #title>危险操作 - 仅限开发环境使用</template>
        此页面用于清理测试数据，请确保您正在开发环境中操作。清理操作将不可逆，请谨慎操作！
      </a-alert>
    </div>

    <a-card class="cleanup-card" title="数据清理" :bordered="false">
      <div class="cleanup-section">
        <div class="section-header">
          <h3>清理所有 App 用户相关数据</h3>
          <p class="section-description">
            此操作将删除所有用户相关的测试数据，包括用户、聊天记录、群组等
          </p>
        </div>

        <a-form :model="cleanupForm" label-align="left" class="cleanup-form">
          <a-form-item>
            <a-checkbox v-model="cleanupForm.confirmText">
              我已理解此操作的危险性，并确认要执行清理
            </a-checkbox>
          </a-form-item>

          <a-form-item>
            <a-input
              v-model="cleanupForm.confirmationInput"
              placeholder="请输入 '确认清理' 以继续"
            />
          </a-form-item>

          <a-form-item>
            <a-space>
              <a-button
                type="primary"
                status="danger"
                :loading="loading"
                :disabled="!canCleanup"
                @click="handleCleanup"
              >
                立即清理所有数据
              </a-button>
              <a-button @click="handleReset">重置</a-button>
            </a-space>
          </a-form-item>
        </a-form>

        <a-divider />

        <div class="cleanup-details">
          <h4>将要清理的数据表：</h4>
          <a-list
            :data-source="cleanupTables"
            bordered
            size="small"
            class="cleanup-table-list"
          >
            <template #item="{ item }">
              <a-list-item>
                <a-list-item-meta>
                  <template #title>{{ item.name }}</template>
                  <template #description>{{ item.description }}</template>
                </a-list-item-meta>
              </a-list-item>
            </template>
          </a-list>
        </div>
      </div>
    </a-card>

    <a-modal
      v-model:visible="showConfirmModal"
      title="确认清理操作"
      :mask-closable="false"
      :esc-to-close="false"
      @cancel="showConfirmModal = false"
      @ok="confirmCleanup"
    >
      <div class="confirm-content">
        <a-alert type="error" :closable="false" class="mb-16">
          <template #icon>
            <icon-danger />
          </template>
          <template #title>最后确认</template>
          您即将删除所有 App 用户相关数据，此操作不可恢复！
        </a-alert>

        <a-descriptions :column="1" size="small" bordered>
          <a-descriptions-item label="将清理的数据表数量">
            {{ cleanupTables.length }} 个
          </a-descriptions-item>
          <a-descriptions-item label="预计影响用户数">
            全部用户
          </a-descriptions-item>
          <a-descriptions-item label="预计影响消息数">
            全部消息
          </a-descriptions-item>
          <a-descriptions-item label="预计影响群组数">
            全部群组
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, computed, ref } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import cleanupAllAppData from '@/api/data-cleanup';

  const { loading, setLoading } = useLoading(false);
  const showConfirmModal = ref(false);

  const cleanupForm = reactive({
    confirmText: false,
    confirmationInput: '',
  });

  const canCleanup = computed(() => {
    return (
      cleanupForm.confirmText && cleanupForm.confirmationInput === '确认清理'
    );
  });

  const cleanupTables = [
    {
      name: 'users',
      description: '用户表 - 删除所有用户账户信息',
    },
    {
      name: 'messages',
      description: '消息表 - 删除所有聊天消息',
    },
    {
      name: 'rooms',
      description: '房间表 - 删除所有群组和私聊房间',
    },
    {
      name: 'room_members',
      description: '房间成员表 - 删除所有房间成员关系',
    },
    {
      name: 'friendships',
      description: '好友关系表 - 删除所有好友关系',
    },
    {
      name: 'friend_requests',
      description: '好友请求表 - 删除所有好友请求',
    },
    {
      name: 'user_friend_remarks',
      description: '好友备注表 - 删除所有好友备注',
    },
    {
      name: 'message_reads',
      description: '消息已读表 - 删除所有消息已读记录',
    },
    {
      name: 'message_parts',
      description: '消息分片表 - 删除所有消息分片',
    },
    {
      name: 'room_pins',
      description: '房间置顶表 - 删除所有房间置顶',
    },
    {
      name: 'user_room_pins',
      description: '用户房间置顶表 - 删除所有用户房间置顶',
    },
    {
      name: 'feedbacks',
      description: '用户反馈表 - 删除所有用户反馈',
    },
    {
      name: 'user_roles',
      description: '用户角色表 - 删除所有用户角色关联',
    },
    {
      name: 'user_login_history',
      description: '用户登录历史表 - 删除所有用户登录历史',
    },
    {
      name: 'user_geolocations',
      description: '用户地理位置表 - 删除所有用户地理位置',
    },
    {
      name: 'group_settings',
      description: '群设置表 - 删除所有群设置',
    },
    {
      name: 'group_announcements',
      description: '群公告表 - 删除所有群公告',
    },
    {
      name: 'group_rules',
      description: '群规则表 - 删除所有群规则',
    },
    {
      name: 'join_requests',
      description: '加群请求表 - 删除所有加群请求',
    },
    {
      name: 'group_invitations',
      description: '群邀请表 - 删除所有群邀请',
    },
    {
      name: 'group_admins',
      description: '群管理员表 - 删除所有群管理员',
    },
    {
      name: 'group_operation_logs',
      description: '群操作日志表 - 删除所有群操作日志',
    },
    {
      name: 'group_mutes',
      description: '群禁言表 - 删除所有群禁言记录',
    },
  ];

  const handleReset = () => {
    cleanupForm.confirmText = false;
    cleanupForm.confirmationInput = '';
  };

  const handleCleanup = () => {
    if (!canCleanup.value) {
      Message.warning('请先确认操作');
      return;
    }
    showConfirmModal.value = true;
  };

  const confirmCleanup = async () => {
    try {
      setLoading(true);
      await cleanupAllAppData();
      Message.success('数据清理完成');
      showConfirmModal.value = false;
      handleReset();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '清理失败，请重试');
    } finally {
      setLoading(false);
    }
  };
</script>

<style lang="less" scoped>
  .data-cleanup-container {
    padding: 0 20px 20px;
  }

  .warning-banner {
    margin-bottom: 16px;
  }

  .cleanup-card {
    margin-top: 16px;
  }

  .cleanup-section {
    padding: 16px 0;
  }

  .section-header {
    margin-bottom: 24px;

    h3 {
      margin-bottom: 8px;
      font-weight: 600;
      font-size: 16px;
    }
  }

  .section-description {
    color: rgb(var(--gray-6));
    font-size: 14px;
  }

  .cleanup-form {
    max-width: 600px;
    margin: 24px 0;
  }

  .cleanup-details {
    margin-top: 24px;

    h4 {
      margin-bottom: 12px;
      font-weight: 600;
      font-size: 14px;
    }
  }

  .cleanup-table-list {
    margin-top: 12px;
  }

  .confirm-content {
    .mb-16 {
      margin-bottom: 16px;
    }
  }
</style>
