<template>
  <div class="version-manager-container">
    <Breadcrumb :items="['menu.version', breadcrumbKey]" />
    <a-card class="general-card" :title="cardTitle" :bordered="false">
      <div class="actions">
        <a-space wrap>
          <a-select
            v-model="channelFilter"
            allow-clear
            allow-create
            placeholder="选择渠道（默认 stable）"
            style="min-width: 180px"
          >
            <a-option
              v-for="channel in availableChannels"
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
          />
        </a-form-item>
        <a-form-item field="build_number" label="构建号">
          <a-input-number
            v-model="formState.build_number"
            :min="1"
            :disabled="isEditing"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item field="channel" label="渠道">
          <a-input
            v-model="formState.channel"
            placeholder="例如：stable / beta"
            :disabled="isEditing"
          />
        </a-form-item>
        <a-form-item field="download_key" label="下载 Key">
          <a-input
            v-model="formState.download_key"
            placeholder="请先上传安装包或手动填写存储路径"
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
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, reactive, ref, watch } from 'vue';
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
  } from '@/api/app-version';
  import { uploadWithSignature } from '@/utils/direct-upload';

  const props = defineProps<{
    platform: 'frontend' | 'desktop';
  }>();

  interface VersionFormState {
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

  const channelDefaults = ['stable', 'beta', 'alpha', 'dev'];

  const listLoading = ref(false);
  const actionLoading = ref(false);
  const uploadLoading = ref(false);
  const versions = ref<AppVersionInfo[]>([]);
  const total = ref(0);
  const pageSize = ref(10);
  const currentPage = ref(1);
  const channelFilter = ref<string | undefined>('stable');

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
    version: '',
    build_number: 1,
    channel: 'stable',
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

  const isEditing = computed(() => !!editingVersion.value);

  const availableChannels = computed(() => {
    const set = new Set<string>();
    channelDefaults.forEach((item) => set.add(item));
    versions.value.forEach((item) => set.add(item.channel));
    if (formState.channel) {
      set.add(formState.channel);
    }
    return Array.from(set).sort();
  });

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
        platform: props.platform,
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
          platform: props.platform,
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
        platform: props.platform,
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

  onMounted(() => {
    fetchVersions();
  });
</script>

<style scoped>
  .version-manager-container {
    padding: 0 20px 20px;
  }

  .version-manager-container .general-card .actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 16px;
  }

  .version-manager-container .general-card .version-table {
    margin-top: 16px;
  }

  .table-pagination {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }

  .hidden-file-input {
    display: none;
  }

  .upload-info {
    color: #4e5969;
  }
</style>
