<template>
  <div class="hot-update-container">
    <Breadcrumb :items="['menu.version', 'menu.version.hotUpdate']" />
    <a-card class="general-card" :title="cardTitle" :bordered="false">
      <div class="actions">
        <a-space wrap>
          <a-select
            v-model="platformFilter"
            style="width: 160px"
            :options="platformOptions"
          />
          <a-select
            v-model="channelFilter"
            allow-clear
            placeholder="选择渠道"
            style="width: 160px"
          >
            <a-option
              v-for="channel in channelOptions"
              :key="channel"
              :value="channel"
            >
              {{ channel }}
            </a-option>
          </a-select>
          <a-button type="primary" @click="handleCreate">
            <template #icon>
              <icon-plus />
            </template>
            新增补丁
          </a-button>
          <a-button :loading="listLoading" @click="fetchHotUpdates">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="columns"
        :data="hotUpdates"
        :loading="listLoading"
        :pagination="false"
        row-key="id"
        class="hot-update-table"
      >
        <template #platform="{ record }">
          <a-tag>{{ platformLabel(record.platform) }}</a-tag>
        </template>
        <template #baseVersion="{ record }">
          {{ getBaseVersionLabel(record.app_version_id) }}
        </template>
        <template #rollout="{ record }">
          <a-progress
            :percent="record.rollout_percentage"
            :status="record.is_active ? 'normal' : 'warning'"
          />
        </template>
        <template #mandatory="{ record }">
          <a-tag :color="record.mandatory ? 'red' : 'green'">
            {{ record.mandatory ? '强制' : '可选' }}
          </a-tag>
        </template>
        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{ record.is_active ? '启用' : '停用' }}
          </a-tag>
        </template>
        <template #released_at="{ record }">
          {{ formatDateTime(record.released_at) }}
        </template>
        <template #operations="{ record }">
          <a-space size="mini">
            <a-button type="text" size="small" @click="handleEdit(record)">
              编辑
            </a-button>
            <a-button
              type="text"
              size="small"
              :loading="toggleLoadingId === record.id"
              @click="handleToggleActive(record)"
            >
              {{ record.is_active ? '停用' : '启用' }}
            </a-button>
            <a-popconfirm
              content="确定要删除该补丁吗？"
              type="warning"
              @ok="handleDelete(record)"
            >
              <a-button type="text" size="small" status="danger">
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>

      <div v-if="total > 0" class="table-pagination">
        <a-pagination
          :current="currentPage"
          :page-size="pageSize"
          :total="total"
          show-total
          show-page-size
          :page-size-options="[10, 20, 50]"
          @change="handlePageChange"
          @page-size-change="handlePageSizeChange"
        />
      </div>
    </a-card>

    <input
      ref="fileInputRef"
      type="file"
      class="hidden-file-input"
      @change="handleFileSelected"
    />

    <a-modal
      :visible="modalVisible"
      :title="modalTitle"
      :width="720"
      :confirm-loading="actionLoading"
      @before-ok="handleBeforeOk"
      @cancel="handleCancel"
      @update:visible="modalVisible = $event"
    >
      <a-form
        ref="formRef"
        :model="formState"
        :rules="formRules"
        label-align="left"
        :label-col-props="{ span: 6 }"
        :wrapper-col-props="{ span: 18 }"
      >
        <a-form-item field="platform" label="平台">
          <a-select
            v-model="formState.platform"
            :options="platformOptions"
            @change="loadVersionOptions"
          />
        </a-form-item>
        <a-form-item field="app_version_id" label="基线版本">
          <a-select
            v-model="formState.app_version_id"
            placeholder="请选择整包版本"
            :options="versionOptions"
            allow-search
          />
        </a-form-item>
        <a-form-item field="patch_version" label="补丁版本">
          <a-input
            v-model="formState.patch_version"
            placeholder="例如：1.0.0-p1"
          />
        </a-form-item>
        <a-form-item field="channel" label="渠道">
          <a-select
            v-model="formState.channel"
            :options="channelSelectOptions"
            allow-clear
          />
        </a-form-item>
        <a-form-item field="download_key" label="补丁 Key">
          <a-input
            v-model="formState.download_key"
            placeholder="请上传补丁文件"
            readonly
          />
        </a-form-item>
        <a-form-item label="补丁上传">
          <a-space>
            <a-button
              type="outline"
              :loading="uploadLoading"
              @click="triggerFileSelect"
            >
              选择文件并上传
            </a-button>
            <span v-if="uploadedFileInfo" class="upload-info">{{
              uploadedFileInfo
            }}</span>
          </a-space>
          <template #extra>
            文件将上传至默认存储，完成后自动填充补丁 Key。
          </template>
        </a-form-item>
        <a-form-item field="download_url" label="备用下载地址">
          <a-input
            v-model="formState.download_url"
            placeholder="可选：备用 CDN 地址"
          />
        </a-form-item>
        <a-form-item field="file_size" label="文件大小">
          <a-input-number
            v-model="formState.file_size"
            :min="0"
            style="width: 100%"
            placeholder="可选"
          />
        </a-form-item>
        <a-form-item field="checksum" label="校验摘要">
          <a-input v-model="formState.checksum" placeholder="可选：MD5/SHA" />
        </a-form-item>
        <a-form-item field="signature" label="签名">
          <a-input v-model="formState.signature" placeholder="可选" />
        </a-form-item>
        <a-form-item field="rollout_percentage" label="灰度比例">
          <a-input-number
            v-model="formState.rollout_percentage"
            :min="0"
            :max="100"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item field="mandatory" label="强制热更">
          <a-switch
            v-model="formState.mandatory"
            checked-text="是"
            unchecked-text="否"
          />
        </a-form-item>
        <a-form-item field="released_at" label="发布时间">
          <a-date-picker
            v-model="releasedAtValue"
            show-time
            style="width: 100%"
            placeholder="可选"
          />
        </a-form-item>
        <a-form-item field="description" label="补丁说明">
          <a-textarea
            v-model="formState.description"
            :rows="3"
            placeholder="记录变更内容"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, reactive, ref, watch } from 'vue';
  import dayjs from 'dayjs';
  import {
    Message,
    type FormInstance,
    type TableColumnData,
  } from '@arco-design/web-vue';
  import {
    listHotUpdates,
    createHotUpdate,
    updateHotUpdate,
    deleteHotUpdate,
    activateHotUpdate,
    deactivateHotUpdate,
    type HotUpdateInfo,
    type CreateHotUpdatePayload,
    type UpdateHotUpdatePayload,
  } from '@/services/hot-update';
  import {
    listAppVersions,
    getAppVersion,
    generateVersionUploadSignature,
    initiateVersionMultipartUpload,
    type AppVersionInfo,
    AppPlatform,
    PlatformLabels,
  } from '@/services/app-version';
  import { uploadWithSignature } from '@/utils/direct-upload';
  import { uploadFileByMultipartAndComplete } from '@/utils/multipart-upload';
  import { computeFileHash } from '@/utils/fileHash';

  const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024;

  const channelOptions = [
    'stable',
    'stable-macos-intel',
    'stable-macos-arm64',
    'beta',
    'alpha',
    'dev',
  ];

  const platformFilter = ref<AppPlatform>(AppPlatform.Android);
  const channelFilter = ref<string | undefined>('stable');
  const listLoading = ref(false);
  const hotUpdates = ref<HotUpdateInfo[]>([]);
  const total = ref(0);
  const pageSize = ref(10);
  const currentPage = ref(1);
  const toggleLoadingId = ref<string | null>(null);

  const versionCache = reactive<Record<string, AppVersionInfo>>({});

  const modalVisible = ref(false);
  const actionLoading = ref(false);
  const uploadLoading = ref(false);
  const fileInputRef = ref<HTMLInputElement | null>(null);
  const formRef = ref<FormInstance>();
  const editingHotUpdate = ref<HotUpdateInfo | null>(null);
  const releasedAtValue = ref<Date>();
  const uploadedFileInfo = ref('');

  const versionOptions = ref<{ label: string; value: string }[]>([]);

  type HotUpdateFormState = Omit<CreateHotUpdatePayload, 'platform'> & {
    platform: AppPlatform;
    file_size?: number;
  };

  function getDefaultFormState(): HotUpdateFormState {
    return {
      platform: AppPlatform.Android,
      app_version_id: '',
      patch_version: '',
      channel: 'stable',
      download_key: '',
      download_url: '',
      file_size: undefined,
      checksum: '',
      signature: '',
      rollout_percentage: 100,
      mandatory: false,
      description: '',
    };
  }

  const formState = reactive<HotUpdateFormState>(getDefaultFormState());

  const formRules = {
    platform: [{ required: true, message: '请选择平台' }],
    app_version_id: [{ required: true, message: '请选择基线版本' }],
    patch_version: [{ required: true, message: '请输入补丁版本' }],
    channel: [{ required: true, message: '请输入渠道' }],
    download_key: [{ required: true, message: '请上传补丁文件' }],
    rollout_percentage: [{ required: true, message: '请输入灰度比例' }],
  };

  const platformOptions = Object.values(AppPlatform)
    .filter(
      (platform) =>
        platform === AppPlatform.Android || platform === AppPlatform.IOS
    )
    .map((platform) => ({
      label: PlatformLabels[platform],
      value: platform,
    }));

  const channelSelectOptions = channelOptions.map((channel) => ({
    label: channel,
    value: channel,
  }));

  const columns: TableColumnData[] = [
    { title: '平台', dataIndex: 'platform', slotName: 'platform', width: 120 },
    {
      title: '基线版本',
      dataIndex: 'app_version_id',
      slotName: 'baseVersion',
      width: 160,
    },
    { title: '补丁版本', dataIndex: 'patch_version', width: 150 },
    { title: '渠道', dataIndex: 'channel', width: 120 },
    {
      title: '灰度比例',
      dataIndex: 'rollout_percentage',
      slotName: 'rollout',
      width: 160,
    },
    {
      title: '强制',
      dataIndex: 'mandatory',
      slotName: 'mandatory',
      width: 100,
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: '发布时间',
      dataIndex: 'released_at',
      slotName: 'released_at',
      width: 180,
    },
    { title: '操作', slotName: 'operations', width: 240, fixed: 'right' },
  ];

  const cardTitle = computed(() => '热更新管理');

  const modalTitle = computed(() =>
    editingHotUpdate.value ? '编辑热更新' : '新增热更新'
  );

  const platformLabel = (value: AppPlatform | string) =>
    PlatformLabels[value as AppPlatform] || value;

  const formatDateTime = (value?: string | null) => {
    if (!value) return '-';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

  const getBaseVersionLabel = (versionId: string) => {
    const info = versionCache[versionId];
    if (info) {
      return `${info.version} (${info.channel})`;
    }
    return versionId;
  };

  const cacheBaseVersions = async (items: HotUpdateInfo[]) => {
    const missing = Array.from(
      new Set(items.map((item) => item.app_version_id))
    ).filter((id) => !versionCache[id]);
    await Promise.all(
      missing.map(async (id) => {
        try {
          const { data } = await getAppVersion(id);
          versionCache[id] = data;
        } catch (error) {
          // 忽略单个版本获取失败
        }
      })
    );
  };

  const fetchHotUpdates = async () => {
    listLoading.value = true;
    try {
      const params = {
        platform: platformFilter.value,
        channel: channelFilter.value,
        limit: pageSize.value,
        offset: (currentPage.value - 1) * pageSize.value,
      };
      const { data } = await listHotUpdates(params);
      hotUpdates.value = data.items;
      total.value = data.total;
      cacheBaseVersions(data.items);
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '加载热更新列表失败';
      Message.error(errorMsg);
    } finally {
      listLoading.value = false;
    }
  };

  const loadVersionOptions = async () => {
    try {
      const { data } = await listAppVersions({
        platform: formState.platform,
        channel: formState.channel || 'stable',
        limit: 100,
        offset: 0,
      });
      versionOptions.value = data.items.map((item) => ({
        label: `${item.version} (${item.channel})`,
        value: item.id,
      }));
      if (
        !versionOptions.value.some(
          (option) => option.value === formState.app_version_id
        )
      ) {
        formState.app_version_id = versionOptions.value[0]?.value || '';
      }
    } catch (error) {
      // ignore load errors
    }
  };

  const handlePageChange = (page: number) => {
    currentPage.value = page;
    fetchHotUpdates();
  };

  const handlePageSizeChange = (size: number) => {
    pageSize.value = size;
    currentPage.value = 1;
    fetchHotUpdates();
  };

  const handleCreate = () => {
    Object.assign(formState, getDefaultFormState());
    formState.platform = platformFilter.value;
    formState.channel = channelFilter.value || 'stable';
    editingHotUpdate.value = null;
    releasedAtValue.value = undefined;
    uploadedFileInfo.value = '';
    loadVersionOptions();
    modalVisible.value = true;
  };

  const formatFileSize = (size?: number | null) => {
    if (!size || size <= 0) return '-';
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    if (size < 1024 * 1024 * 1024)
      return `${(size / 1024 / 1024).toFixed(2)} MB`;
    return `${(size / 1024 / 1024 / 1024).toFixed(2)} GB`;
  };

  const handleEdit = (record: HotUpdateInfo) => {
    editingHotUpdate.value = record;
    Object.assign(formState, {
      platform: record.platform as AppPlatform,
      app_version_id: record.app_version_id,
      patch_version: record.patch_version,
      channel: record.channel,
      download_key: record.download_key,
      download_url: record.download_url || '',
      file_size: record.file_size ?? undefined,
      checksum: record.checksum || '',
      signature: record.signature || '',
      rollout_percentage: record.rollout_percentage,
      mandatory: record.mandatory,
      description: record.description || '',
    });
    releasedAtValue.value = record.released_at
      ? new Date(record.released_at)
      : undefined;
    uploadedFileInfo.value = record.file_size
      ? `${record.patch_version} · ${formatFileSize(record.file_size)}`
      : '';
    loadVersionOptions();
    modalVisible.value = true;
  };

  const handleBeforeOk = async (done: (closed: boolean) => void) => {
    if (!formRef.value) {
      done(false);
      return;
    }
    const errors = await formRef.value.validate();
    if (errors) {
      done(false);
      return;
    }
    try {
      actionLoading.value = true;
      const payload: CreateHotUpdatePayload = {
        platform: formState.platform,
        app_version_id: formState.app_version_id,
        patch_version: formState.patch_version.trim(),
        channel: formState.channel.trim(),
        download_key: formState.download_key.trim(),
        download_url: formState.download_url || undefined,
        file_size: formState.file_size ?? undefined,
        checksum: formState.checksum || undefined,
        signature: formState.signature || undefined,
        rollout_percentage: formState.rollout_percentage,
        mandatory: formState.mandatory,
        description: formState.description || undefined,
        released_at: releasedAtValue.value
          ? releasedAtValue.value.toISOString()
          : undefined,
      };

      if (editingHotUpdate.value) {
        const updatePayload: UpdateHotUpdatePayload = {
          patch_version: payload.patch_version,
          channel: payload.channel,
          download_key: payload.download_key,
          download_url: payload.download_url,
          file_size: payload.file_size,
          checksum: payload.checksum,
          signature: payload.signature,
          rollout_percentage: payload.rollout_percentage,
          mandatory: payload.mandatory,
          description: payload.description,
          released_at: payload.released_at,
        };
        await updateHotUpdate(editingHotUpdate.value.id, updatePayload);
        Message.success('热更新已更新');
      } else {
        await createHotUpdate(payload);
        Message.success('热更新已创建');
      }
      await fetchHotUpdates();
      modalVisible.value = false;
      done(true);
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingHotUpdate.value ? '更新热更新失败' : '创建热更新失败');
      Message.error(errorMsg);
      done(false);
    } finally {
      actionLoading.value = false;
    }
  };

  const handleCancel = () => {
    if (actionLoading.value) return;
    modalVisible.value = false;
  };

  const handleDelete = async (record: HotUpdateInfo) => {
    try {
      await deleteHotUpdate(record.id);
      Message.success('删除成功');
      fetchHotUpdates();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '删除失败';
      Message.error(errorMsg);
    }
  };

  const handleToggleActive = async (record: HotUpdateInfo) => {
    toggleLoadingId.value = record.id;
    try {
      if (record.is_active) {
        await deactivateHotUpdate(record.id);
        Message.success('补丁已停用');
      } else {
        await activateHotUpdate(record.id);
        Message.success('补丁已启用');
      }
      fetchHotUpdates();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '操作失败';
      Message.error(errorMsg);
    } finally {
      toggleLoadingId.value = null;
    }
  };

  const triggerFileSelect = () => {
    fileInputRef.value?.click();
  };

  const handleFileSelected = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;
    const file = files && files.length > 0 ? files[0] : null;
    if (!file) return;
    if (!formState.channel || !formState.channel.trim()) {
      Message.error('请先填写渠道');
      inputEl.value = '';
      return;
    }
    uploadLoading.value = true;
    try {
      // 先计算文件哈希，用于后端去重
      let hashValue: string | null = null;
      let hashAlg: number | null = null;
      try {
        const hashResult = await computeFileHash(file);
        hashValue = hashResult.hashValue;
        hashAlg = hashResult.hashAlg;
        if (hashValue) {
          // eslint-disable-next-line no-console
          console.log('[HotUpdateUpload] 文件哈希计算完成:', {
            alg: hashAlg,
            value: hashValue,
            size: file.size,
          });
        } else {
          // eslint-disable-next-line no-console
          console.log('[HotUpdateUpload] 文件哈希未计算或不可用，将不参与去重');
        }
      } catch (hashError: any) {
        // eslint-disable-next-line no-console
        console.warn(
          '[HotUpdateUpload] 计算文件哈希失败，将跳过哈希上报:',
          hashError
        );
        hashValue = null;
        hashAlg = null;
      }

      if (file.size > MULTIPART_THRESHOLD_BYTES) {
        const { data } = await initiateVersionMultipartUpload({
          platform: formState.platform,
          channel: formState.channel.trim(),
          filename: file.name,
          file_size: file.size,
          hash_value: hashValue ?? undefined,
          hash_alg: hashAlg ?? undefined,
          content_type: file.type || undefined,
        });
        if (!data.success || !data.key) {
          throw new Error(data.message || '初始化分片上传失败');
        }

        if (!data.session_id) {
          // 命中哈希去重，复用已上传的补丁包
          formState.file_size = file.size;
          Message.success(data.message || '复用已上传的补丁包，无需重新上传');
          formState.download_key = data.key;
        } else {
          if (!data.part_size || !data.total_parts) {
            throw new Error(
              '分片上传初始化结果不完整（缺少 part_size/total_parts）'
            );
          }

          uploadedFileInfo.value = `${file.name} · ${formatFileSize(
            file.size
          )} · 0/${data.total_parts}`;
          await uploadFileByMultipartAndComplete({
            file,
            sessionId: data.session_id,
            partSize: data.part_size,
            totalParts: data.total_parts,
            onProgress: (uploadedParts, totalParts) => {
              uploadedFileInfo.value = `${file.name} · ${formatFileSize(
                file.size
              )} · ${uploadedParts}/${totalParts}`;
            },
            autoAbortOnError: true,
          });

          formState.file_size = file.size;
          formState.download_key = data.key;
          Message.success('补丁上传成功（分片直传）');
        }
      } else {
        const { data } = await generateVersionUploadSignature({
          platform: formState.platform,
          channel: formState.channel.trim(),
          filename: file.name,
          file_size: file.size,
          hash_value: hashValue ?? undefined,
          hash_alg: hashAlg ?? undefined,
        });
        if (!data.success || !data.key) {
          throw new Error(data.message || '获取直传签名失败');
        }

        if (data.signature) {
          const response = await uploadWithSignature(file, data.signature);
          if (!response.ok) {
            const text = await response.text();
            throw new Error(text || '上传失败');
          }
          formState.file_size = file.size;
          Message.success('补丁上传成功');
        } else {
          // 命中哈希去重，复用已上传的补丁包
          formState.file_size = file.size;
          Message.success(data.message || '复用已上传的补丁包，无需重新上传');
        }

        formState.download_key = data.key;
      }
      uploadedFileInfo.value = `${file.name} · ${formatFileSize(file.size)}`;
    } catch (error: any) {
      const errorMsg =
        error?.message || error?.response?.data?.message || '上传补丁失败';
      Message.error(errorMsg);
    } finally {
      uploadLoading.value = false;
      if (inputEl) {
        inputEl.value = '';
      }
    }
  };

  watch([platformFilter, channelFilter], () => {
    currentPage.value = 1;
    fetchHotUpdates();
  });

  watch(
    () => formState.platform,
    () => {
      loadVersionOptions();
    }
  );

  watch(
    () => formState.channel,
    () => {
      loadVersionOptions();
    }
  );

  onMounted(() => {
    loadVersionOptions();
    fetchHotUpdates();
  });
</script>

<style scoped>
  .hot-update-container {
    padding: 0 20px 20px;
  }

  .hot-update-container .general-card .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }

  .hot-update-container .general-card .hot-update-table {
    margin-top: 16px;
  }

  .table-pagination {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }

  .upload-info {
    color: #8c8c8c;
    font-size: 12px;
  }

  .hidden-file-input {
    display: none;
  }
</style>
