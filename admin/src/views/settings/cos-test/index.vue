<template>
  <div class="cos-test-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.cosTest']" />
    <a-card class="general-card" :title="t('cosTest.title')" :bordered="false">
      <a-space direction="vertical" :size="24" style="width: 100%">
        <a-form :model="formData" layout="vertical">
          <a-form-item :label="t('cosTest.provider.label')">
            <a-select
              v-model="formData.provider_id"
              :placeholder="t('cosTest.provider.placeholder')"
              allow-clear
              :loading="providersLoading"
            >
              <a-option
                v-for="provider in providers"
                :key="provider.id"
                :value="provider.id"
                :disabled="!provider.is_active"
              >
                {{ provider.name }}
                <span v-if="provider.is_default" style="color: #1890ff"
                  >({{ t('cosTest.provider.defaultTag') }})</span
                >
                <a-tag
                  v-if="!provider.is_active"
                  size="small"
                  color="gray"
                  style="margin-left: 8px"
                >
                  {{ t('cosTest.provider.disabledTag') }}
                </a-tag>
              </a-option>
            </a-select>
          </a-form-item>
        </a-form>

        <a-card :title="t('cosTest.bucket.section')" size="small">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-button
              type="primary"
              :loading="bucketsLoading"
              @click="handleListBuckets"
            >
              {{ t('cosTest.bucket.load') }}
            </a-button>
            <a-table
              v-if="buckets.length > 0"
              :columns="bucketColumns"
              :data="buckets"
              :pagination="false"
              size="small"
              row-key="name"
            />
            <a-empty
              v-else-if="bucketsLoaded && !bucketsLoading"
              :description="t('cosTest.bucket.empty')"
            />
            <a-result
              v-if="bucketsResult"
              :status="bucketsResult.success ? 'success' : 'error'"
              :title="bucketsResult.message"
            />
          </a-space>
        </a-card>

        <a-card :title="t('cosTest.cors.section')" size="small">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-space wrap>
              <a-button
                type="primary"
                :loading="corsLoading"
                @click="handleLoadCorsRules"
              >
                {{ t('cosTest.cors.load') }}
              </a-button>
              <a-tag v-if="corsLoaded" color="arcoblue">
                {{ t('cosTest.cors.currentCount', { count: corsRules.length }) }}
              </a-tag>
            </a-space>
            <a-table
              v-if="corsRulesTableData.length > 0"
              :columns="corsTableColumns"
              :data="corsRulesTableData"
              :pagination="false"
              size="small"
              row-key="key"
            />
            <a-empty
              v-else-if="corsLoaded && !corsLoading"
              :description="t('cosTest.cors.empty')"
            />
            <a-result
              v-if="corsResult"
              :status="corsResult.success ? 'success' : 'error'"
              :title="corsResult.message"
            />
            <a-divider />
            <a-form :model="corsForm" layout="vertical">
              <a-form-item :label="t('cosTest.cors.form.origin.label')">
                <a-input
                  v-model="corsForm.origin"
                  :placeholder="t('cosTest.cors.form.origin.placeholder')"
                />
              </a-form-item>
              <a-form-item
                :label="t('cosTest.cors.form.methods.label')"
              >
                <a-select
                  v-model="corsForm.methods"
                  mode="multiple"
                  allow-clear
                  :placeholder="t('cosTest.cors.form.methods.placeholder')"
                >
                  <a-option
                    v-for="method in corsMethodOptions"
                    :key="method"
                    :value="method"
                  >
                    {{ method }}
                  </a-option>
                </a-select>
              </a-form-item>
              <a-form-item :label="t('cosTest.cors.form.allowedHeaders.label')">
                <a-input
                  v-model="corsForm.allowedHeaders"
                  :placeholder="t('cosTest.cors.form.allowedHeaders.placeholder')"
                />
              </a-form-item>
              <a-form-item :label="t('cosTest.cors.form.exposeHeaders.label')">
                <a-input
                  v-model="corsForm.exposeHeaders"
                  :placeholder="t('cosTest.cors.form.exposeHeaders.placeholder')"
                />
              </a-form-item>
              <a-form-item :label="t('cosTest.cors.form.maxAge.label')">
                <a-input-number
                  v-model="corsForm.maxAgeSeconds"
                  :min="0"
                  :precision="0"
                  style="width: 100%"
                />
              </a-form-item>
              <a-form-item :label="t('cosTest.cors.form.override.label')">
                <a-switch v-model="corsForm.overrideExisting" />
                <span style="margin-left: 8px">
                  {{ t('cosTest.cors.form.override.note') }}
                </span>
              </a-form-item>
              <a-form-item>
                <a-button
                  type="primary"
                  status="success"
                  :loading="corsSaveLoading"
                  @click="handleAddCorsRule"
                >
                  {{ t('cosTest.cors.save') }}
                </a-button>
              </a-form-item>
            </a-form>
          </a-space>
        </a-card>

        <a-card :title="t('cosTest.upload.section')" size="small">
          <a-form :model="uploadForm" layout="vertical">
            <a-form-item :label="t('cosTest.upload.key.label')">
              <a-input
                v-model="uploadForm.key"
                :placeholder="t('cosTest.upload.key.placeholder')"
              />
            </a-form-item>
            <a-form-item :label="t('cosTest.upload.contentType.label')">
              <a-input
                v-model="uploadForm.content_type"
                :placeholder="t('cosTest.upload.contentType.placeholder')"
              />
            </a-form-item>
            <a-form-item :label="t('cosTest.upload.file.label')">
              <input
                ref="fileInputRef"
                type="file"
                style="display: none"
                @change="handleFileChange"
              />
              <a-space>
                <a-button @click="triggerFileSelect">
                  {{ t('cosTest.upload.file.select') }}
                </a-button>
                <span v-if="selectedFileInfo">{{ selectedFileInfo }}</span>
              </a-space>
            </a-form-item>
            <a-form-item>
              <a-alert
                type="warning"
                show-icon
                style="margin-bottom: 12px"
                :title="t('cosTest.upload.alert')"
              />
              <a-progress
                v-if="multipartUploadProgress !== null"
                :percent="multipartUploadPercent"
                size="small"
                :show-text="true"
                style="margin-bottom: 12px"
              />
              <a-button
                type="primary"
                status="success"
                :loading="uploadLoading"
                :disabled="!selectedFile"
                @click="handleUploadFile"
              >
                {{ t('cosTest.upload.submit') }}
              </a-button>
            </a-form-item>
          </a-form>
          <a-result
            v-if="uploadResult"
            :status="uploadResult.success ? 'success' : 'error'"
            :title="uploadResult.message"
          >
            <template v-if="uploadResult.success && uploadResult.url" #subtitle>
              <a :href="uploadResult.url" target="_blank">
                {{ uploadResult.url }}
              </a>
            </template>
          </a-result>
        </a-card>

        <a-card :title="t('cosTest.download.section')" size="small">
          <a-form :model="downloadForm" layout="vertical">
            <a-form-item :label="t('cosTest.download.key.label')">
              <a-input
                v-model="downloadForm.key"
                :placeholder="t('cosTest.download.key.placeholder')"
              />
            </a-form-item>
            <a-form-item :label="t('cosTest.download.expires.label')">
              <a-input-number
                v-model="downloadForm.expires_in_seconds"
                :min="60"
                :max="86400"
                :precision="0"
                style="width: 100%"
              />
            </a-form-item>
            <a-form-item>
              <a-space wrap>
                <a-button
                  type="primary"
                  :loading="downloadLoading"
                  @click="handleGenerateDownloadUrl"
                >
                  {{ t('cosTest.download.generate') }}
                </a-button>
                <a-button v-if="lastUploadedKey" @click="fillLastUploadedKey">
                  {{ t('cosTest.download.useLastKey') }}
                </a-button>
              </a-space>
            </a-form-item>
          </a-form>
          <a-result
            v-if="downloadResult"
            :status="downloadResult.success ? 'success' : 'error'"
            :title="downloadResult.message"
          >
            <template
              v-if="downloadResult.success && downloadResult.url"
              #subtitle
            >
              <a :href="downloadResult.url" target="_blank">
                {{ downloadResult.url }}
              </a>
            </template>
          </a-result>
        </a-card>
      </a-space>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, onMounted, computed } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import { useI18n } from 'vue-i18n';
  import {
    listStorageProviders,
    testCosListBuckets,
    testCosUploadSignature,
    testCosMultipartUploadInitiate,
    testCosDownloadUrl,
    getCosCors,
    setCosCors,
    type StorageProvider,
    type DirectUploadSignature,
    type SetCosCorsRulePayload,
  } from '@/api/settings';
  import { computeFileHash } from '@/utils/fileHash';
  import { uploadFileByMultipartAndComplete } from '@/utils/multipart-upload';

  const { t } = useI18n();

  type UploadTestResult = {
    success: boolean;
    message: string;
    url?: string;
  };

  type DownloadUrlResult = {
    success: boolean;
    message: string;
    url?: string;
  };

  type SimpleResult = {
    success: boolean;
    message: string;
  };

  const providers = ref<StorageProvider[]>([]);
  const providersLoading = ref(false);

  const formData = reactive({
    provider_id: undefined as string | undefined,
  });

  const buckets = ref<
    Array<{
      name: string;
      region: string;
      creation_date?: string | null;
    }>
  >([]);
  const bucketsLoading = ref(false);
  const bucketsLoaded = ref(false);
  const bucketsResult = ref<SimpleResult | null>(null);

  const bucketColumns = computed(() => [
    {
      title: t('cosTest.bucket.table.name'),
      dataIndex: 'name',
    },
    {
      title: t('cosTest.bucket.table.region'),
      dataIndex: 'region',
    },
    {
      title: t('cosTest.bucket.table.createdAt'),
      dataIndex: 'creation_date',
    },
  ]);

  const uploadForm = reactive({
    key: `test/${Date.now()}.txt`,
    content_type: '',
  });

  const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024;

  const uploadLoading = ref(false);
  const uploadResult = ref<UploadTestResult | null>(null);
  const lastUploadedKey = ref('');
  const multipartUploadProgress = ref<number | null>(null);
  const multipartUploadPercent = computed(() => {
    if (multipartUploadProgress.value === null) return 0;
    return Math.min(
      100,
      Math.max(0, Math.round(multipartUploadProgress.value * 100))
    );
  });

  const fileInputRef = ref<HTMLInputElement | null>(null);
  const selectedFile = ref<File | null>(null);
  const selectedFileInfo = computed(() => {
    if (!selectedFile.value) {
      return '';
    }
    const sizeKB = selectedFile.value.size / 1024;
    const displaySize =
      sizeKB >= 1024
        ? `${(sizeKB / 1024).toFixed(2)} MB`
        : `${sizeKB.toFixed(2)} KB`;
    return `${selectedFile.value.name} (${displaySize})`;
  });

  const corsRules = ref<SetCosCorsRulePayload[]>([]);
  const corsRulesTableData = computed(() =>
    corsRules.value.map((rule, index) => ({
      key: `${index}`,
      origins: (rule.allowed_origins || []).join(', '),
      methods: (rule.allowed_methods || []).join(', '),
      headers:
        rule.allowed_headers && rule.allowed_headers.length > 0
          ? rule.allowed_headers.join(', ')
          : '*',
      exposeHeaders:
        rule.expose_headers && rule.expose_headers.length > 0
          ? rule.expose_headers.join(', ')
          : '-',
      maxAge:
        typeof rule.max_age_seconds === 'number' ? rule.max_age_seconds : '-',
    }))
  );
  const corsTableColumns = computed(() => [
    { title: t('cosTest.cors.table.origins'), dataIndex: 'origins' },
    { title: t('cosTest.cors.table.methods'), dataIndex: 'methods' },
    { title: t('cosTest.cors.table.headers'), dataIndex: 'headers' },
    {
      title: t('cosTest.cors.table.exposeHeaders'),
      dataIndex: 'exposeHeaders',
    },
    { title: t('cosTest.cors.table.maxAge'), dataIndex: 'maxAge' },
  ]);
  const corsLoaded = ref(false);
  const corsLoading = ref(false);
  const corsSaveLoading = ref(false);
  const corsResult = ref<SimpleResult | null>(null);
  const corsMethodOptions = ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'];
  const corsForm = reactive({
    origin: 'http://localhost:8011',
    methods: ['PUT'] as string[],
    allowedHeaders: '*',
    exposeHeaders: '',
    maxAgeSeconds: 600 as number | null,
    overrideExisting: false,
  });

  const downloadForm = reactive({
    key: '',
    expires_in_seconds: 600,
  });
  const downloadLoading = ref(false);
  const downloadResult = ref<DownloadUrlResult | null>(null);

  const fetchProviders = async () => {
    try {
      providersLoading.value = true;
      const response = await listStorageProviders();
      const data = (response.data as any)?.data || response.data;
      providers.value = data?.providers || [];
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('cosTest.error.fetchProviders');
      Message.error(errorMsg);
    } finally {
      providersLoading.value = false;
    }
  };

  const loadCorsRules = async (silent = false): Promise<boolean> => {
    try {
      corsLoading.value = true;
      const response = await getCosCors({
        provider_id: formData.provider_id,
      });
      const { data } = response;
      if (data.success) {
        corsRules.value = data.rules || [];
        corsLoaded.value = true;
        corsResult.value = {
          success: true,
          message: data.message || t('cosTest.cors.fetchSuccess'),
        };
        if (!silent) {
          Message.success(corsResult.value.message);
        }
        return true;
      }
      corsRules.value = data.rules || [];
      corsResult.value = {
        success: false,
        message: data.message || t('cosTest.cors.fetchError'),
      };
      if (!silent) {
        Message.error(corsResult.value.message);
      }
      return false;
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('cosTest.cors.fetchError');
      corsResult.value = {
        success: false,
        message: errorMsg,
      };
      if (!silent) {
        Message.error(errorMsg);
      }
      return false;
    } finally {
      corsLoading.value = false;
    }
  };

  const handleLoadCorsRules = async () => {
    await loadCorsRules(false);
  };

  const handleListBuckets = async () => {
    try {
      bucketsLoading.value = true;
      bucketsResult.value = null;

      const response = await testCosListBuckets({
        provider_id: formData.provider_id,
      });
      const { data } = response;

      if (data.success) {
        buckets.value = data.buckets || [];
        bucketsLoaded.value = true;
        bucketsResult.value = {
          success: true,
          message: data.message || t('cosTest.bucket.success'),
        };
        Message.success(bucketsResult.value.message);
      } else {
        buckets.value = [];
        bucketsResult.value = {
          success: false,
          message: data.message || t('cosTest.bucket.error'),
        };
        Message.error(bucketsResult.value.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('cosTest.bucket.error');
      buckets.value = [];
      bucketsResult.value = {
        success: false,
        message: errorMsg,
      };
      Message.error(errorMsg);
    } finally {
      bucketsLoading.value = false;
    }
  };

  const computeHashForFile = async (
    file?: File
  ): Promise<{
    hashValue?: string;
    hashAlg?: number;
  }> => {
    if (!file) return {};
    try {
      const hash = await computeFileHash(file);
      if (!hash.hashValue) return {};
      return {
        hashValue: hash.hashValue,
        hashAlg: hash.hashAlg ?? 2,
      };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(t('cosTest.upload.hashWarn'), error);
      return {};
    }
  };

  const requestUploadSignature = async (
    key: string,
    contentType: string | undefined,
    file?: File
  ): Promise<{
    key: string;
    signature: DirectUploadSignature | null;
    message: string;
  }> => {
    const hash = await computeHashForFile(file);
    const { hashValue } = hash;
    const { hashAlg } = hash;

    const response = await testCosUploadSignature({
      provider_id: formData.provider_id,
      key,
      content_type: contentType?.trim() || undefined,
      file_size: file?.size,
      hash_value: hashValue,
      hash_alg: hashAlg,
    });
    const { data } = response;
    if (!data.success) {
      throw new Error(data.message || t('cosTest.upload.signatureError'));
    }
    return {
      key,
      signature: data.signature ?? null,
      message: data.message,
    };
  };

  const performMultipartUpload = async (
    file: File,
    contentType: string | undefined,
    loadingRef: typeof uploadLoading
  ): Promise<boolean> => {
    try {
      loadingRef.value = true;
      uploadResult.value = null;
      multipartUploadProgress.value = 0;

      const key = uploadForm.key.trim();
      const hash = await computeHashForFile(file);

      const { data } = await testCosMultipartUploadInitiate({
        provider_id: formData.provider_id,
        key,
        content_type: contentType?.trim() || undefined,
        file_size: file.size,
        hash_value: hash.hashValue,
        hash_alg: hash.hashAlg,
      });

      if (!data.success) {
        throw new Error(data.message || t('cosTest.upload.multipartInitError'));
      }

      const finalKey = data.key || key;

      if (!data.session_id) {
        multipartUploadProgress.value = null;
        uploadResult.value = {
          success: true,
          message: data.message || t('cosTest.upload.reused'),
          url: undefined,
        };
        lastUploadedKey.value = finalKey;
        Message.success(uploadResult.value.message);
        return true;
      }

      if (!data.part_size || !data.total_parts) {
        throw new Error(t('cosTest.upload.multipartIncomplete'));
      }

      await uploadFileByMultipartAndComplete({
        file,
        sessionId: data.session_id,
        partSize: data.part_size,
        totalParts: data.total_parts,
        onProgress: (uploadedParts, totalParts) => {
          multipartUploadProgress.value =
            totalParts > 0 ? uploadedParts / totalParts : 0;
        },
        autoAbortOnError: true,
      });

      multipartUploadProgress.value = 1;
      uploadResult.value = {
        success: true,
        message: t('cosTest.upload.multipartSuccess'),
        url: undefined,
      };
      lastUploadedKey.value = finalKey;
      Message.success(uploadResult.value.message);
      return true;
    } catch (error: any) {
      const errorMsg = error?.message || t('cosTest.upload.failed');
      uploadResult.value = {
        success: false,
        message: errorMsg,
      };
      Message.error(errorMsg);
      return false;
    } finally {
      loadingRef.value = false;
    }
  };

  const performDirectUpload = async (
    blob: Blob,
    contentType: string | undefined,
    loadingRef: typeof uploadLoading
  ): Promise<boolean> => {
    try {
      loadingRef.value = true;
      uploadResult.value = null;
      multipartUploadProgress.value = null;

      const selected = selectedFile.value ?? null;
      const signatureResult = await requestUploadSignature(
        uploadForm.key.trim(),
        contentType,
        selected || undefined
      );

      if (!signatureResult.signature) {
        uploadResult.value = {
          success: true,
          message: signatureResult.message || t('cosTest.upload.reused'),
          url: undefined,
        };
        lastUploadedKey.value = signatureResult.key;
        Message.success(uploadResult.value.message);
        return true;
      }

      const { signature } = signatureResult;

      const headers = new Headers();
      Object.entries(signature.headers || {}).forEach(
        ([headerKey, headerValue]) => {
          if (headerKey.toLowerCase() === 'host') {
            return;
          }
          headers.set(headerKey, headerValue);
        }
      );

      if (contentType && contentType.trim() && !headers.has('Content-Type')) {
        headers.set('Content-Type', contentType.trim());
      }

      const response = await fetch(signature.url, {
        method: signature.method || 'PUT',
        headers,
        body: blob,
      });

      if (!response.ok) {
        let errorDetails = '';
        try {
          errorDetails = await response.text();
        } catch {
          errorDetails = '';
        }
        throw new Error(
          t('cosTest.upload.cosReturned', {
            status: response.status,
            details: errorDetails ? `: ${errorDetails.slice(0, 200)}` : '',
          })
        );
      }

      uploadResult.value = {
        success: true,
        message: t('cosTest.upload.success'),
        url: signature.url,
      };
      lastUploadedKey.value = uploadForm.key.trim();
      Message.success(t('cosTest.upload.success'));
      return true;
    } catch (error: any) {
      const errorMsg = error?.message || t('cosTest.upload.failed');
      uploadResult.value = {
        success: false,
        message: errorMsg,
      };
      Message.error(errorMsg);
      return false;
    } finally {
      loadingRef.value = false;
    }
  };

  const triggerFileSelect = () => {
    fileInputRef.value?.click();
  };

  const handleFileChange = (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;
    selectedFile.value = files && files.length > 0 ? files[0] : null;

    if (selectedFile.value) {
      if (!uploadForm.key || uploadForm.key.startsWith('test/')) {
        uploadForm.key = `test/${Date.now()}-${selectedFile.value.name}`;
      }
      if (!uploadForm.content_type && selectedFile.value.type) {
        uploadForm.content_type = selectedFile.value.type;
      }
    }
  };

  const resetFileSelection = () => {
    selectedFile.value = null;
    multipartUploadProgress.value = null;
    if (fileInputRef.value) {
      fileInputRef.value.value = '';
    }
  };

  const handleUploadFile = async () => {
    if (!selectedFile.value) {
      Message.error(t('cosTest.upload.selectFileFirst'));
      return;
    }
    if (!uploadForm.key.trim()) {
      Message.error(t('cosTest.upload.keyRequired'));
      return;
    }

    const contentType =
      selectedFile.value.type ||
      uploadForm.content_type?.trim() ||
      'application/octet-stream';

    const shouldUseMultipart =
      selectedFile.value.size > MULTIPART_THRESHOLD_BYTES;
    const success = shouldUseMultipart
      ? await performMultipartUpload(
          selectedFile.value,
          contentType,
          uploadLoading
        )
      : await performDirectUpload(
          selectedFile.value,
          contentType,
          uploadLoading
        );

    if (success) {
      resetFileSelection();
    }
  };

  const fillLastUploadedKey = () => {
    if (lastUploadedKey.value) {
      downloadForm.key = lastUploadedKey.value;
    } else {
      Message.info(t('cosTest.download.noLastKey'));
    }
  };

  const handleGenerateDownloadUrl = async () => {
    if (!downloadForm.key.trim()) {
      Message.error(t('cosTest.download.keyRequired'));
      return;
    }

    const expiresIn = downloadForm.expires_in_seconds || 600;
    if (expiresIn < 60 || expiresIn > 86400) {
      Message.error(t('cosTest.download.expiresRange'));
      return;
    }

    downloadLoading.value = true;
    downloadResult.value = null;
    try {
      const response = await testCosDownloadUrl({
        provider_id: formData.provider_id,
        key: downloadForm.key.trim(),
        expires_in_seconds: expiresIn,
      });
      const { data } = response;
      downloadResult.value = data;
      if (data.success && data.url) {
        Message.success(t('cosTest.download.success'));
      } else {
        Message.error(data.message || t('cosTest.download.error'));
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('cosTest.download.error');
      downloadResult.value = {
        success: false,
        message: errorMsg,
      };
      Message.error(errorMsg);
    } finally {
      downloadLoading.value = false;
    }
  };

  const handleAddCorsRule = async () => {
    const originList = corsForm.origin
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    if (originList.length === 0) {
      Message.error(t('cosTest.validation.originRequired'));
      return;
    }

    const normalizedMethods = corsForm.methods
      .map((method) => method.trim().toUpperCase())
      .filter((method) => method.length > 0);
    const methodList =
      normalizedMethods.length > 0
        ? Array.from(new Set(normalizedMethods))
        : ['PUT', 'OPTIONS'];

    const allowedHeaders = corsForm.allowedHeaders
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    const exposeHeaders = corsForm.exposeHeaders
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    const maxAge =
      typeof corsForm.maxAgeSeconds === 'number'
        ? corsForm.maxAgeSeconds
        : undefined;

    if (typeof maxAge === 'number' && maxAge < 0) {
      Message.error(t('cosTest.validation.maxAge'));
      return;
    }

    if (!corsForm.overrideExisting && !corsLoaded.value) {
      await loadCorsRules(true);
    }

    const baseRules = corsForm.overrideExisting
      ? []
      : corsRules.value.map((rule) => ({
          allowed_origins: [...rule.allowed_origins],
          allowed_methods: [...rule.allowed_methods],
          allowed_headers: rule.allowed_headers
            ? [...rule.allowed_headers]
            : undefined,
          expose_headers: rule.expose_headers
            ? [...rule.expose_headers]
            : undefined,
          max_age_seconds: rule.max_age_seconds,
        }));

    baseRules.push({
      allowed_origins: originList,
      allowed_methods: methodList,
      allowed_headers: allowedHeaders.length > 0 ? allowedHeaders : undefined,
      expose_headers: exposeHeaders.length > 0 ? exposeHeaders : undefined,
      max_age_seconds: maxAge,
    });

    corsSaveLoading.value = true;
    try {
      const response = await setCosCors({
        provider_id: formData.provider_id,
        rules: baseRules,
      });
      const { data } = response;
      if (data.success) {
        Message.success(data.message || t('cosTest.cors.success'));
        const reloaded = await loadCorsRules(true);
        if (!reloaded) {
          Message.warning(t('cosTest.cors.reloadWarning'));
        }
        corsResult.value = {
          success: true,
          message: data.message || t('cosTest.cors.success'),
        };
      } else {
        corsResult.value = {
          success: false,
          message: data.message || t('cosTest.cors.error'),
        };
        Message.error(corsResult.value.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        t('cosTest.cors.error');
      corsResult.value = {
        success: false,
        message: errorMsg,
      };
      Message.error(errorMsg);
    } finally {
      corsSaveLoading.value = false;
    }
  };

  onMounted(() => {
    fetchProviders();
  });
</script>

<style scoped>
  .cos-test-container {
    padding: 0 20px 20px;
  }
</style>
