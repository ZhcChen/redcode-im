<template>
  <div class="push-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.push']" />

    <a-card class="general-card" title="Push 通知" :bordered="false">
      <a-spin :loading="loading" tip="加载中...">
        <div v-if="!loading" class="push-settings">
          <a-alert type="info" show-icon :closable="false" title="说明">
            <template #default>
              <div class="hint">
                未配置任何平台凭据时，系统不会发送系统通知（离线推送），仅保留
                WebSocket 实时推送能力。
              </div>
            </template>
          </a-alert>

          <div class="section">
            <h3 class="section-title">全局设置</h3>
            <a-form :model="globalForm" layout="vertical">
              <a-form-item label="离线推送总开关（系统通知）">
                <a-switch v-model="globalForm.enabled" />
              </a-form-item>
              <a-form-item label="用户在线时跳过系统通知">
                <a-switch v-model="globalForm.skip_if_online" />
              </a-form-item>
            </a-form>
            <a-space>
              <a-button
                type="primary"
                :loading="savingGlobal"
                @click="handleSaveGlobal"
              >
                保存全局设置
              </a-button>
              <a-button
                :disabled="savingGlobal || savingFcm || savingApns"
                @click="fetchData"
              >
                刷新
              </a-button>
              <a-button @click="handleOpenPushLogs">查看 Push 日志</a-button>
            </a-space>
          </div>

          <a-divider />

          <div class="section">
            <h3 class="section-title">队列状态（push_job_queue）</h3>
            <a-alert type="warning" show-icon :closable="false" title="说明">
              <template #default>
                <div class="hint">
                  服务端采用 DB 队列作为 Push
                  主队列；此处用于观察是否存在积压与失败。
                </div>
              </template>
            </a-alert>

            <a-descriptions
              :column="2"
              size="small"
              bordered
              style="margin-top: 12px"
            >
              <a-descriptions-item label="pending">
                {{ queueStats?.pending ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item label="retry">
                {{ queueStats?.retry ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item label="due（可执行）">
                {{ queueStats?.due ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item label="failed">
                {{ queueStats?.failed ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item label="done">
                {{ queueStats?.done ?? '-' }}
              </a-descriptions-item>
              <a-descriptions-item label="next_run_at">
                {{ formatTime(queueStats?.next_run_at ?? undefined) }}
              </a-descriptions-item>
              <a-descriptions-item label="oldest_created_at">
                {{ formatTime(queueStats?.oldest_created_at ?? undefined) }}
              </a-descriptions-item>
            </a-descriptions>

            <a-space style="margin-top: 12px">
              <a-button :loading="loadingQueueStats" @click="fetchQueueStats">
                刷新队列状态
              </a-button>
            </a-space>
          </div>

          <a-divider />

          <div class="section">
            <h3 class="section-title">平台配置</h3>

            <a-card
              class="provider-card"
              title="FCM（Firebase Cloud Messaging）"
            >
              <a-form :model="fcmForm" layout="vertical">
                <a-form-item label="启用 FCM">
                  <a-switch v-model="fcmForm.enabled" />
                </a-form-item>

                <a-form-item label="当前配置（只展示非敏感信息）">
                  <a-descriptions :column="1" size="small" bordered>
                    <a-descriptions-item label="状态">
                      <a-tag :color="fcmMeta?.enabled ? 'green' : 'gray'">
                        {{ fcmMeta?.enabled ? '已启用' : '未启用' }}
                      </a-tag>
                      <a-tag
                        v-if="fcmMeta?.has_secret"
                        color="blue"
                        style="margin-left: 8px"
                      >
                        已配置凭据
                      </a-tag>
                      <a-tag v-else color="gray" style="margin-left: 8px">
                        未配置凭据
                      </a-tag>
                    </a-descriptions-item>
                    <a-descriptions-item label="project_id">
                      {{ fcmProjectId }}
                    </a-descriptions-item>
                    <a-descriptions-item label="client_email">
                      {{ fcmClientEmail }}
                    </a-descriptions-item>
                    <a-descriptions-item label="secret_fingerprint">
                      {{ fcmMeta?.secret_fingerprint || '暂无' }}
                    </a-descriptions-item>
                    <a-descriptions-item label="最后更新">
                      {{ formatTime(fcmMeta?.updated_at) }}
                    </a-descriptions-item>
                  </a-descriptions>
                </a-form-item>

                <a-form-item
                  label="Service Account JSON（明文输入，保存后加密存储）"
                >
                  <a-textarea
                    v-model="fcmForm.service_account_json"
                    :auto-size="{ minRows: 6, maxRows: 12 }"
                    placeholder="粘贴 Firebase service account JSON（包含 project_id/client_email/private_key 等）"
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
                  保存 FCM 配置
                </a-button>
                <a-button @click="openTestModal('fcm')"> 测试发送 </a-button>
              </a-space>
            </a-card>

            <a-card
              class="provider-card"
              title="APNs（Apple Push Notification service）"
            >
              <a-form :model="apnsForm" layout="vertical">
                <a-form-item label="启用 APNs">
                  <a-switch v-model="apnsForm.enabled" />
                </a-form-item>

                <a-form-item label="当前配置（只展示非敏感信息）">
                  <a-descriptions :column="1" size="small" bordered>
                    <a-descriptions-item label="状态">
                      <a-tag :color="apnsMeta?.enabled ? 'green' : 'gray'">
                        {{ apnsMeta?.enabled ? '已启用' : '未启用' }}
                      </a-tag>
                      <a-tag
                        v-if="apnsMeta?.has_secret"
                        color="blue"
                        style="margin-left: 8px"
                      >
                        已配置凭据
                      </a-tag>
                      <a-tag v-else color="gray" style="margin-left: 8px">
                        未配置凭据
                      </a-tag>
                    </a-descriptions-item>
                    <a-descriptions-item label="team_id">
                      {{ apnsTeamId }}
                    </a-descriptions-item>
                    <a-descriptions-item label="key_id">
                      {{ apnsKeyId }}
                    </a-descriptions-item>
                    <a-descriptions-item label="bundle_id">
                      {{ apnsBundleId }}
                    </a-descriptions-item>
                    <a-descriptions-item label="environment">
                      {{ apnsEnvironment }}
                    </a-descriptions-item>
                    <a-descriptions-item label="secret_fingerprint">
                      {{ apnsMeta?.secret_fingerprint || '暂无' }}
                    </a-descriptions-item>
                    <a-descriptions-item label="最后更新">
                      {{ formatTime(apnsMeta?.updated_at) }}
                    </a-descriptions-item>
                  </a-descriptions>
                </a-form-item>

                <a-form-item label="Team ID">
                  <a-input
                    v-model="apnsForm.team_id"
                    allow-clear
                    placeholder="Apple Developer Team ID"
                  />
                </a-form-item>
                <a-form-item label="Key ID">
                  <a-input
                    v-model="apnsForm.key_id"
                    allow-clear
                    placeholder="APNs Auth Key ID"
                  />
                </a-form-item>
                <a-form-item label="Bundle ID">
                  <a-input
                    v-model="apnsForm.bundle_id"
                    allow-clear
                    placeholder="例如 com.redcode.im.iosapp"
                  />
                </a-form-item>
                <a-form-item label="环境">
                  <a-select v-model="apnsForm.environment">
                    <a-option value="sandbox">sandbox</a-option>
                    <a-option value="production">production</a-option>
                  </a-select>
                </a-form-item>
                <a-form-item
                  label="Private Key .p8（明文输入，保存后加密存储）"
                >
                  <a-textarea
                    v-model="apnsForm.private_key_p8"
                    :auto-size="{ minRows: 6, maxRows: 12 }"
                    placeholder="粘贴 APNs Auth Key .p8 私钥"
                    allow-clear
                  />
                </a-form-item>
              </a-form>

              <a-space>
                <a-button
                  type="primary"
                  :loading="savingApns"
                  @click="handleSaveApns"
                >
                  保存 APNs 配置
                </a-button>
                <a-button @click="openTestModal('apns')"> 测试发送 </a-button>
              </a-space>
            </a-card>
          </div>
        </div>
      </a-spin>
    </a-card>

    <a-modal
      v-model:visible="testModalVisible"
      title="测试发送"
      :ok-loading="testing"
      :mask-closable="false"
      @ok="handleTestSend"
    >
      <a-form :model="testForm" layout="vertical">
        <a-form-item label="provider">
          <a-select v-model="testForm.provider">
            <a-option value="fcm">FCM</a-option>
            <a-option value="apns">APNs</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="device_token（可选）">
          <a-input
            v-model="testForm.device_token"
            allow-clear
            placeholder="优先使用 device_token；未填则尝试用 user_id 查找已注册设备"
          />
        </a-form-item>
        <a-form-item label="user_id（可选）">
          <a-input
            v-model="testForm.user_id"
            allow-clear
            placeholder="用户 UUID（用于查找 push_devices 中的 token）"
          />
        </a-form-item>
        <a-form-item label="标题">
          <a-input v-model="testForm.title" allow-clear />
        </a-form-item>
        <a-form-item label="正文">
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
  import { useRouter } from 'vue-router';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import {
    getPushSettings,
    getPushJobQueueStats,
    testPush,
    updatePushSettings,
    upsertPushProviderConfig,
    type UpsertApnsProviderPayload,
    type PushProviderConfigView,
    type PushJobQueueStatsResponse,
  } from '@/services/push-settings';

  const router = useRouter();

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

  const apnsMeta = computed(() => {
    return (
      providers.value.find(
        (p) => p.provider === 'apns' && p.platform === 'ios'
      ) ?? null
    );
  });

  const fcmProjectId = computed(() => {
    const v = fcmMeta.value?.config_public?.project_id;
    return typeof v === 'string' && v.trim() ? v : '未配置';
  });

  const fcmClientEmail = computed(() => {
    const v = fcmMeta.value?.config_public?.client_email;
    return typeof v === 'string' && v.trim() ? v : '未配置';
  });

  const apnsTeamId = computed(() => {
    const v = apnsMeta.value?.config_public?.team_id;
    return typeof v === 'string' && v.trim() ? v : '未配置';
  });

  const apnsKeyId = computed(() => {
    const v = apnsMeta.value?.config_public?.key_id;
    return typeof v === 'string' && v.trim() ? v : '未配置';
  });

  const apnsBundleId = computed(() => {
    const v = apnsMeta.value?.config_public?.bundle_id;
    return typeof v === 'string' && v.trim() ? v : '未配置';
  });

  const apnsEnvironment = computed(() => {
    const v = apnsMeta.value?.config_public?.environment;
    return typeof v === 'string' && v.trim() ? v : 'production';
  });

  const fcmForm = reactive({
    enabled: false,
    service_account_json: '',
  });

  const apnsForm = reactive({
    enabled: false,
    team_id: '',
    key_id: '',
    bundle_id: '',
    environment: 'sandbox' as 'sandbox' | 'production',
    private_key_p8: '',
  });

  const queueStats = ref<PushJobQueueStatsResponse | null>(null);
  const loadingQueueStats = ref(false);

  const { loading, setLoading } = useLoading(true);
  const savingGlobal = ref(false);
  const savingFcm = ref(false);
  const savingApns = ref(false);

  const testModalVisible = ref(false);
  const testing = ref(false);
  const testForm = reactive({
    provider: 'fcm',
    device_token: '',
    user_id: '',
    title: '测试通知',
    body: '这是一条测试 Push 通知',
  });

  const formatTime = (value?: string) => {
    if (!value) return '暂无';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

  const fetchQueueStats = async () => {
    loadingQueueStats.value = true;
    try {
      const { data } = await getPushJobQueueStats();
      queueStats.value = data;
    } catch (_) {
      Message.error('加载队列状态失败，请稍后重试');
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

      // 同步 fcm 开关（文本框不会回填，避免泄露/误操作）
      fcmForm.enabled = fcmMeta.value?.enabled ?? false;
      apnsForm.enabled = apnsMeta.value?.enabled ?? false;
      apnsForm.team_id = apnsTeamId.value === '未配置' ? '' : apnsTeamId.value;
      apnsForm.key_id = apnsKeyId.value === '未配置' ? '' : apnsKeyId.value;
      apnsForm.bundle_id =
        apnsBundleId.value === '未配置' ? '' : apnsBundleId.value;
      apnsForm.environment =
        apnsEnvironment.value === 'production' ? 'production' : 'sandbox';
    } catch (error) {
      Message.error('加载 Push 设置失败，请稍后重试');
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
      Message.success('保存成功');
    } catch (error) {
      Message.error('保存失败，请稍后重试');
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
      Message.warning('启用 FCM 需要填写 Service Account JSON');
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

      // 保存成功后清空文本框，避免明文残留
      fcmForm.service_account_json = '';
      await fetchData();
      Message.success('保存成功');
    } catch (error) {
      Message.error('保存失败，请检查配置或稍后重试');
    } finally {
      savingFcm.value = false;
    }
  };

  const handleSaveApns = async () => {
    const hasExistingSecret = apnsMeta.value?.has_secret === true;
    const hasNewSecret =
      apnsForm.private_key_p8 && apnsForm.private_key_p8.trim() !== '';

    if (
      apnsForm.enabled &&
      (!apnsForm.team_id.trim() ||
        !apnsForm.key_id.trim() ||
        !apnsForm.bundle_id.trim())
    ) {
      Message.warning('启用 APNs 需要填写 Team ID、Key ID 和 Bundle ID');
      return;
    }
    if (apnsForm.enabled && !hasExistingSecret && !hasNewSecret) {
      Message.warning('启用 APNs 需要填写 .p8 私钥');
      return;
    }

    savingApns.value = true;
    try {
      const payload: UpsertApnsProviderPayload = {
        enabled: apnsForm.enabled,
        team_id: apnsForm.team_id.trim(),
        key_id: apnsForm.key_id.trim(),
        bundle_id: apnsForm.bundle_id.trim(),
        environment: apnsForm.environment,
      };
      if (hasNewSecret) {
        payload.private_key_p8 = apnsForm.private_key_p8;
      }
      await upsertPushProviderConfig('apns', payload);

      // 保存成功后清空文本框，避免明文残留
      apnsForm.private_key_p8 = '';
      await fetchData();
      Message.success('保存成功');
    } catch (error) {
      Message.error('保存失败，请检查配置或稍后重试');
    } finally {
      savingApns.value = false;
    }
  };

  const handleOpenPushLogs = () => {
    router.push({ name: 'PushLog' });
  };

  const openTestModal = (provider: 'fcm' | 'apns' = 'fcm') => {
    testForm.provider = provider;
    testModalVisible.value = true;
  };

  const handleTestSend = async () => {
    const deviceToken = testForm.device_token.trim();
    const userId = testForm.user_id.trim();
    const title = testForm.title.trim();
    const body = testForm.body.trim();

    if (!deviceToken && !userId) {
      Message.warning('请填写 device_token 或 user_id');
      return;
    }
    if (!title) {
      Message.warning('请填写标题');
      return;
    }
    if (!body) {
      Message.warning('请填写正文');
      return;
    }

    testing.value = true;
    try {
      await testPush({
        provider: testForm.provider,
        device_token: deviceToken || undefined,
        user_id: userId || undefined,
        title,
        body,
      });
      Message.success('发送成功');
      testModalVisible.value = false;
    } catch (error) {
      Message.error('发送失败，请稍后重试');
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
