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
            :placeholder="t('hotUpdate.channel.placeholder')"
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
            {{ t('hotUpdate.action.create') }}
          </a-button>
          <a-button :loading="listLoading" @click="fetchHotUpdates">
            <template #icon>
              <icon-refresh />
            </template>
            {{ t('hotUpdate.action.refresh') }}
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
            {{
              record.mandatory
                ? t('hotUpdate.status.mandatory')
                : t('hotUpdate.status.optional')
            }}
          </a-tag>
        </template>
        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{
              record.is_active
                ? t('hotUpdate.status.active')
                : t('hotUpdate.status.inactive')
            }}
          </a-tag>
        </template>
        <template #released_at="{ record }">
          {{ formatDateTime(record.released_at) }}
        </template>
        <template #operations="{ record }">
          <a-space size="mini">
            <a-button type="text" size="small" @click="handleEdit(record)">
              {{ t('hotUpdate.action.edit') }}
            </a-button>
            <a-button
              type="text"
              size="small"
              :loading="toggleLoadingId === record.id"
              @click="handleToggleActive(record)"
            >
              {{
                record.is_active
                  ? t('hotUpdate.action.disable')
                  : t('hotUpdate.action.enable')
              }}
            </a-button>
            <a-popconfirm
              :content="t('hotUpdate.delete.confirm')"
              type="warning"
              @ok="handleDelete(record)"
            >
              <a-button type="text" size="small" status="danger">
                {{ t('hotUpdate.action.delete') }}
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
        <a-form-item field="platform" :label="t('hotUpdate.field.platform')">
          <a-select
            v-model="formState.platform"
            :options="platformOptions"
            @change="loadVersionOptions"
          />
        </a-form-item>
        <a-form-item
          field="app_version_id"
          :label="t('hotUpdate.field.baseVersion')"
        >
          <a-select
            v-model="formState.app_version_id"
            :placeholder="t('hotUpdate.field.baseVersion.placeholder')"
            :options="versionOptions"
            allow-search
          />
        </a-form-item>
        <a-form-item
          field="patch_version"
          :label="t('hotUpdate.field.patchVersion')"
        >
          <a-input
            v-model="formState.patch_version"
            :placeholder="t('hotUpdate.field.patchVersion.placeholder')"
          />
        </a-form-item>
        <a-form-item field="channel" :label="t('hotUpdate.field.channel')">
          <a-select
            v-model="formState.channel"
            :options="channelSelectOptions"
            allow-clear
          />
        </a-form-item>
        <a-form-item
          field="download_key"
          :label="t('hotUpdate.field.patchKey')"
        >
          <a-input
            v-model="formState.download_key"
            :placeholder="t('hotUpdate.field.patchKey.placeholder')"
            readonly
          />
        </a-form-item>
        <a-form-item :label="t('hotUpdate.field.patchUpload')">
          <a-space>
            <a-button
              type="outline"
              :loading="uploadLoading"
              @click="triggerFileSelect"
            >
              {{ t('hotUpdate.action.upload') }}
            </a-button>
            <span v-if="uploadedFileInfo" class="upload-info">{{
              uploadedFileInfo
            }}</span>
          </a-space>
          <template #extra>
            {{ t('hotUpdate.field.patchUpload.help') }}
          </template>
        </a-form-item>
        <a-form-item
          field="download_url"
          :label="t('hotUpdate.field.downloadUrl')"
        >
          <a-input
            v-model="formState.download_url"
            :placeholder="t('hotUpdate.field.downloadUrl.placeholder')"
          />
        </a-form-item>
        <a-form-item field="file_size" :label="t('hotUpdate.field.fileSize')">
          <a-input-number
            v-model="formState.file_size"
            :min="0"
            style="width: 100%"
            :placeholder="t('hotUpdate.field.optional')"
          />
        </a-form-item>
        <a-form-item field="checksum" :label="t('hotUpdate.field.checksum')">
          <a-input
            v-model="formState.checksum"
            :placeholder="t('hotUpdate.field.checksum.placeholder')"
          />
        </a-form-item>
        <a-form-item field="signature" :label="t('hotUpdate.field.signature')">
          <a-input
            v-model="formState.signature"
            :placeholder="t('hotUpdate.field.optional')"
          />
        </a-form-item>
        <a-form-item
          field="rollout_percentage"
          :label="t('hotUpdate.field.rollout')"
        >
          <a-input-number
            v-model="formState.rollout_percentage"
            :min="0"
            :max="100"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item field="mandatory" :label="t('hotUpdate.field.mandatory')">
          <a-switch
            v-model="formState.mandatory"
            :checked-text="t('versionManager.boolean.yes')"
            :unchecked-text="t('versionManager.boolean.no')"
          />
        </a-form-item>
        <a-form-item
          field="released_at"
          :label="t('hotUpdate.field.releasedAt')"
        >
          <a-date-picker
            v-model="releasedAtValue"
            show-time
            style="width: 100%"
            :placeholder="t('hotUpdate.field.optional')"
          />
        </a-form-item>
        <a-form-item
          field="description"
          :label="t('hotUpdate.field.description')"
        >
          <a-textarea
            v-model="formState.description"
            :rows="3"
            :placeholder="t('hotUpdate.field.description.placeholder')"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, reactive, ref, watch } from 'vue';
  import { useI18n } from 'vue-i18n';
  import dayjs, { type Dayjs } from 'dayjs';
  import { Message, type FormInstance } from '@arco-design/web-vue';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
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
  } from '@/api/hot-update';
  import {
    listAppVersions,
    getAppVersion,
    generateVersionUploadSignature,
    initiateVersionMultipartUpload,
    type AppVersionInfo,
    AppPlatform,
    PlatformLabels,
  } from '@/api/app-version';
  import { uploadWithSignature } from '@/utils/direct-upload';
  import { uploadFileByMultipartAndComplete } from '@/utils/multipart-upload';
  import { computeFileHash } from '@/utils/fileHash';

  const { t } = useI18n();

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
  const releasedAtValue = ref<Dayjs | null>(null);
  const uploadedFileInfo = ref('');

  const versionOptions = ref<{ label: string; value: string }[]>([]);

  type HotUpdateFormState = Omit<CreateHotUpdatePayload, 'platform'> & {
    platform: AppPlatform;
    file_size?: number | null;
  };

  function getDefaultFormState(): HotUpdateFormState {
    return {
      platform: AppPlatform.Android,
      app_version_id: '',
      patch_version: '',
      channel: 'stable',
      download_key: '',
      download_url: '',
      file_size: null,
      checksum: '',
      signature: '',
      rollout_percentage: 100,
      mandatory: false,
      description: '',
    };
  }

  const formState = reactive<HotUpdateFormState>(getDefaultFormState());

  const formRules = computed(() => ({
    platform: [{ required: true, message: t('hotUpdate.validation.platform') }],
    app_version_id: [
      { required: true, message: t('hotUpdate.validation.baseVersion') },
    ],
    patch_version: [
      { required: true, message: t('hotUpdate.validation.patchVersion') },
    ],
    channel: [{ required: true, message: t('hotUpdate.validation.channel') }],
    download_key: [
      { required: true, message: t('hotUpdate.validation.patchFile') },
    ],
    rollout_percentage: [
      { required: true, message: t('hotUpdate.validation.rollout') },
    ],
  }));

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

  const columns = computed(() => [
    {
      title: t('hotUpdate.table.platform'),
      dataIndex: 'platform',
      slotName: 'platform',
      width: 120,
    },
    {
      title: t('hotUpdate.table.baseVersion'),
      dataIndex: 'app_version_id',
      slotName: 'baseVersion',
      width: 160,
    },
    {
      title: t('hotUpdate.table.patchVersion'),
      dataIndex: 'patch_version',
      width: 150,
    },
    { title: t('hotUpdate.table.channel'), dataIndex: 'channel', width: 120 },
    {
      title: t('hotUpdate.table.rollout'),
      dataIndex: 'rollout_percentage',
      slotName: 'rollout',
      width: 160,
    },
    {
      title: t('hotUpdate.table.mandatory'),
      dataIndex: 'mandatory',
      slotName: 'mandatory',
      width: 100,
    },
    {
      title: t('hotUpdate.table.status'),
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: t('hotUpdate.table.releasedAt'),
      dataIndex: 'released_at',
      slotName: 'released_at',
      width: 180,
    },
    {
      title: t('hotUpdate.table.operations'),
      slotName: 'operations',
      width: 240,
      fixed: 'right',
    },
  ]);

  const cardTitle = computed(() => t('hotUpdate.title'));

  const modalTitle = computed(() =>
    editingHotUpdate.value
      ? t('hotUpdate.modal.edit')
      : t('hotUpdate.modal.create')
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
        } catch {
          /* Ignore cache warm-up failures for individual versions. */
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
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('hotUpdate.fetch.error'),
        })
      );
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
    releasedAtValue.value = null;
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
      file_size: record.file_size ?? null,
      checksum: record.checksum || '',
      signature: record.signature || '',
      rollout_percentage: record.rollout_percentage,
      mandatory: record.mandatory,
      description: record.description || '',
    });
    releasedAtValue.value = record.released_at
      ? dayjs(record.released_at)
      : null;
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
        Message.success(t('hotUpdate.update.success'));
      } else {
        await createHotUpdate(payload);
        Message.success(t('hotUpdate.create.success'));
      }
      await fetchHotUpdates();
      modalVisible.value = false;
      done(true);
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: editingHotUpdate.value
            ? t('hotUpdate.update.error')
            : t('hotUpdate.create.error'),
        })
      );
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
      Message.success(t('hotUpdate.delete.success'));
      fetchHotUpdates();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('hotUpdate.delete.error'),
        })
      );
    }
  };

  const handleToggleActive = async (record: HotUpdateInfo) => {
    toggleLoadingId.value = record.id;
    try {
      if (record.is_active) {
        await deactivateHotUpdate(record.id);
        Message.success(t('hotUpdate.toggle.disableSuccess'));
      } else {
        await activateHotUpdate(record.id);
        Message.success(t('hotUpdate.toggle.enableSuccess'));
      }
      fetchHotUpdates();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('hotUpdate.toggle.error'),
        })
      );
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
      Message.error(t('hotUpdate.validation.channelBeforeUpload'));
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
          console.log('[HotUpdateUpload] File hash computed:', {
            alg: hashAlg,
            value: hashValue,
            size: file.size,
          });
        } else {
          // eslint-disable-next-line no-console
          console.log(
            '[HotUpdateUpload] File hash unavailable. Deduplication skipped.'
          );
        }
      } catch (hashError: any) {
        // eslint-disable-next-line no-console
        console.warn(
          '[HotUpdateUpload] Failed to compute file hash. Reporting skipped:',
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
          throw new Error(data.message || t('hotUpdate.upload.error'));
        }

        if (!data.session_id) {
          formState.file_size = file.size;
          Message.success(data.message || t('hotUpdate.upload.dedup'));
          formState.download_key = data.key;
        } else {
          if (!data.part_size || !data.total_parts) {
            throw new Error(t('hotUpdate.upload.error'));
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
          Message.success(t('hotUpdate.upload.multipartSuccess'));
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
          throw new Error(data.message || t('hotUpdate.upload.error'));
        }

        if (data.signature) {
          const response = await uploadWithSignature(file, data.signature);
          if (!response.ok) {
            const text = await response.text();
            throw new Error(text || t('hotUpdate.upload.error'));
          }
          formState.file_size = file.size;
          Message.success(t('hotUpdate.upload.success'));
        } else {
          formState.file_size = file.size;
          Message.success(data.message || t('hotUpdate.upload.dedup'));
        }

        formState.download_key = data.key;
      }
      uploadedFileInfo.value = `${file.name} · ${formatFileSize(file.size)}`;
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('hotUpdate.upload.error'),
        })
      );
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
