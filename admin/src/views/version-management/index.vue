<template>
  <div class="version-manager-container">
    <Breadcrumb :items="['menu.version', breadcrumbKey]" />
    <a-card class="general-card" :title="cardTitle" :bordered="false">
      <div class="actions">
        <div v-if="platformOptions.length > 0" class="platform-switch">
          <a-radio-group v-model="selectedPlatform" type="button">
            <a-radio
              v-for="option in platformOptions"
              :key="option"
              :value="option"
            >
              {{ PlatformLabels[option] }}
            </a-radio>
          </a-radio-group>
        </div>
        <a-space wrap>
          <a-select
            v-model="channelFilter"
            allow-clear
            placeholder="选择渠道（默认 stable）"
            style="min-width: 180px"
          >
            <a-option
              v-for="option in channelOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </a-option>
          </a-select>
          <a-button type="outline" @click="openChannelModal">管理渠道</a-button>
          <a-button type="primary" @click="handleCreate">
            <template #icon>
              <icon-plus />
            </template>
            新增版本
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="columns"
        :data="versions"
        :loading="listLoading"
        :pagination="false"
        row-key="id"
        class="version-table"
      >
        <template #channel="{ record }">
          <a-tag color="arcoblue">{{ record.channel }}</a-tag>
        </template>
        <template #mandatory="{ record }">
          <a-tag :color="record.mandatory ? 'red' : 'green'">
            {{ record.mandatory ? '是' : '否' }}
          </a-tag>
        </template>
        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{ record.is_active ? '启用' : '停用' }}
          </a-tag>
        </template>
        <template #file_size="{ record }">
          {{ formatFileSize(record.file_size) }}
        </template>
        <template #released_at="{ record }">
          {{ formatDateTime(record.released_at) }}
        </template>
        <template #updated_at="{ record }">
          {{ formatDateTime(record.updated_at) }}
        </template>
        <template #operations="{ record }">
          <a-space size="mini">
            <a-button type="text" size="small" @click="handleEdit(record)">
              编辑
            </a-button>
            <a-button
              type="text"
              size="small"
              :loading="downloadLoadingId === record.id"
              @click="handleCopyDownloadLink(record)"
            >
              下载链接
            </a-button>
            <a-button
              v-if="record.is_active"
              type="text"
              size="small"
              :loading="deactivateLoadingId === record.id"
              @click="handleDeactivate(record)"
            >
              停用
            </a-button>
            <a-popconfirm
              content="确定要删除该版本记录吗？"
              type="warning"
              @ok="handleDelete(record)"
            >
              <a-button
                type="text"
                size="small"
                status="danger"
                :loading="deleteLoadingId === record.id"
              >
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
        <a-form-item field="version" label="版本号">
          <a-input
            v-model="formState.version"
            placeholder="例如：1.2.3"
            :disabled="isEditing"
            @focus="focusedField = 'version'"
            @blur="focusedField = null"
          />
          <div
            v-if="focusedField === 'version' && versionHistory.length"
            class="input-suggestions"
          >
            <span>最近：</span>
            <a-tag
              v-for="item in versionHistory"
              :key="item"
              size="small"
              @click="applyVersionSuggestion(item)"
            >
              {{ item }}
            </a-tag>
          </div>
        </a-form-item>
        <a-form-item field="build_number" label="构建号">
          <a-input-number
            v-model="formState.build_number"
            :min="1"
            :disabled="isEditing"
            style="width: 100%"
            @focus="focusedField = 'build'"
            @blur="focusedField = null"
          />
          <div
            v-if="focusedField === 'build' && buildHistory.length"
            class="input-suggestions"
          >
            <span>最近：</span>
            <a-tag
              v-for="item in buildHistory"
              :key="item"
              size="small"
              @click="applyBuildSuggestion(item)"
            >
              {{ item }}
            </a-tag>
          </div>
        </a-form-item>
        <a-form-item field="channel" label="渠道">
          <a-select
            v-model="formState.channel"
            :disabled="isEditing"
            placeholder="请选择渠道"
            allow-clear
          >
            <a-option
              v-for="option in channelOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </a-option>
          </a-select>
          <template #extra>
            渠道由「管理渠道」入口维护，建议按环境划分（如 stable/beta）。
          </template>
        </a-form-item>
        <a-form-item field="download_key" label="下载 Key">
          <a-input
            v-model="formState.download_key"
            placeholder="请选择文件后自动生成"
            readonly
          />
        </a-form-item>
        <a-form-item label="安装包上传">
          <a-space>
            <a-button
              type="outline"
              :loading="uploadLoading"
              @click="triggerFileSelect"
            >
              选择文件并上传
            </a-button>
            <span v-if="uploadedFileInfo" class="upload-info">
              {{ uploadedFileInfo }}
            </span>
          </a-space>
          <template #extra>
            文件将直接上传到默认存储提供商，完成后自动填充下载 Key。
          </template>
        </a-form-item>
        <a-form-item field="download_url" label="备用下载地址">
          <a-input
            v-model="formState.download_url"
            placeholder="可选：填写备用 CDN 或下载地址"
          />
        </a-form-item>
        <a-form-item field="release_notes" label="更新说明">
          <a-textarea
            v-model="formState.release_notes"
            :rows="4"
            placeholder="可选：填写本次版本的更新说明"
            allow-clear
          />
        </a-form-item>
        <a-form-item field="checksum" label="校验摘要">
          <a-input
            v-model="formState.checksum"
            placeholder="可选：MD5/SHA 摘要值"
          />
        </a-form-item>
        <a-form-item field="signature" label="签名信息">
          <a-input
            v-model="formState.signature"
            placeholder="可选：签名或公钥信息"
          />
        </a-form-item>
        <a-form-item field="released_at" label="发布时间">
          <a-date-picker
            v-model="releasedAtValue"
            show-time
            style="width: 100%"
            placeholder="选择发布时间（可选）"
          />
        </a-form-item>
        <a-form-item field="mandatory" label="强制更新">
          <a-switch
            v-model="formState.mandatory"
            checked-text="是"
            unchecked-text="否"
          />
        </a-form-item>
        <a-form-item field="is_active" label="启用状态">
          <a-switch
            v-model="formState.is_active"
            checked-text="启用"
            unchecked-text="停用"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <a-modal
      v-model:visible="channelModalVisible"
      title="管理渠道"
      :width="520"
      ok-text="保存渠道"
      cancel-text="取消"
      @before-ok="handleChannelBeforeOk"
      @cancel="channelModalVisible = false"
    >
      <a-form
        ref="channelFormRef"
        :model="channelForm"
        :rules="channelFormRules"
        label-align="left"
        :label-col-props="{ span: 6 }"
        :wrapper-col-props="{ span: 18 }"
      >
        <a-form-item field="name" label="渠道名称">
          <a-input v-model="channelForm.name" placeholder="例如：稳定渠道" />
        </a-form-item>
        <a-form-item field="code" label="渠道编码">
          <a-input
            v-model="channelForm.code"
            placeholder="例如：stable"
            allow-clear
          />
        </a-form-item>
        <a-form-item field="description" label="备注">
          <a-input
            v-model="channelForm.description"
            placeholder="可选：说明渠道用途"
          />
        </a-form-item>
      </a-form>
      <div class="channel-list">
        <div
          v-for="item in channelPresets"
          :key="item.code"
          class="channel-list__item"
        >
          <div class="channel-list__title">
            {{ item.name }}（{{ item.code }}）
          </div>
          <div class="channel-list__desc">
            {{ item.description || '暂无备注' }}
          </div>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { computed, reactive, ref, watch } from 'vue';
  import type { Ref } from 'vue';
  import { Message, type FormInstance } from '@arco-design/web-vue';
  import dayjs, { type Dayjs } from 'dayjs';
  import {
    listAppVersions,
    createAppVersion,
    updateAppVersion,
    deleteAppVersion,
    deactivateAppVersion,
    generateVersionUploadSignature,
    generateVersionDownloadUrl,
    type AppVersionInfo,
    type CreateAppVersionPayload,
    type UpdateAppVersionPayload,
    type ListAppVersionsParams,
    AppPlatform,
    PlatformLabels,
  } from '@/api/app-version';
  import { uploadWithSignature } from '@/utils/direct-upload';

  const props = defineProps<{
    platform: 'frontend' | 'desktop';
  }>();

  const platformPresets: Record<'frontend' | 'desktop', AppPlatform[]> = {
    frontend: [AppPlatform.Android, AppPlatform.IOS],
    desktop: [AppPlatform.Windows, AppPlatform.MacOS, AppPlatform.Linux],
  };

  const platformOptions = computed(() => platformPresets[props.platform]);
  const selectedPlatform = ref<AppPlatform>(platformOptions.value[0]);

  interface ChannelPreset {
    name: string;
    code: string;
    description?: string;
  }

  const DEFAULT_CHANNELS: ChannelPreset[] = [
    { name: 'Stable', code: 'stable', description: '生产稳定渠道' },
    { name: 'Beta', code: 'beta', description: '灰度/公测渠道' },
    { name: 'Alpha', code: 'alpha', description: '内部测试渠道' },
    { name: 'Dev', code: 'dev', description: '开发验证渠道' },
  ];

  const CHANNEL_STORAGE_KEY = 'version_manager_channel_presets';
  const VERSION_HISTORY_KEY = 'version_manager_version_history';
  const BUILD_HISTORY_KEY = 'version_manager_build_history';

  const loadChannelPresets = (): ChannelPreset[] => {
    try {
      const stored = localStorage.getItem(CHANNEL_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed) && parsed.length) {
          return parsed;
        }
      }
    } catch (error) {
      // ignore parse errors
    }
    return DEFAULT_CHANNELS;
  };

  const channelPresets = ref<ChannelPreset[]>(loadChannelPresets());
  const channelOptions = computed(() =>
    channelPresets.value.map((item) => ({
      label: `${item.name} (${item.code})`,
      value: item.code,
    }))
  );

  const saveChannelPresets = () => {
    localStorage.setItem(
      CHANNEL_STORAGE_KEY,
      JSON.stringify(channelPresets.value)
    );
  };

  interface VersionFormState {
    platform: AppPlatform;
    version: string;
    build_number: number;
    channel: string;
    download_key: string;
    download_url?: string;
    release_notes?: string;
    checksum?: string;
    signature?: string;
    mandatory: boolean;
    is_active: boolean;
    file_size?: number | null;
  }

  const listLoading = ref(false);
  const actionLoading = ref(false);
  const uploadLoading = ref(false);
  const versions = ref<AppVersionInfo[]>([]);
  const total = ref(0);
  const pageSize = ref(10);
  const currentPage = ref(1);
  const channelFilter = ref<string | undefined>(
    channelOptions.value[0]?.value || 'stable'
  );

  const channelModalVisible = ref(false);
  const channelFormRef = ref<FormInstance>();
  const channelForm = reactive({
    name: '',
    code: '',
    description: '',
  });

  const channelFormRules = {
    name: [{ required: true, message: '请输入渠道名称' }],
    code: [{ required: true, message: '请输入渠道编码' }],
  };

  const modalVisible = ref(false);
  const formRef = ref<FormInstance>();
  const editingVersion = ref<AppVersionInfo | null>(null);
  const releasedAtValue = ref<Dayjs | null>(null);
  const fileInputRef = ref<HTMLInputElement | null>(null);
  const uploadedFileInfo = ref<string>('');

  const deactivateLoadingId = ref<string | null>(null);
  const deleteLoadingId = ref<string | null>(null);
  const downloadLoadingId = ref<string | null>(null);

  const formState = reactive<VersionFormState>({
    platform: selectedPlatform.value,
    version: '',
    build_number: 1,
    channel: channelFilter.value || 'stable',
    download_key: '',
    download_url: '',
    release_notes: '',
    checksum: '',
    signature: '',
    mandatory: false,
    is_active: true,
    file_size: null,
  });

  const formRules = {
    version: [{ required: true, message: '请输入版本号' }],
    build_number: [{ required: true, type: 'number', message: '请输入构建号' }],
    channel: [{ required: true, message: '请输入渠道标识' }],
    download_key: [{ required: true, message: '请上传安装包或填写下载 Key' }],
  };

  const isEditing = computed(() => !!editingVersion.value);

  const versionHistory = ref<string[]>(
    JSON.parse(localStorage.getItem(VERSION_HISTORY_KEY) || '[]')
  );
  const buildHistory = ref<number[]>(
    JSON.parse(localStorage.getItem(BUILD_HISTORY_KEY) || '[]')
  );

  const focusedField = ref<'version' | 'build' | null>(null);

  const updateHistory = <T extends string | number>(
    history: Ref<T[]>,
    value: T,
    storageKey: string,
    limit = 5
  ) => {
    const list = history.value.filter((item) => item !== value);
    list.unshift(value);
    history.value = list.slice(0, limit);
    localStorage.setItem(storageKey, JSON.stringify(history.value));
  };

  const applyVersionSuggestion = (value: string) => {
    formState.version = value;
    focusedField.value = null;
  };

  const applyBuildSuggestion = (value: number) => {
    formState.build_number = value;
    focusedField.value = null;
  };

  const resetChannelForm = () => {
    channelForm.name = '';
    channelForm.code = '';
    channelForm.description = '';
    channelFormRef.value?.clearValidate();
  };

  const openChannelModal = () => {
    resetChannelForm();
    channelModalVisible.value = true;
  };

  const handleChannelBeforeOk = async (done: (closed: boolean) => void) => {
    if (!channelFormRef.value) {
      done(false);
      return;
    }
    const errors = await channelFormRef.value.validate();
    if (errors) {
      done(false);
      return;
    }
    const name = channelForm.name.trim();
    const code = channelForm.code.trim();
    if (!name || !code) {
      Message.error('请填写完整的渠道信息');
      done(false);
      return;
    }
    const exists = channelPresets.value.some(
      (item) => item.code.toLowerCase() === code.toLowerCase()
    );
    if (exists) {
      Message.error('渠道编码已存在');
      done(false);
      return;
    }
    channelPresets.value = [
      ...channelPresets.value,
      {
        name,
        code,
        description: channelForm.description.trim() || undefined,
      },
    ];
    channelFilter.value = code;
    if (!isEditing.value) {
      formState.channel = code;
    }
    Message.success('新增渠道成功');
    done(true);
  };

  const columns = [
    { title: '版本号', dataIndex: 'version', width: 120 },
    { title: '构建号', dataIndex: 'build_number', width: 100 },
    { title: '渠道', dataIndex: 'channel', slotName: 'channel', width: 120 },
    {
      title: '下载 Key',
      dataIndex: 'download_key',
      ellipsis: true,
      tooltip: true,
      width: 220,
    },
    {
      title: '文件大小',
      dataIndex: 'file_size',
      slotName: 'file_size',
      width: 120,
    },
    {
      title: '强制更新',
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
    {
      title: '更新时间',
      dataIndex: 'updated_at',
      slotName: 'updated_at',
      width: 180,
    },
    { title: '操作', slotName: 'operations', width: 260, fixed: 'right' },
  ];

  const breadcrumbKey = computed(() =>
    props.platform === 'desktop'
      ? 'menu.version.desktop'
      : 'menu.version.frontend'
  );

  const cardTitle = computed(() =>
    props.platform === 'desktop' ? '桌面客户端版本管理' : 'App客户端版本管理'
  );

  const modalTitle = computed(() =>
    editingVersion.value ? '编辑版本信息' : '新增版本'
  );

  const formatDateTime = (value?: string | null) => {
    if (!value) return '-';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

  const formatFileSize = (size?: number | null) => {
    if (!size || size <= 0) return '-';
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    }
    if (size < 1024 * 1024 * 1024) {
      return `${(size / 1024 / 1024).toFixed(2)} MB`;
    }
    return `${(size / 1024 / 1024 / 1024).toFixed(2)} GB`;
  };

  const fetchVersions = async () => {
    listLoading.value = true;
    try {
      const params: ListAppVersionsParams = {
        platform: selectedPlatform.value,
        limit: pageSize.value,
        offset: (currentPage.value - 1) * pageSize.value,
      };
      if (channelFilter.value) {
        params.channel = channelFilter.value;
      }
      const { data } = await listAppVersions(params);
      versions.value = data.items;
      total.value = data.total;
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '加载版本列表失败';
      Message.error(errorMsg);
    } finally {
      listLoading.value = false;
    }
  };

  const resetForm = (options?: { keepChannel?: boolean }) => {
    formState.platform = selectedPlatform.value;
    formState.version = '';
    formState.build_number = 1;
    formState.channel = options?.keepChannel
      ? formState.channel
      : channelFilter.value || 'stable';
    formState.download_key = '';
    formState.download_url = '';
    formState.release_notes = '';
    formState.checksum = '';
    formState.signature = '';
    formState.mandatory = false;
    formState.is_active = true;
    formState.file_size = null;
    releasedAtValue.value = null;
    uploadedFileInfo.value = '';
    editingVersion.value = null;
  };

  watch(platformOptions, (options) => {
    if (!options.includes(selectedPlatform.value)) {
      const [firstOption] = options;
      if (firstOption) {
        selectedPlatform.value = firstOption;
      }
    }
  });

  watch(
    selectedPlatform,
    (platform) => {
      formState.platform = platform;
      currentPage.value = 1;
      fetchVersions();
    },
    { immediate: true }
  );

  watch(
    channelPresets,
    () => {
      saveChannelPresets();
      if (
        channelFilter.value &&
        !channelPresets.value.some((item) => item.code === channelFilter.value)
      ) {
        channelFilter.value = channelPresets.value[0]?.code;
      }
      if (
        formState.channel &&
        !channelPresets.value.some((item) => item.code === formState.channel)
      ) {
        formState.channel = channelPresets.value[0]?.code || '';
      }
    },
    { deep: true }
  );

  const handleCreate = () => {
    resetForm({ keepChannel: true });
    formState.channel = channelFilter.value || 'stable';
    if (versions.value.length > 0) {
      const maxBuild = Math.max(
        ...versions.value.map((item) => item.build_number)
      );
      formState.build_number = maxBuild + 1;
    }
    modalVisible.value = true;
  };

  const fillFormForEdit = (record: AppVersionInfo) => {
    const recordPlatform = record.platform as AppPlatform;
    if (platformOptions.value.includes(recordPlatform)) {
      selectedPlatform.value = recordPlatform;
    } else {
      formState.platform = recordPlatform;
    }
    formState.version = record.version;
    formState.build_number = record.build_number;
    formState.channel = record.channel;
    formState.download_key = record.download_key;
    formState.download_url = record.download_url ?? '';
    formState.release_notes = record.release_notes ?? '';
    formState.checksum = record.checksum ?? '';
    formState.signature = record.signature ?? '';
    formState.mandatory = record.mandatory;
    formState.is_active = record.is_active;
    formState.file_size = record.file_size ?? null;
    releasedAtValue.value = record.released_at
      ? dayjs(record.released_at)
      : null;
    uploadedFileInfo.value = record.file_size
      ? `${record.version} · ${formatFileSize(record.file_size)}`
      : '';
  };

  const handleEdit = (record: AppVersionInfo) => {
    editingVersion.value = record;
    fillFormForEdit(record);
    modalVisible.value = true;
  };

  const handlePageChange = (page: number) => {
    currentPage.value = page;
    fetchVersions();
  };

  const handlePageSizeChange = (size: number) => {
    pageSize.value = size;
    currentPage.value = 1;
    fetchVersions();
  };

  const normalizeOptionalString = (value?: string | null) => {
    if (value === undefined || value === null) {
      return undefined;
    }
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  };

  const handleSubmit = async () => {
    if (!formRef.value) return false;
    const errors = await formRef.value.validate();
    if (errors) {
      return false;
    }
    if (!formState.download_key) {
      Message.error('请上传安装包或填写下载 Key');
      return false;
    }

    actionLoading.value = true;
    try {
      const releaseAt = releasedAtValue.value
        ? releasedAtValue.value.toISOString()
        : undefined;
      if (editingVersion.value) {
        const payload: UpdateAppVersionPayload = {
          download_key: formState.download_key.trim(),
          download_url: normalizeOptionalString(formState.download_url),
          file_size: formState.file_size ?? undefined,
          checksum: normalizeOptionalString(formState.checksum),
          signature: normalizeOptionalString(formState.signature),
          release_notes: normalizeOptionalString(formState.release_notes),
          mandatory: formState.mandatory,
          is_active: formState.is_active,
          released_at: releaseAt ?? undefined,
        };
        await updateAppVersion(editingVersion.value.id, payload);
        Message.success('版本信息已更新');
      } else {
        const payload: CreateAppVersionPayload = {
          platform: selectedPlatform.value,
          version: formState.version.trim(),
          build_number: formState.build_number,
          channel: formState.channel.trim(),
          download_key: formState.download_key.trim(),
          download_url:
            normalizeOptionalString(formState.download_url) ?? undefined,
          file_size: formState.file_size ?? undefined,
          checksum: normalizeOptionalString(formState.checksum) ?? undefined,
          signature: normalizeOptionalString(formState.signature) ?? undefined,
          release_notes:
            normalizeOptionalString(formState.release_notes) ?? undefined,
          mandatory: formState.mandatory,
          is_active: formState.is_active,
          released_at: releaseAt,
        };
        await createAppVersion(payload);
        updateHistory(versionHistory, payload.version, VERSION_HISTORY_KEY);
        updateHistory(buildHistory, payload.build_number, BUILD_HISTORY_KEY);
        Message.success('新增版本成功');
      }
      await fetchVersions();
      return true;
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        (editingVersion.value ? '更新版本失败' : '新增版本失败');
      Message.error(errorMsg);
      return false;
    } finally {
      actionLoading.value = false;
    }
  };

  const handleBeforeOk = async (done: (closed: boolean) => void) => {
    const result = await handleSubmit();
    if (result) {
      modalVisible.value = false;
      resetForm({ keepChannel: true });
    }
    done(result);
  };

  const handleCancel = () => {
    if (actionLoading.value) return;
    modalVisible.value = false;
    resetForm({ keepChannel: true });
  };

  const handleRefresh = () => {
    fetchVersions();
  };

  const triggerFileSelect = () => {
    fileInputRef.value?.click();
  };

  const handleFileSelected = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;
    const file = files && files.length > 0 ? files[0] : null;
    if (!file) {
      return;
    }
    if (!formState.channel || !formState.channel.trim()) {
      Message.error('请先填写渠道标识');
      inputEl.value = '';
      return;
    }
    uploadLoading.value = true;
    try {
      const { data } = await generateVersionUploadSignature({
        platform: selectedPlatform.value,
        channel: formState.channel.trim(),
        filename: file.name,
      });
      if (!data.success || !data.signature || !data.key) {
        throw new Error(data.message || '获取直传签名失败');
      }
      const response = await uploadWithSignature(file, data.signature);
      if (!response.ok) {
        const text = await response.text();
        throw new Error(text || '上传失败');
      }
      formState.download_key = data.key;
      formState.file_size = file.size;
      uploadedFileInfo.value = `${file.name} · ${formatFileSize(file.size)}`;
      Message.success('安装包上传成功');
    } catch (error: any) {
      const errorMsg =
        error?.message || error?.response?.data?.message || '上传安装包失败';
      Message.error(errorMsg);
    } finally {
      uploadLoading.value = false;
      if (inputEl) {
        inputEl.value = '';
      }
    }
  };

  const handleDeactivate = async (record: AppVersionInfo) => {
    deactivateLoadingId.value = record.id;
    try {
      await deactivateAppVersion(record.id);
      Message.success('已停用该版本');
      await fetchVersions();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '停用版本失败';
      Message.error(errorMsg);
    } finally {
      deactivateLoadingId.value = null;
    }
  };

  const handleDelete = async (record: AppVersionInfo) => {
    deleteLoadingId.value = record.id;
    try {
      await deleteAppVersion(record.id);
      Message.success('删除成功');
      if (versions.value.length === 1 && currentPage.value > 1) {
        currentPage.value -= 1;
      }
      await fetchVersions();
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '删除版本失败';
      Message.error(errorMsg);
    } finally {
      deleteLoadingId.value = null;
    }
  };

  const copyToClipboard = async (text: string) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        return true;
      }
    } catch (_) {
      // 忽略异常，尝试降级方案
    }
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.focus();
    textarea.select();
    try {
      const successful = document.execCommand('copy');
      return successful;
    } catch (_) {
      return false;
    } finally {
      document.body.removeChild(textarea);
    }
  };

  const handleCopyDownloadLink = async (record: AppVersionInfo) => {
    downloadLoadingId.value = record.id;
    try {
      const { data } = await generateVersionDownloadUrl({
        id: record.id,
        expires_in_seconds: 600,
      });
      if (data.success && data.download_url) {
        const copied = await copyToClipboard(data.download_url);
        if (copied) {
          Message.success('下载链接已复制（10 分钟内有效）');
        } else {
          Message.info(`下载链接：${data.download_url}`);
        }
      } else {
        Message.error(data.message || '生成下载链接失败');
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '生成下载链接失败';
      Message.error(errorMsg);
    } finally {
      downloadLoadingId.value = null;
    }
  };

  watch(channelFilter, () => {
    currentPage.value = 1;
    fetchVersions();
  });
</script>

<style scoped>
  .version-manager-container {
    padding: 0 20px 20px;
  }

  .version-manager-container .general-card .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }

  .platform-switch {
    display: flex;
    align-items: center;
  }

  .version-manager-container .general-card .version-table {
    margin-top: 16px;
  }

  .table-pagination {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }

  .input-suggestions {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    align-items: center;
    margin-top: 6px;
    color: #8c8c8c;
    font-size: 12px;
  }

  .input-suggestions span {
    margin-right: 2px;
  }

  .channel-list {
    max-height: 200px;
    margin-top: 16px;
    padding-right: 4px;
    overflow-y: auto;
  }

  .channel-list__item {
    padding: 8px 0;
    border-bottom: 1px solid #f0f0f0;
  }

  .channel-list__title {
    color: #1d2129;
    font-weight: 600;
  }

  .channel-list__desc {
    color: #8c8c8c;
    font-size: 12px;
  }

  .hidden-file-input {
    display: none;
  }

  .upload-info {
    color: #4e5969;
  }
</style>
