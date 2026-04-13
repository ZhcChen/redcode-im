<template>
  <div class="storage-config-container">
    <Breadcrumb
      :items="['menu.operations', 'menu.operations.storageProvider']"
    />

    <a-space direction="vertical" :size="16" fill class="content-space">
      <a-alert type="info" :closable="false">
        <template #title>Backblaze B2 运行时配置</template>
        当前页直接管理 B2
        的运行时配置版本。应用后会同步默认对象存储提供商，现有上传链路无需改动。
      </a-alert>

      <a-card class="general-card" title="对象存储配置" :bordered="false">
        <div class="actions">
          <a-space wrap>
            <a-button :loading="loading" @click="refreshData(true)">
              <template #icon>
                <icon-refresh />
              </template>
              刷新
            </a-button>
            <a-button
              :disabled="!current"
              @click="fillFormFromCurrent(current)"
            >
              使用当前配置
            </a-button>
          </a-space>
        </div>

        <a-spin :loading="loading" style="width: 100%">
          <div class="config-grid">
            <a-card class="inner-card" title="当前生效配置" size="small">
              <a-empty v-if="!current" description="当前暂无可用配置" />
              <a-descriptions v-else :column="1" size="small" bordered>
                <a-descriptions-item label="来源">
                  <a-tag :color="sourceTagColor(current.source)">
                    {{ sourceLabel(current.source) }}
                  </a-tag>
                </a-descriptions-item>
                <a-descriptions-item label="版本">
                  {{ versionLabel(current.version) }}
                </a-descriptions-item>
                <a-descriptions-item label="Endpoint">
                  {{ current.endpoint || '-' }}
                </a-descriptions-item>
                <a-descriptions-item label="Region">
                  {{ current.region || '-' }}
                </a-descriptions-item>
                <a-descriptions-item label="Private Bucket">
                  {{ current.privateBucket || '-' }}
                </a-descriptions-item>
                <a-descriptions-item label="Public Bucket">
                  {{ current.publicBucket || '-' }}
                </a-descriptions-item>
                <a-descriptions-item label="Public Base URL">
                  {{ current.publicBaseUrl || '-' }}
                </a-descriptions-item>
                <a-descriptions-item label="上传签名 TTL">
                  {{ current.uploadUrlTtlSeconds }} 秒
                </a-descriptions-item>
                <a-descriptions-item label="下载签名 TTL">
                  {{ current.downloadUrlTtlSeconds }} 秒
                </a-descriptions-item>
                <a-descriptions-item label="Key ID">
                  <a-tag :color="current.keyIdConfigured ? 'green' : 'gray'">
                    {{ current.keyIdConfigured ? '已配置' : '未配置' }}
                  </a-tag>
                </a-descriptions-item>
                <a-descriptions-item label="Application Key">
                  <a-tag
                    :color="current.applicationKeyConfigured ? 'green' : 'gray'"
                  >
                    {{ current.applicationKeyConfigured ? '已配置' : '未配置' }}
                  </a-tag>
                </a-descriptions-item>
                <a-descriptions-item label="最近应用">
                  {{ formatDate(current.lastAppliedAt) }}
                </a-descriptions-item>
                <a-descriptions-item label="最近更新">
                  {{ formatDate(current.updatedAt) }}
                </a-descriptions-item>
              </a-descriptions>
            </a-card>

            <a-card class="inner-card" title="编辑 / 应用 B2 配置" size="small">
              <a-form :model="form" layout="vertical">
                <a-form-item label="Endpoint">
                  <a-input
                    v-model="form.endpoint"
                    allow-clear
                    placeholder="https://s3.us-east-005.backblazeb2.com"
                  />
                </a-form-item>
                <a-form-item label="Region">
                  <a-input
                    v-model="form.region"
                    allow-clear
                    placeholder="us-east-005"
                  />
                </a-form-item>
                <a-form-item label="Private Bucket">
                  <a-input
                    v-model="form.privateBucket"
                    allow-clear
                    placeholder="请输入私有 Bucket 名称"
                  />
                </a-form-item>
                <a-form-item label="Public Bucket">
                  <a-input
                    v-model="form.publicBucket"
                    allow-clear
                    placeholder="可选：请输入公开 Bucket 名称"
                  />
                </a-form-item>
                <a-form-item label="Public Base URL">
                  <a-input
                    v-model="form.publicBaseUrl"
                    allow-clear
                    placeholder="可选：请输入公开访问 Base URL"
                  />
                </a-form-item>
                <div class="ttl-grid">
                  <a-form-item label="上传签名 TTL（秒）">
                    <a-input-number
                      v-model="form.uploadUrlTtlSeconds"
                      :min="1"
                      mode="button"
                      style="width: 100%"
                    />
                  </a-form-item>
                  <a-form-item label="下载签名 TTL（秒）">
                    <a-input-number
                      v-model="form.downloadUrlTtlSeconds"
                      :min="1"
                      mode="button"
                      style="width: 100%"
                    />
                  </a-form-item>
                </div>
                <a-form-item label="Key ID">
                  <a-input
                    v-model="form.keyId"
                    allow-clear
                    placeholder="留空表示沿用当前 Key ID"
                  />
                  <div v-if="current?.keyIdConfigured" class="secret-hint">
                    当前已配置 Key ID
                  </div>
                </a-form-item>
                <a-form-item label="Application Key">
                  <a-input-password
                    v-model="form.applicationKey"
                    allow-clear
                    placeholder="留空表示沿用当前 Application Key"
                  />
                  <div
                    v-if="current?.applicationKeyConfigured"
                    class="secret-hint"
                  >
                    当前已配置 Application Key
                  </div>
                </a-form-item>
                <a-form-item label="变更说明">
                  <a-textarea
                    v-model="form.changeNote"
                    :auto-size="{ minRows: 2, maxRows: 4 }"
                    placeholder="请输入本次变更说明（可选）"
                  />
                </a-form-item>
                <a-space wrap>
                  <a-button
                    type="outline"
                    :loading="probing"
                    :disabled="!canManage"
                    @click="handleProbe"
                  >
                    探测配置
                  </a-button>
                  <a-button
                    type="primary"
                    :loading="applying"
                    :disabled="!canManage"
                    @click="handleApply"
                  >
                    应用配置
                  </a-button>
                  <a-button
                    :loading="initializingBuckets"
                    :disabled="!canManage"
                    @click="handleInitBuckets"
                  >
                    初始化 Bucket
                  </a-button>
                </a-space>
              </a-form>
            </a-card>
          </div>

          <a-card
            v-if="probeResult || initBucketResult"
            class="inner-card result-card"
            title="探测结果"
            size="small"
          >
            <a-space direction="vertical" :size="16" fill>
              <template v-if="probeSummary">
                <a-descriptions :column="1" size="small" bordered>
                  <a-descriptions-item label="探测版本候选">
                    {{ versionLabel(probeSummary.version) }}
                  </a-descriptions-item>
                  <a-descriptions-item label="Endpoint">
                    {{ probeSummary.endpoint || '-' }}
                  </a-descriptions-item>
                  <a-descriptions-item label="Private Bucket">
                    {{ probeSummary.privateBucket || '-' }}
                  </a-descriptions-item>
                  <a-descriptions-item label="Public Bucket">
                    {{ probeSummary.publicBucket || '-' }}
                  </a-descriptions-item>
                </a-descriptions>
              </template>

              <template v-if="probeResult">
                <div class="tag-section">
                  <div class="section-title">运行时所需能力</div>
                  <a-space wrap>
                    <a-tag
                      v-for="capability in probeResult.requiredRuntimeCapabilities"
                      :key="`required-${capability}`"
                      color="arcoblue"
                    >
                      {{ capability }}
                    </a-tag>
                  </a-space>
                </div>

                <div class="tag-section">
                  <div class="section-title">已授权能力</div>
                  <a-space wrap>
                    <a-tag
                      v-for="capability in probeResult.allowedCapabilities"
                      :key="`allowed-${capability}`"
                      :color="capabilityColor(capability)"
                    >
                      {{ capability }}
                    </a-tag>
                  </a-space>
                </div>

                <a-table
                  :columns="probeColumns"
                  :data="probeResult.checks"
                  :pagination="false"
                  size="small"
                  row-key="code"
                >
                  <template #status="{ record }">
                    <a-tag :color="probeStatusColor(record.status)">
                      {{ probeStatusLabel(record.status) }}
                    </a-tag>
                  </template>
                </a-table>
              </template>

              <template v-if="initBucketResult">
                <div class="section-title">Bucket 初始化结果</div>
                <a-table
                  :columns="bucketInitColumns"
                  :data="initBucketResult.items"
                  :pagination="false"
                  size="small"
                  row-key="bucketName"
                >
                  <template #status="{ record }">
                    <a-tag :color="bucketInitStatusColor(record.status)">
                      {{ bucketInitStatusLabel(record.status) }}
                    </a-tag>
                  </template>
                </a-table>
              </template>
            </a-space>
          </a-card>
        </a-spin>
      </a-card>

      <a-card class="general-card" title="配置历史" :bordered="false">
        <a-table
          :columns="historyColumns"
          :data="history"
          :pagination="false"
          :loading="loading"
          row-key="version"
        >
          <template #version="{ record }">
            {{ versionLabel(record.version) }}
          </template>
          <template #source="{ record }">
            <a-tag :color="sourceTagColor(record.source)">
              {{ sourceLabel(record.source) }}
            </a-tag>
          </template>
          <template #status="{ record }">
            <a-tag :color="historyStatusColor(record.status)">
              {{ historyStatusLabel(record.status) }}
            </a-tag>
          </template>
          <template #bucket="{ record }">
            <div>{{ record.privateBucket }}</div>
            <div class="sub-value">{{ record.publicBucket || '-' }}</div>
          </template>
          <template #updatedAt="{ record }">
            {{
              formatDate(
                record.updatedAt || record.appliedAt || record.createdAt
              )
            }}
          </template>
          <template #operations="{ record }">
            <a-button
              v-if="record.version && record.status !== 'active'"
              type="text"
              size="small"
              :loading="
                rollbacking && rollbackTarget?.version === record.version
              "
              :disabled="!canManage"
              @click="openRollback(record)"
            >
              回滚到 {{ versionLabel(record.version) }}
            </a-button>
            <span v-else>-</span>
          </template>
        </a-table>
      </a-card>
    </a-space>

    <a-modal
      v-model:visible="rollbackVisible"
      title="回滚对象存储配置"
      :confirm-loading="rollbacking"
      @ok="handleRollback"
    >
      <a-space direction="vertical" fill>
        <a-alert type="warning" :closable="false">
          将会基于历史版本重新生成一个新的 active 版本，不会直接覆写旧记录。
        </a-alert>
        <a-descriptions :column="1" size="small" bordered>
          <a-descriptions-item label="目标版本">
            {{ versionLabel(rollbackTarget?.version ?? null) }}
          </a-descriptions-item>
          <a-descriptions-item label="目标 Bucket">
            {{ rollbackTarget?.privateBucket || '-' }}
          </a-descriptions-item>
        </a-descriptions>
        <a-textarea
          v-model="rollbackReason"
          :auto-size="{ minRows: 2, maxRows: 4 }"
          placeholder="请输入回滚原因（可选）"
        />
      </a-space>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import { onMounted, reactive, ref } from 'vue';

  import useCan from '@/shared/access/use-can';
  import {
    applyObjectStorageConfig,
    fetchObjectStorageConfig,
    fetchObjectStorageConfigHistory,
    initObjectStorageBuckets,
    probeObjectStorageConfig,
    rollbackObjectStorageConfig,
    type ObjectStorageBucketInitResult,
    type ObjectStorageConfigHistoryItem,
    type ObjectStorageConfigInput,
    type ObjectStorageConfigSummary,
    type ObjectStorageProbeResult,
  } from '@/services/storage-config';

  interface StorageConfigFormState {
    endpoint: string;
    region: string;
    privateBucket: string;
    publicBucket: string;
    publicBaseUrl: string;
    uploadUrlTtlSeconds: number;
    downloadUrlTtlSeconds: number;
    keyId: string;
    applicationKey: string;
    changeNote: string;
  }

  const canManage = useCan('system:settings');

  const loading = ref(false);
  const probing = ref(false);
  const applying = ref(false);
  const initializingBuckets = ref(false);
  const rollbacking = ref(false);
  const hydrated = ref(false);

  const current = ref<ObjectStorageConfigSummary | null>(null);
  const history = ref<ObjectStorageConfigHistoryItem[]>([]);
  const probeSummary = ref<ObjectStorageConfigSummary | null>(null);
  const probeResult = ref<ObjectStorageProbeResult | null>(null);
  const initBucketResult = ref<ObjectStorageBucketInitResult | null>(null);

  const rollbackVisible = ref(false);
  const rollbackTarget = ref<ObjectStorageConfigHistoryItem | null>(null);
  const rollbackReason = ref('');

  function emptyToNull(value: string): string | null {
    const trimmed = value.trim();
    return trimmed || null;
  }

  function normalizePositiveNumber(value: number): number | null {
    if (!Number.isFinite(value) || value <= 0) {
      return null;
    }
    return Math.floor(value);
  }

  const form = reactive<StorageConfigFormState>({
    endpoint: '',
    region: 'us-east-005',
    privateBucket: '',
    publicBucket: '',
    publicBaseUrl: '',
    uploadUrlTtlSeconds: 900,
    downloadUrlTtlSeconds: 600,
    keyId: '',
    applicationKey: '',
    changeNote: '',
  });

  const historyColumns = [
    { title: '版本', dataIndex: 'version', slotName: 'version', width: 120 },
    { title: '来源', dataIndex: 'source', slotName: 'source', width: 120 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 120 },
    { title: 'Bucket', dataIndex: 'privateBucket', slotName: 'bucket' },
    { title: '变更说明', dataIndex: 'changeNote', ellipsis: true },
    {
      title: '更新时间',
      dataIndex: 'updatedAt',
      slotName: 'updatedAt',
      width: 180,
    },
    { title: '操作', slotName: 'operations', width: 160 },
  ];

  const probeColumns = [
    { title: '检查项', dataIndex: 'code', width: 180 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 120 },
    { title: '说明', dataIndex: 'message' },
  ];

  const bucketInitColumns = [
    { title: 'Bucket', dataIndex: 'bucketName', width: 220 },
    { title: '角色', dataIndex: 'bucketRole', width: 120 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 140 },
    { title: '说明', dataIndex: 'message' },
  ];

  function fillFormFromCurrent(summary: ObjectStorageConfigSummary | null) {
    form.endpoint =
      summary?.endpoint || 'https://s3.us-east-005.backblazeb2.com';
    form.region = summary?.region || 'us-east-005';
    form.privateBucket = summary?.privateBucket || '';
    form.publicBucket = summary?.publicBucket || '';
    form.publicBaseUrl = summary?.publicBaseUrl || '';
    form.uploadUrlTtlSeconds = summary?.uploadUrlTtlSeconds || 900;
    form.downloadUrlTtlSeconds = summary?.downloadUrlTtlSeconds || 600;
    form.keyId = '';
    form.applicationKey = '';
    form.changeNote = '';
    hydrated.value = true;
  }

  function buildInput(): ObjectStorageConfigInput {
    return {
      endpoint: emptyToNull(form.endpoint),
      region: emptyToNull(form.region),
      privateBucket: emptyToNull(form.privateBucket),
      publicBucket: emptyToNull(form.publicBucket),
      publicBaseUrl: emptyToNull(form.publicBaseUrl),
      uploadUrlTtlSeconds: normalizePositiveNumber(form.uploadUrlTtlSeconds),
      downloadUrlTtlSeconds: normalizePositiveNumber(
        form.downloadUrlTtlSeconds
      ),
      keyId: emptyToNull(form.keyId),
      applicationKey: emptyToNull(form.applicationKey),
    };
  }

  function resolveErrorMessage(error: any, fallback: string) {
    return (
      error?.response?.data?.message ||
      error?.response?.data?.details ||
      error?.message ||
      fallback
    );
  }

  function formatDate(value?: string | null) {
    if (!value) {
      return '-';
    }
    return dayjs(value).format('YYYY-MM-DD HH:mm:ss');
  }

  function versionLabel(version?: number | null) {
    return version ? `v${version}` : 'env fallback';
  }

  function sourceLabel(source: string) {
    return source === 'database' ? '数据库版本' : '环境变量回退';
  }

  function sourceTagColor(source: string) {
    return source === 'database' ? 'arcoblue' : 'orange';
  }

  function historyStatusLabel(status: string) {
    if (status === 'active') return '生效中';
    if (status === 'superseded') return '已替换';
    if (status === 'rolled_back') return '已回滚';
    return status || '-';
  }

  function historyStatusColor(status: string) {
    if (status === 'active') return 'green';
    if (status === 'superseded') return 'gray';
    if (status === 'rolled_back') return 'orange';
    return 'arcoblue';
  }

  function probeStatusLabel(status: string) {
    if (status === 'pass') return '通过';
    if (status === 'warn') return '警告';
    return '失败';
  }

  function probeStatusColor(status: string) {
    if (status === 'pass') return 'green';
    if (status === 'warn') return 'orange';
    return 'red';
  }

  function capabilityColor(capability: string) {
    if (capability === 'writeBuckets') {
      return 'purple';
    }
    if (capability === 'writeFiles') {
      return 'green';
    }
    if (capability === 'readFiles') {
      return 'arcoblue';
    }
    return 'gray';
  }

  function bucketInitStatusLabel(status: string) {
    if (status === 'created') return '已创建';
    if (status === 'already_exists') return '已存在';
    if (status === 'skipped') return '已跳过';
    return '失败';
  }

  function bucketInitStatusColor(status: string) {
    if (status === 'created') return 'green';
    if (status === 'already_exists') return 'arcoblue';
    if (status === 'skipped') return 'gray';
    return 'red';
  }

  async function refreshData(hydrateForm = false) {
    try {
      loading.value = true;
      const [nextCurrent, nextHistory] = await Promise.all([
        fetchObjectStorageConfig(),
        fetchObjectStorageConfigHistory(),
      ]);
      current.value = nextCurrent;
      history.value = nextHistory;
      if (hydrateForm || !hydrated.value) {
        fillFormFromCurrent(nextCurrent);
      }
    } catch (error: any) {
      Message.error(resolveErrorMessage(error, '加载对象存储配置失败'));
    } finally {
      loading.value = false;
    }
  }

  async function handleProbe() {
    try {
      probing.value = true;
      initBucketResult.value = null;
      const payload = await probeObjectStorageConfig(buildInput());
      probeSummary.value = payload.normalized;
      probeResult.value = payload.probe;
      Message.success('探测完成');
    } catch (error: any) {
      probeSummary.value = null;
      probeResult.value = null;
      Message.error(resolveErrorMessage(error, '探测对象存储配置失败'));
    } finally {
      probing.value = false;
    }
  }

  async function handleApply() {
    try {
      applying.value = true;
      await applyObjectStorageConfig(
        buildInput(),
        emptyToNull(form.changeNote)
      );
      Message.success('对象存储配置已应用');
      await refreshData(true);
    } catch (error: any) {
      Message.error(resolveErrorMessage(error, '应用对象存储配置失败'));
    } finally {
      applying.value = false;
    }
  }

  async function handleInitBuckets() {
    try {
      initializingBuckets.value = true;
      const payload = await initObjectStorageBuckets();
      current.value = payload.current;
      initBucketResult.value = payload.result;
      Message.success('Bucket 初始化完成');
    } catch (error: any) {
      initBucketResult.value = null;
      Message.error(resolveErrorMessage(error, '初始化 Bucket 失败'));
    } finally {
      initializingBuckets.value = false;
    }
  }

  function openRollback(record: ObjectStorageConfigHistoryItem) {
    rollbackTarget.value = record;
    rollbackReason.value = '';
    rollbackVisible.value = true;
  }

  async function handleRollback() {
    if (!rollbackTarget.value?.version) {
      return;
    }

    try {
      rollbacking.value = true;
      await rollbackObjectStorageConfig(
        rollbackTarget.value.version,
        emptyToNull(rollbackReason.value)
      );
      rollbackVisible.value = false;
      Message.success(`已回滚到 ${versionLabel(rollbackTarget.value.version)}`);
      await refreshData(true);
    } catch (error: any) {
      Message.error(resolveErrorMessage(error, '回滚对象存储配置失败'));
    } finally {
      rollbacking.value = false;
    }
  }

  onMounted(() => {
    refreshData(true);
  });
</script>

<style lang="less" scoped>
  .storage-config-container {
    padding: 0 20px 20px;
  }

  .content-space {
    width: 100%;
  }

  .actions {
    margin-bottom: 16px;
  }

  .config-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
    margin-bottom: 16px;
  }

  .inner-card {
    width: 100%;
  }

  .result-card {
    margin-top: 16px;
  }

  .ttl-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
  }

  .secret-hint {
    margin-top: 8px;
    color: rgb(var(--gray-6));
    font-size: 12px;
    line-height: 1.4;
  }

  .section-title {
    margin-bottom: 8px;
    font-weight: 600;
    font-size: 13px;
  }

  .tag-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .sub-value {
    color: rgb(var(--gray-6));
    font-size: 12px;
  }

  @media (max-width: 1200px) {
    .config-grid,
    .ttl-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
