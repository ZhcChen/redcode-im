<template>
  <div class="push-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.push']" />

    <a-card
      class="general-card"
      :title="t('settingsPush.title')"
      :bordered="false"
    >
      <a-spin :loading="loading" :tip="t('settingsPush.loading')">
        <div v-if="!loading" class="push-settings">
          <a-alert
            type="info"
            show-icon
            :closable="false"
            :title="t('settingsPush.tip.title')"
          >
            <template #default>
              <div class="hint">
                {{ t('settingsPush.tip.content') }}
              </div>
            </template>
          </a-alert>

          <div class="section">
            <h3 class="section-title">{{ t('settingsPush.section.global') }}</h3>
            <a-form layout="vertical">
              <a-form-item :label="t('settingsPush.global.enabled')">
                <a-switch v-model="globalForm.enabled" />
              </a-form-item>
              <a-form-item :label="t('settingsPush.global.skipIfOnline')">
                <a-switch v-model="globalForm.skip_if_online" />
              </a-form-item>
            </a-form>
            <a-space>
              <a-button
                type="primary"
                :loading="savingGlobal"
                @click="handleSaveGlobal"
              >
                {{ t('settingsPush.action.saveGlobal') }}
              </a-button>
              <a-button
                :disabled="savingGlobal || savingFcm"
                @click="fetchData"
              >
                {{ t('settingsPush.action.refresh') }}
              </a-button>
              <a-button @click="handleOpenPushLogs">
                {{ t('settingsPush.action.viewLogs') }}
              </a-button>
            </a-space>
          </div>

          <a-divider />

          <div class="section">
            <h3 class="section-title">{{ t('settingsPush.section.queue') }}</h3>
            <a-alert
              type="warning"
              show-icon
              :closable="false"
              :title="t('settingsPush.queue.tip.title')"
            >
              <template #default>
                <div class="hint">
                  {{ t('settingsPush.queue.tip.content') }}
                </div>
              </template>
            </a-alert>

            <a-descriptions
              :column="2"
              size="small"
              bordered
              style="margin-top: 12px"
            >
              <a-descriptions-item :label="t('settingsPush.queue.pending')">
                {{ queueStats?.pending ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item :label="t('settingsPush.queue.retry')">
                {{ queueStats?.retry ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item :label="t('settingsPush.queue.due')">
                {{ queueStats?.due ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item :label="t('settingsPush.queue.failed')">
                {{ queueStats?.failed ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item :label="t('settingsPush.queue.done')">
                {{ queueStats?.done ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item :label="t('settingsPush.queue.nextRunAt')">
                {{ formatTime(queueStats?.next_run_at ?? undefined) }}
              </a-descriptions-item>
              <a-descriptions-item
                :label="t('settingsPush.queue.oldestCreatedAt')"
              >
                {{ formatTime(queueStats?.oldest_created_at ?? undefined) }}
              </a-descriptions-item>
            </a-descriptions>

            <a-space style="margin-top: 12px">
              <a-button :loading="loadingQueueStats" @click="fetchQueueStats">
                {{ t('settingsPush.action.refreshQueue') }}
              </a-button>
            </a-space>
          </div>

          <a-divider />

          <div class="section">
            <h3 class="section-title">
              {{ t('settingsPush.section.providers') }}
            </h3>

            <a-card
              class="provider-card"
              :title="t('settingsPush.provider.fcm.title')"
            >
              <a-form layout="vertical">
                <a-form-item :label="t('settingsPush.provider.fcm.enabled')">
                  <a-switch v-model="fcmForm.enabled" />
                </a-form-item>

                <a-form-item
                  :label="t('settingsPush.provider.fcm.currentConfig')"
                >
                  <a-descriptions :column="1" size="small" bordered>
                    <a-descriptions-item
                      :label="t('settingsPush.provider.fcm.status')"
                    >
                      <a-tag :color="fcmMeta?.enabled ? 'green' : 'gray'">
                        {{
                          fcmMeta?.enabled
                            ? t('settingsPush.provider.fcm.statusEnabled')
                            : t('settingsPush.provider.fcm.statusDisabled')
                        }}
                      </a-tag>
                      <a-tag
                        v-if="fcmMeta?.has_secret"
                        color="blue"
                        style="margin-left: 8px"
                      >
                        {{ t('settingsPush.provider.fcm.secretConfigured') }}
                      </a-tag>
                      <a-tag v-else color="gray" style="margin-left: 8px">
                        {{ t('settingsPush.provider.fcm.secretMissing') }}
                      </a-tag>
                    </a-descriptions-item>
                    <a-descriptions-item
                      :label="t('settingsPush.provider.fcm.projectId')"
                    >
                      {{ fcmProjectId }}
                    </a-descriptions-item>
                    <a-descriptions-item
                      :label="t('settingsPush.provider.fcm.clientEmail')"
                    >
                      {{ fcmClientEmail }}
                    </a-descriptions-item>
                    <a-descriptions-item
                      :label="t('settingsPush.provider.fcm.secretFingerprint')"
                    >
                      {{ fcmMeta?.secret_fingerprint || t('settingsPush.empty') }}
                    </a-descriptions-item>
                    <a-descriptions-item
                      :label="t('settingsPush.provider.fcm.lastUpdated')"
                    >
                      {{ formatTime(fcmMeta?.updated_at) }}
                    </a-descriptions-item>
                  </a-descriptions>
                </a-form-item>

                <a-form-item
                  :label="t('settingsPush.provider.fcm.jsonLabel')"
                >
                  <a-textarea
                    v-model="fcmForm.service_account_json"
                    :auto-size="{ minRows: 6, maxRows: 12 }"
                    :placeholder="t('settingsPush.provider.fcm.jsonPlaceholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-form>

              <a-space>
                <a-button
                  type="primary"
                  :loading="savingFcm"
                  @click="handleSaveFcm"
                >
                  {{ t('settingsPush.action.saveFcm') }}
                </a-button>
                <a-button @click="openTestModal">
                  {{ t('settingsPush.action.testSend') }}
                </a-button>
              </a-space>
            </a-card>
          </div>
        </div>
      </a-spin>
    </a-card>

    <a-modal
      v-model:visible="testModalVisible"
      :title="t('settingsPush.modal.title')"
      :ok-loading="testing"
      :mask-closable="false"
      @ok="handleTestSend"
    >
      <a-form layout="vertical">
        <a-form-item :label="t('settingsPush.modal.deviceToken.label')">
          <a-input
            v-model="testForm.device_token"
            allow-clear
            :placeholder="t('settingsPush.modal.deviceToken.placeholder')"
          />
        </a-form-item>
        <a-form-item :label="t('settingsPush.modal.userId.label')">
          <a-input
            v-model="testForm.user_id"
            allow-clear
            :placeholder="t('settingsPush.modal.userId.placeholder')"
          />
        </a-form-item>
        <a-form-item :label="t('settingsPush.modal.notificationTitle.label')">
          <a-input v-model="testForm.title" allow-clear />
        </a-form-item>
        <a-form-item :label="t('settingsPush.modal.notificationBody.label')">
          <a-textarea
            v-model="testForm.body"
            :auto-size="{ minRows: 3, maxRows: 6 }"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { useRouter } from 'vue-router';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    getPushSettings,
    getPushJobQueueStats,
    testPush,
    updatePushSettings,
    upsertPushProviderConfig,
    type PushProviderConfigView,
    type PushJobQueueStatsResponse,
  } from '@/api/settings';

  const router = useRouter();
  const { t } = useI18n();

  const globalForm = reactive({
    enabled: true,
    skip_if_online: true,
  });

  const providers = ref<PushProviderConfigView[]>([]);

  const fcmMeta = computed(() => {
    return (
      providers.value.find(
        (p) => p.provider === 'fcm' && (p.platform === 'all' || !p.platform)
      ) ?? null
    );
  });

  const fcmProjectId = computed(() => {
    const v = fcmMeta.value?.config_public?.project_id;
    return typeof v === 'string' && v.trim()
      ? v
      : t('settingsPush.notConfigured');
  });

  const fcmClientEmail = computed(() => {
    const v = fcmMeta.value?.config_public?.client_email;
    return typeof v === 'string' && v.trim()
      ? v
      : t('settingsPush.notConfigured');
  });

  const fcmForm = reactive({
    enabled: false,
    service_account_json: '',
  });

  const queueStats = ref<PushJobQueueStatsResponse | null>(null);
  const loadingQueueStats = ref(false);

  const { loading, setLoading } = useLoading(true);
  const savingGlobal = ref(false);
  const savingFcm = ref(false);

  const testModalVisible = ref(false);
  const testing = ref(false);
  const testForm = reactive({
    device_token: '',
    user_id: '',
    title: t('settingsPush.modal.defaultTitle'),
    body: t('settingsPush.modal.defaultBody'),
  });

  const formatTime = (value?: string) => {
    if (!value) return t('settingsPush.empty');
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

  const fetchQueueStats = async () => {
    loadingQueueStats.value = true;
    try {
      const { data } = await getPushJobQueueStats();
      queueStats.value = data;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsPush.fetchQueue.error'),
        })
      );
    } finally {
      loadingQueueStats.value = false;
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const [settingsResp] = await Promise.all([
        getPushSettings(),
        fetchQueueStats().catch(() => {}),
      ]);

      const { data } = settingsResp;
      globalForm.enabled = data.enabled;
      globalForm.skip_if_online = data.skip_if_online;
      providers.value = data.providers ?? [];

      fcmForm.enabled = fcmMeta.value?.enabled ?? false;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsPush.fetch.error'),
        })
      );
    } finally {
      setLoading(false);
    }
  };

  const handleSaveGlobal = async () => {
    savingGlobal.value = true;
    try {
      const { data } = await updatePushSettings({
        enabled: globalForm.enabled,
        skip_if_online: globalForm.skip_if_online,
      });
      globalForm.enabled = data.enabled;
      globalForm.skip_if_online = data.skip_if_online;
      providers.value = data.providers ?? [];
      Message.success(t('settingsPush.save.success'));
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsPush.save.error'),
        })
      );
    } finally {
      savingGlobal.value = false;
    }
  };

  const handleSaveFcm = async () => {
    const hasExistingSecret = fcmMeta.value?.has_secret === true;
    const hasNewSecret =
      fcmForm.service_account_json &&
      fcmForm.service_account_json.trim() !== '';

    if (fcmForm.enabled && !hasExistingSecret && !hasNewSecret) {
      Message.warning(t('settingsPush.validation.requireJson'));
      return;
    }

    savingFcm.value = true;
    try {
      const payload: Record<string, any> = {
        enabled: fcmForm.enabled,
      };
      if (hasNewSecret) {
        payload.service_account_json = fcmForm.service_account_json;
      }
      await upsertPushProviderConfig('fcm', payload);

      fcmForm.service_account_json = '';
      await fetchData();
      Message.success(t('settingsPush.save.success'));
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsPush.save.providerError'),
        })
      );
    } finally {
      savingFcm.value = false;
    }
  };

  const handleOpenPushLogs = () => {
    router.push({ name: 'PushLog' });
  };

  const openTestModal = () => {
    testModalVisible.value = true;
  };

  const handleTestSend = async () => {
    const deviceToken = testForm.device_token.trim();
    const userId = testForm.user_id.trim();
    const title = testForm.title.trim();
    const body = testForm.body.trim();

    if (!deviceToken && !userId) {
      Message.warning(t('settingsPush.validation.requireTarget'));
      return;
    }
    if (!title) {
      Message.warning(t('settingsPush.validation.requireTitle'));
      return;
    }
    if (!body) {
      Message.warning(t('settingsPush.validation.requireBody'));
      return;
    }

    testing.value = true;
    try {
      await testPush({
        provider: 'fcm',
        device_token: deviceToken || undefined,
        user_id: userId || undefined,
        title,
        body,
      });
      Message.success(t('settingsPush.test.success'));
      testModalVisible.value = false;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsPush.test.error'),
        })
      );
    } finally {
      testing.value = false;
    }
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .push-settings-container {
    padding: 0 20px 20px;
  }

  .general-card {
    .push-settings {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
  }

  .section {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .section-title {
    margin: 0;
    color: var(--color-text-1, #1d2129);
    font-weight: 600;
    font-size: 14px;
  }

  .provider-card {
    :deep(.arco-card-body) {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
  }

  .hint {
    color: var(--color-text-2, #4e5969);
    font-size: 13px;
    line-height: 1.6;
  }
</style>
