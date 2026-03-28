<template>
  <div class="data-cleanup-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.dataCleanup']" />

    <div class="warning-banner">
      <a-alert type="warning" :closable="false">
        <template #icon>
          <icon-warning />
        </template>
        <template #title>{{ t('dataCleanup.warning.title') }}</template>
        {{ t('dataCleanup.warning.message') }}
      </a-alert>
    </div>

    <a-card class="cleanup-card" :title="t('dataCleanup.title')" :bordered="false">
      <div class="cleanup-section">
        <div class="section-header">
          <h3>{{ t('dataCleanup.section.title') }}</h3>
          <p class="section-description">{{ t('dataCleanup.section.description') }}</p>
        </div>

        <a-form :model="cleanupForm" label-align="left" class="cleanup-form">
          <a-form-item>
            <a-checkbox v-model="cleanupForm.confirmText">
              {{ t('dataCleanup.confirmCheckbox') }}
            </a-checkbox>
          </a-form-item>

          <a-form-item>
            <a-input
              v-model="cleanupForm.confirmationInput"
              :placeholder="t('dataCleanup.confirmInput.placeholder')"
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
                {{ t('dataCleanup.run') }}
              </a-button>
              <a-button @click="handleReset">{{ t('dataCleanup.reset') }}</a-button>
            </a-space>
          </a-form-item>
        </a-form>

        <a-divider />

        <div class="cleanup-details">
          <h4>{{ t('dataCleanup.tableList.title') }}</h4>
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
      :title="t('dataCleanup.modal.title')"
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
          <template #title>{{ t('dataCleanup.modal.finalTitle') }}</template>
          {{ t('dataCleanup.modal.finalMessage') }}
        </a-alert>

        <a-descriptions :column="1" size="small" bordered>
          <a-descriptions-item :label="t('dataCleanup.modal.tableCount')">
            {{ cleanupTables.length }} {{ t('dataCleanup.modal.countUnit') }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('dataCleanup.modal.affectedUsers')">
            {{ t('dataCleanup.modal.allUsers') }}
          </a-descriptions-item>
          <a-descriptions-item
            :label="t('dataCleanup.modal.affectedMessages')"
          >
            {{ t('dataCleanup.modal.allMessages') }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('dataCleanup.modal.affectedGroups')">
            {{ t('dataCleanup.modal.allGroups') }}
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
  import { useI18n } from 'vue-i18n';
  import cleanupAllAppData from '@/api/data-cleanup';

  const { t } = useI18n();
  const { loading, setLoading } = useLoading(false);
  const showConfirmModal = ref(false);

  const cleanupForm = reactive({
    confirmText: false,
    confirmationInput: '',
  });

  const canCleanup = computed(() => {
    return (
      cleanupForm.confirmText &&
      cleanupForm.confirmationInput === t('dataCleanup.confirmPhrase')
    );
  });

  const cleanupTables = computed(() => [
    {
      name: 'users',
      description: t('dataCleanup.tables.users'),
    },
    {
      name: 'messages',
      description: t('dataCleanup.tables.messages'),
    },
    {
      name: 'rooms',
      description: t('dataCleanup.tables.rooms'),
    },
    {
      name: 'room_members',
      description: t('dataCleanup.tables.room_members'),
    },
    {
      name: 'friendships',
      description: t('dataCleanup.tables.friendships'),
    },
    {
      name: 'friend_requests',
      description: t('dataCleanup.tables.friend_requests'),
    },
    {
      name: 'user_friend_remarks',
      description: t('dataCleanup.tables.user_friend_remarks'),
    },
    {
      name: 'message_reads',
      description: t('dataCleanup.tables.message_reads'),
    },
    {
      name: 'message_parts',
      description: t('dataCleanup.tables.message_parts'),
    },
    {
      name: 'room_pins',
      description: t('dataCleanup.tables.room_pins'),
    },
    {
      name: 'user_room_pins',
      description: t('dataCleanup.tables.user_room_pins'),
    },
    {
      name: 'feedbacks',
      description: t('dataCleanup.tables.feedbacks'),
    },
    {
      name: 'user_roles',
      description: t('dataCleanup.tables.user_roles'),
    },
    {
      name: 'user_login_history',
      description: t('dataCleanup.tables.user_login_history'),
    },
    {
      name: 'user_geolocations',
      description: t('dataCleanup.tables.user_geolocations'),
    },
    {
      name: 'group_settings',
      description: t('dataCleanup.tables.group_settings'),
    },
    {
      name: 'group_announcements',
      description: t('dataCleanup.tables.group_announcements'),
    },
    {
      name: 'group_rules',
      description: t('dataCleanup.tables.group_rules'),
    },
    {
      name: 'join_requests',
      description: t('dataCleanup.tables.join_requests'),
    },
    {
      name: 'group_invitations',
      description: t('dataCleanup.tables.group_invitations'),
    },
    {
      name: 'group_admins',
      description: t('dataCleanup.tables.group_admins'),
    },
    {
      name: 'group_operation_logs',
      description: t('dataCleanup.tables.group_operation_logs'),
    },
    {
      name: 'group_mutes',
      description: t('dataCleanup.tables.group_mutes'),
    },
  ]);

  const handleReset = () => {
    cleanupForm.confirmText = false;
    cleanupForm.confirmationInput = '';
  };

  const handleCleanup = () => {
    if (!canCleanup.value) {
      Message.warning(t('dataCleanup.messages.confirmRequired'));
      return;
    }
    showConfirmModal.value = true;
  };

  const confirmCleanup = async () => {
    try {
      setLoading(true);
      await cleanupAllAppData();
      Message.success(t('dataCleanup.messages.success'));
      showConfirmModal.value = false;
      handleReset();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || t('dataCleanup.messages.error'));
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
