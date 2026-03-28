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
            allow-create
            :placeholder="t('versionManager.channel.placeholder')"
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
            {{ t('versionManager.action.create') }}
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            {{ t('versionManager.action.refresh') }}
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
        :scroll="{ x: tableScrollX }"
      >
        <template #channel="{ record }">
          <a-tag color="arcoblue">{{ record.channel }}</a-tag>
        </template>
        <template #mandatory="{ record }">
          <a-tag :color="record.mandatory ? 'red' : 'green'">
            {{
              record.mandatory
                ? t('versionManager.boolean.yes')
                : t('versionManager.boolean.no')
            }}
          </a-tag>
        </template>
        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{
              record.is_active
                ? t('versionManager.status.active')
                : t('versionManager.status.inactive')
            }}
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
              {{ t('versionManager.action.edit') }}
            </a-button>
            <a-button
              type="text"
              size="small"
              :loading="downloadLoadingId === record.id"
              @click="handleCopyDownloadLink(record)"
            >
              {{ t('versionManager.action.copyDownload') }}
            </a-button>
            <a-button
              v-if="record.is_active"
              type="text"
              size="small"
              :loading="deactivateLoadingId === record.id"
              @click="handleDeactivate(record)"
            >
              {{ t('versionManager.action.deactivate') }}
            </a-button>
            <a-popconfirm
              :content="t('versionManager.delete.confirm')"
              type="warning"
              @ok="handleDelete(record)"
            >
              <a-button
                type="text"
                size="small"
                status="danger"
                :loading="deleteLoadingId === record.id"
              >
                {{ t('versionManager.action.delete') }}
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
        <a-form-item field="version" :label="t('versionManager.field.version')">
          <a-input
            v-model="formState.version"
            :placeholder="t('versionManager.field.version.placeholder')"
            :disabled="isEditing"
          />
        </a-form-item>
        <a-form-item
          field="build_number"
          :label="t('versionManager.field.buildNumber')"
        >
          <a-input-number
            v-model="formState.build_number"
            :min="1"
            :disabled="isEditing"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item field="channel" :label="t('versionManager.field.channel')">
          <a-input
            v-model="formState.channel"
            :placeholder="t('versionManager.field.channel.placeholder')"
            :disabled="isEditing"
          />
        </a-form-item>
        <a-form-item
          field="download_key"
          :label="t('versionManager.field.downloadKey')"
        >
          <a-input
            v-model="formState.download_key"
            :placeholder="t('versionManager.field.downloadKey.placeholder')"
          />
        </a-form-item>
        <a-form-item :label="t('versionManager.field.packageUpload')">
          <a-space>
            <a-button
              type="outline"
              :loading="uploadLoading"
              @click="triggerFileSelect"
            >
              {{ t('versionManager.action.upload') }}
            </a-button>
            <span v-if="uploadedFileInfo" class="upload-info">
              {{ uploadedFileInfo }}
            </span>
          </a-space>
          <template #extra>
            {{ t('versionManager.field.packageUpload.help') }}
          </template>
        </a-form-item>
        <a-form-item field="download_url" :label="downloadUrlLabel">
          <a-input
            v-model="formState.download_url"
            :placeholder="t('versionManager.field.downloadUrl.placeholder')"
          />
        </a-form-item>
        <a-form-item
          v-if="showAppStoreUrlField"
          field="app_store_url"
          :label="appStoreUrlLabel"
        >
          <a-input
            v-model="formState.app_store_url"
            :placeholder="t('versionManager.field.appStore.placeholder')"
          />
        </a-form-item>
        <a-form-item
          field="release_notes"
          :label="t('versionManager.field.releaseNotes')"
        >
          <a-textarea
            v-model="formState.release_notes"
            :rows="4"
            :placeholder="t('versionManager.field.releaseNotes.placeholder')"
            allow-clear
          />
        </a-form-item>
        <a-form-item
          field="checksum"
          :label="t('versionManager.field.checksum')"
        >
          <a-input
            v-model="formState.checksum"
            :placeholder="t('versionManager.field.checksum.placeholder')"
          />
        </a-form-item>
        <a-form-item
          field="signature"
          :label="t('versionManager.field.signature')"
        >
          <a-input
            v-model="formState.signature"
            :placeholder="t('versionManager.field.signature.placeholder')"
          />
        </a-form-item>
        <a-form-item
          field="released_at"
          :label="t('versionManager.field.releasedAt')"
        >
          <a-date-picker
            v-model="releasedAtValue"
            show-time
            style="width: 100%"
            :placeholder="t('versionManager.field.releasedAt.placeholder')"
          />
        </a-form-item>
        <a-form-item
          field="mandatory"
          :label="t('versionManager.field.mandatory')"
        >
          <a-switch
            v-model="formState.mandatory"
            :checked-text="t('versionManager.boolean.yes')"
            :unchecked-text="t('versionManager.boolean.no')"
          />
        </a-form-item>
        <a-form-item
          field="is_active"
          :label="t('versionManager.field.enabled')"
        >
          <a-switch
            v-model="formState.is_active"
            :checked-text="t('versionManager.status.active')"
            :unchecked-text="t('versionManager.status.inactive')"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { computed, reactive, ref, watch } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { Message, type FormInstance } from '@arco-design/web-vue';
  import dayjs, { type Dayjs } from 'dayjs';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    listAppVersions,
    createAppVersion,
    updateAppVersion,
    deleteAppVersion,
    deactivateAppVersion,
    generateVersionUploadSignature,
    initiateVersionMultipartUpload,
    generateVersionDownloadUrl,
    type AppVersionInfo,
    type CreateAppVersionPayload,
    type UpdateAppVersionPayload,
    type ListAppVersionsParams,
    AppPlatform,
    PlatformLabels,
  } from '@/api/app-version';
  import { uploadWithSignature } from '@/utils/direct-upload';
  import { uploadFileByMultipartAndComplete } from '@/utils/multipart-upload';
  import { computeFileHash } from '@/utils/fileHash';

  const props = defineProps<{
    platform: 'frontend' | 'desktop';
  }>();
  const { t } = useI18n();

  const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024;

  const platformPresets: Record<'frontend' | 'desktop', AppPlatform[]> = {
    frontend: [AppPlatform.Android, AppPlatform.IOS],
    desktop: [AppPlatform.Windows, AppPlatform.MacOS, AppPlatform.Linux],
  };

  const platformOptions = computed(() => platformPresets[props.platform]);
  const selectedPlatform = ref<AppPlatform>(platformOptions.value[0]);

  interface VersionFormState {
    platform: AppPlatform;
    version: string;
    build_number: number;
    channel: string;
    download_key: string;
    download_url?: string;
    app_store_url?: string;
    release_notes?: string;
    checksum?: string;
    signature?: string;
    mandatory: boolean;
    is_active: boolean;
    file_size?: number | null;
  }

  const channelDefaults = [
    'stable',
    'stable-macos-intel',
    'stable-macos-arm64',
    'beta',
    'alpha',
    'dev',
  ];

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
    platform: selectedPlatform.value,
    version: '',
    build_number: 1,
    channel: 'stable',
    download_key: '',
    download_url: '',
    app_store_url: '',
    release_notes: '',
    checksum: '',
    signature: '',
    mandatory: false,
    is_active: true,
    file_size: null,
  });

  const formRules = computed(() => ({
    version: [
      { required: true, message: t('versionManager.validation.version') },
    ],
    build_number: [
      {
        required: true,
        type: 'number',
        message: t('versionManager.validation.buildNumber'),
      },
    ],
    channel: [
      { required: true, message: t('versionManager.validation.channel') },
    ],
  }));

  const columns = computed(() => [
    {
      title: t('versionManager.table.version'),
      dataIndex: 'version',
      width: 120,
      fixed: 'left' as const,
    },
    {
      title: t('versionManager.table.buildNumber'),
      dataIndex: 'build_number',
      width: 100,
    },
    {
      title: t('versionManager.table.channel'),
      dataIndex: 'channel',
      slotName: 'channel',
      width: 160,
    },
    {
      title: t('versionManager.table.downloadKey'),
      dataIndex: 'download_key',
      ellipsis: true,
      tooltip: true,
      width: 220,
    },
    {
      title: t('versionManager.table.appStore'),
      dataIndex: 'app_store_url',
      ellipsis: true,
      tooltip: true,
      width: 220,
    },
    {
      title: t('versionManager.table.fileSize'),
      dataIndex: 'file_size',
      slotName: 'file_size',
      width: 120,
    },
    {
      title: t('versionManager.table.mandatory'),
      dataIndex: 'mandatory',
      slotName: 'mandatory',
      width: 100,
    },
    {
      title: t('versionManager.table.status'),
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: t('versionManager.table.releasedAt'),
      dataIndex: 'released_at',
      slotName: 'released_at',
      width: 180,
    },
    {
      title: t('versionManager.table.updatedAt'),
      dataIndex: 'updated_at',
      slotName: 'updated_at',
      width: 180,
    },
    {
      title: t('versionManager.table.operations'),
      slotName: 'operations',
      width: 300,
      fixed: 'right',
    },
  ]);

  const tableScrollX = computed(() =>
    columns.value.reduce((sum, column) => {
      const width = typeof column.width === 'number' ? column.width : 150;
      return sum + width;
    }, 0),
  );

  const breadcrumbKey = computed(() =>
    props.platform === 'desktop'
      ? 'menu.version.desktop'
      : 'menu.version.frontend',
  );

  const cardTitle = computed(() =>
    props.platform === 'desktop'
      ? t('versionManager.title.desktop')
      : t('versionManager.title.frontend'),
  );

  const modalTitle = computed(() =>
    editingVersion.value
      ? t('versionManager.modal.edit')
      : t('versionManager.modal.create'),
  );

  const isEditing = computed(() => !!editingVersion.value);

  const showAppStoreUrlField = computed(
    () =>
      selectedPlatform.value === AppPlatform.IOS ||
      selectedPlatform.value === AppPlatform.MacOS,
  );

  const appStoreUrlLabel = computed(() =>
    selectedPlatform.value === AppPlatform.MacOS
      ? t('versionManager.field.appStore.macos')
      : t('versionManager.field.appStore.ios'),
  );

  const downloadUrlLabel = computed(() => {
    if (selectedPlatform.value === AppPlatform.IOS) {
      return t('versionManager.field.downloadUrl.ios');
    }
    if (selectedPlatform.value === AppPlatform.MacOS) {
      return t('versionManager.field.downloadUrl.macos');
    }
    return t('versionManager.field.downloadUrl.fallback');
  });

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
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('versionManager.fetch.error'),
        }),
      );
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
    formState.app_store_url = '';
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
    { immediate: true },
  );

  const handleCreate = () => {
    resetForm({ keepChannel: true });
    formState.channel = channelFilter.value || 'stable';
    if (versions.value.length > 0) {
      const maxBuild = Math.max(
        ...versions.value.map((item) => item.build_number),
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
    formState.app_store_url = record.app_store_url ?? '';
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
    const downloadKeyTrimmed = formState.download_key.trim();
    const downloadUrlTrimmed = (formState.download_url || '').trim();
    const appStoreUrlTrimmed = (formState.app_store_url || '').trim();
    if (!downloadKeyTrimmed && !downloadUrlTrimmed && !appStoreUrlTrimmed) {
      Message.error(t('versionManager.validation.downloadTarget'));
      return false;
    }

    actionLoading.value = true;
    try {
      const releaseAt = releasedAtValue.value
        ? releasedAtValue.value.toISOString()
        : undefined;
      if (editingVersion.value) {
        const payload: UpdateAppVersionPayload = {
          download_key: downloadKeyTrimmed,
          download_url: normalizeOptionalString(formState.download_url),
          app_store_url: normalizeOptionalString(formState.app_store_url),
          file_size: formState.file_size ?? undefined,
          checksum: normalizeOptionalString(formState.checksum),
          signature: normalizeOptionalString(formState.signature),
          release_notes: normalizeOptionalString(formState.release_notes),
          mandatory: formState.mandatory,
          is_active: formState.is_active,
          released_at: releaseAt ?? undefined,
        };
        await updateAppVersion(editingVersion.value.id, payload);
        Message.success(t('versionManager.update.success'));
      } else {
        const payload: CreateAppVersionPayload = {
          platform: selectedPlatform.value,
          version: formState.version.trim(),
          build_number: formState.build_number,
          channel: formState.channel.trim(),
          download_key: downloadKeyTrimmed,
          download_url:
            normalizeOptionalString(formState.download_url) ?? undefined,
          app_store_url:
            normalizeOptionalString(formState.app_store_url) ?? undefined,
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
        Message.success(t('versionManager.create.success'));
      }
      await fetchVersions();
      return true;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: editingVersion.value
            ? t('versionManager.update.error')
            : t('versionManager.create.error'),
        }),
      );
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
      Message.error(t('versionManager.validation.channelBeforeUpload'));
      inputEl.value = '';
      return;
    }
    uploadLoading.value = true;
    try {
      let hashValue: string | null = null;
      let hashAlg: number | null = null;
      try {
        const hashResult = await computeFileHash(file);
        hashValue = hashResult.hashValue;
        hashAlg = hashResult.hashAlg;
        if (hashValue) {
          // eslint-disable-next-line no-console
          console.log('[VersionUpload] File hash computed:', {
            alg: hashAlg,
            value: hashValue,
            size: file.size,
          });
        } else {
          // eslint-disable-next-line no-console
          console.log(
            '[VersionUpload] File hash unavailable. Deduplication skipped.',
          );
        }
      } catch (hashError: any) {
        // eslint-disable-next-line no-console
        console.warn(
          '[VersionUpload] Failed to compute file hash. Reporting skipped:',
          hashError,
        );
        hashValue = null;
        hashAlg = null;
      }

      if (file.size > MULTIPART_THRESHOLD_BYTES) {
        const { data } = await initiateVersionMultipartUpload({
          platform: selectedPlatform.value,
          channel: formState.channel.trim(),
          filename: file.name,
          file_size: file.size,
          hash_value: hashValue ?? undefined,
          hash_alg: hashAlg ?? undefined,
          content_type: file.type || undefined,
        });
        if (!data.success || !data.key) {
          throw new Error(data.message || t('versionManager.upload.error'));
        }

        if (!data.session_id) {
          formState.file_size = file.size;
          Message.success(data.message || t('versionManager.upload.dedup'));
          formState.download_key = data.key;
        } else {
          if (!data.part_size || !data.total_parts) {
            throw new Error(t('versionManager.upload.error'));
          }

          uploadedFileInfo.value = `${file.name} · ${formatFileSize(
            file.size,
          )} · 0/${data.total_parts}`;
          await uploadFileByMultipartAndComplete({
            file,
            sessionId: data.session_id,
            partSize: data.part_size,
            totalParts: data.total_parts,
            onProgress: (uploadedParts, totalParts) => {
              uploadedFileInfo.value = `${file.name} · ${formatFileSize(
                file.size,
              )} · ${uploadedParts}/${totalParts}`;
            },
            autoAbortOnError: true,
          });

          formState.file_size = file.size;
          formState.download_key = data.key;
          Message.success(t('versionManager.upload.multipartSuccess'));
        }
      } else {
        const { data } = await generateVersionUploadSignature({
          platform: selectedPlatform.value,
          channel: formState.channel.trim(),
          filename: file.name,
          file_size: file.size,
          hash_value: hashValue ?? undefined,
          hash_alg: hashAlg ?? undefined,
        });
        if (!data.success || !data.key) {
          throw new Error(data.message || t('versionManager.upload.error'));
        }

        if (data.signature) {
          const response = await uploadWithSignature(file, data.signature);
          if (!response.ok) {
            const text = await response.text();
            throw new Error(text || t('versionManager.upload.error'));
          }
          formState.file_size = file.size;
          Message.success(t('versionManager.upload.success'));
        } else {
          formState.file_size = file.size;
          Message.success(data.message || t('versionManager.upload.dedup'));
        }

        formState.download_key = data.key;
      }
      uploadedFileInfo.value = `${file.name} · ${formatFileSize(file.size)}`;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('versionManager.upload.error'),
        }),
      );
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
      Message.success(t('versionManager.deactivate.success'));
      await fetchVersions();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('versionManager.deactivate.error'),
        }),
      );
    } finally {
      deactivateLoadingId.value = null;
    }
  };

  const handleDelete = async (record: AppVersionInfo) => {
    deleteLoadingId.value = record.id;
    try {
      await deleteAppVersion(record.id);
      Message.success(t('versionManager.delete.success'));
      if (versions.value.length === 1 && currentPage.value > 1) {
        currentPage.value -= 1;
      }
      await fetchVersions();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('versionManager.delete.error'),
        }),
      );
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
    } catch (_clipboardError) {
      String(_clipboardError);
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
          Message.success(t('versionManager.download.success'));
        } else {
          Message.info(
            t('versionManager.download.fallback', {
              url: data.download_url,
            }),
          );
        }
      } else {
        Message.error(data.message || t('versionManager.download.error'));
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('versionManager.download.error'),
        }),
      );
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

  .hidden-file-input {
    display: none;
  }

  .upload-info {
    color: #4e5969;
  }
</style>
