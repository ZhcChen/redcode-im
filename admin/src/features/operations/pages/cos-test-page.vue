<template>
  <div class="cos-test-container">
    <Breadcrumb :items="['menu.operations', 'menu.operations.cosTest']" />
    <a-card class="general-card" title="腾讯云 COS 测试" :bordered="false">
      <a-space direction="vertical" :size="24" style="width: 100%">
        <!-- 提供商选择 -->
        <a-form :model="formData" layout="vertical">
          <a-form-item label="选择提供商">
            <a-select
              v-model="formData.provider_id"
              placeholder="选择要测试的提供商（留空使用默认提供商）"
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
                  >(默认)</span
                >
                <a-tag
                  v-if="!provider.is_active"
                  size="small"
                  color="gray"
                  style="margin-left: 8px"
                >
                  已禁用
                </a-tag>
              </a-option>
            </a-select>
          </a-form-item>
        </a-form>

        <!-- 测试一：Bucket 列表 -->
        <a-card title="测试一：Bucket 列表" size="small">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-button
              type="primary"
              :loading="bucketsLoading"
              @click="handleListBuckets"
            >
              加载 Bucket 列表
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
              description="暂无 Bucket"
            />
            <a-result
              v-if="bucketsResult"
              :status="bucketsResult.success ? 'success' : 'error'"
              :title="bucketsResult.message"
            />
          </a-space>
        </a-card>

        <!-- 测试二：跨域规则配置 -->
        <a-card title="测试二：跨域规则配置" size="small">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-space wrap>
              <a-button
                type="primary"
                :loading="corsLoading"
                @click="handleLoadCorsRules"
              >
                加载跨域规则
              </a-button>
              <a-tag v-if="corsLoaded" color="arcoblue">
                当前 {{ corsRules.length }} 条
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
              description="暂无跨域规则"
            />
            <a-result
              v-if="corsResult"
              :status="corsResult.success ? 'success' : 'error'"
              :title="corsResult.message"
            />
            <a-divider />
            <a-form :model="corsForm" layout="vertical">
              <a-form-item label="允许的来源（Origin）">
                <a-input
                  v-model="corsForm.origin"
                  placeholder="例如：http://localhost:8011, https://admin.example.com"
                />
              </a-form-item>
              <a-form-item
                label="允许的方法（COS 仅支持 GET/PUT/POST/DELETE/HEAD）"
              >
                <a-select
                  v-model="corsForm.methods"
                  mode="multiple"
                  allow-clear
                  placeholder="选择允许的方法"
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
              <a-form-item label="允许的 Header（逗号分隔，留空默认 *）">
                <a-input
                  v-model="corsForm.allowedHeaders"
                  placeholder="例如：Content-Type,x-cos-acl"
                />
              </a-form-item>
              <a-form-item label="暴露的 Header（逗号分隔，可留空）">
                <a-input
                  v-model="corsForm.exposeHeaders"
                  placeholder="例如：ETag"
                />
              </a-form-item>
              <a-form-item label="缓存时间（秒，可留空）">
                <a-input-number
                  v-model="corsForm.maxAgeSeconds"
                  :min="0"
                  :precision="0"
                  style="width: 100%"
                />
              </a-form-item>
              <a-form-item label="覆盖已存在的规则">
                <a-switch v-model="corsForm.overrideExisting" />
                <span style="margin-left: 8px">开启后仅保留本次配置</span>
              </a-form-item>
              <a-form-item>
                <a-button
                  type="primary"
                  status="success"
                  :loading="corsSaveLoading"
                  @click="handleAddCorsRule"
                >
                  保存跨域规则
                </a-button>
              </a-form-item>
            </a-form>
          </a-space>
        </a-card>

        <!-- 测试三：本地文件直传 -->
        <a-card title="测试三：本地文件直传" size="small">
          <a-form :model="uploadForm" layout="vertical">
            <a-form-item label="文件路径（Key）">
              <a-input
                v-model="uploadForm.key"
                placeholder="例如：test/hello.txt"
              />
            </a-form-item>
            <a-form-item label="Content-Type（可选）">
              <a-input
                v-model="uploadForm.content_type"
                placeholder="例如：image/png"
              />
            </a-form-item>
            <a-form-item label="选择本地文件">
              <input
                ref="fileInputRef"
                type="file"
                style="display: none"
                @change="handleFileChange"
              />
              <a-space>
                <a-button @click="triggerFileSelect">选择文件</a-button>
                <span v-if="selectedFileInfo">{{ selectedFileInfo }}</span>
              </a-space>
            </a-form-item>
            <a-form-item>
              <a-alert
                type="warning"
                show-icon
                style="margin-bottom: 12px"
                title="大于 5MB 会自动使用分片直传；请确保 COS 跨域规则的 ExposeHeaders 包含 ETag"
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
                上传所选文件
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

        <!-- 测试四：下载链接生成 -->
        <a-card title="测试四：生成下载链接" size="small">
          <a-form :model="downloadForm" layout="vertical">
            <a-form-item label="文件路径（Key）">
              <a-input
                v-model="downloadForm.key"
                placeholder="使用上传后的 key，例如：test/xxx.png"
              />
            </a-form-item>
            <a-form-item label="过期时间（秒，默认 600，最大 86400）">
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
                  生成下载链接
                </a-button>
                <a-button v-if="lastUploadedKey" @click="fillLastUploadedKey">
                  使用最近上传的 key
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

  const bucketColumns = [
    {
      title: 'Bucket 名称',
      dataIndex: 'name',
    },
    {
      title: '地域',
      dataIndex: 'region',
    },
    {
      title: '创建时间',
      dataIndex: 'creation_date',
    },
  ];

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
  const corsTableColumns = [
    { title: '允许来源', dataIndex: 'origins' },
    { title: '允许方法', dataIndex: 'methods' },
    { title: '允许 Header', dataIndex: 'headers' },
    { title: '暴露 Header', dataIndex: 'exposeHeaders' },
    { title: '缓存时间 (秒)', dataIndex: 'maxAge' },
  ];
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
        '获取提供商列表失败';
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
          message: data.message || '获取跨域规则成功',
        };
        if (!silent) {
          Message.success(corsResult.value.message);
        }
        return true;
      }
      corsRules.value = data.rules || [];
      corsResult.value = {
        success: false,
        message: data.message || '获取跨域规则失败',
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
        '获取跨域规则失败';
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
          message: data.message || '获取 bucket 列表成功',
        };
        Message.success(bucketsResult.value.message);
      } else {
        buckets.value = [];
        bucketsResult.value = {
          success: false,
          message: data.message || '获取 bucket 列表失败',
        };
        Message.error(bucketsResult.value.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '获取 bucket 列表失败';
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
      console.warn('[COS Test] 计算文件哈希失败，将跳过哈希上报', error);
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
      throw new Error(data.message || '生成直传签名失败');
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
        throw new Error(data.message || '初始化分片上传失败');
      }

      const finalKey = data.key || key;

      // 命中哈希去重：无需上传
      if (!data.session_id) {
        multipartUploadProgress.value = null;
        uploadResult.value = {
          success: true,
          message: data.message || '复用已上传的对象，无需重新上传',
          url: undefined,
        };
        lastUploadedKey.value = finalKey;
        Message.success(uploadResult.value.message);
        return true;
      }

      if (!data.part_size || !data.total_parts) {
        throw new Error(
          '分片上传初始化结果不完整（缺少 part_size/total_parts）'
        );
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
        message: '上传成功（分片直传）',
        url: undefined,
      };
      lastUploadedKey.value = finalKey;
      Message.success(uploadResult.value.message);
      return true;
    } catch (error: any) {
      const errorMsg = error?.message || '上传失败';
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

      // 命中哈希去重：无需上传
      if (!signatureResult.signature) {
        uploadResult.value = {
          success: true,
          message: signatureResult.message || '复用已上传的对象，无需重新上传',
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
          `COS 返回 ${response.status}${
            errorDetails ? `: ${errorDetails.slice(0, 200)}` : ''
          }`
        );
      }

      uploadResult.value = {
        success: true,
        message: '上传成功',
        url: signature.url,
      };
      lastUploadedKey.value = uploadForm.key.trim();
      Message.success('上传成功');
      return true;
    } catch (error: any) {
      const errorMsg = error?.message || '上传失败';
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
      Message.error('请先选择文件');
      return;
    }
    if (!uploadForm.key.trim()) {
      Message.error('请输入文件路径');
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
      Message.info('暂无最近上传的 key');
    }
  };

  const handleGenerateDownloadUrl = async () => {
    if (!downloadForm.key.trim()) {
      Message.error('请先填写文件路径');
      return;
    }

    const expiresIn = downloadForm.expires_in_seconds || 600;
    if (expiresIn < 60 || expiresIn > 86400) {
      Message.error('过期时间需在 60-86400 秒之间');
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
        Message.success('生成下载链接成功');
      } else {
        Message.error(data.message || '生成下载链接失败');
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '生成下载链接失败';
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
      Message.error('请至少提供一个允许的来源');
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
      Message.error('缓存时间必须大于或等于 0');
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
        Message.success(data.message || '跨域规则配置成功');
        const reloaded = await loadCorsRules(true);
        if (!reloaded) {
          Message.warning('跨域规则已更新，但刷新列表失败，请手动重新加载');
        }
        corsResult.value = {
          success: true,
          message: data.message || '跨域规则配置成功',
        };
      } else {
        corsResult.value = {
          success: false,
          message: data.message || '配置跨域规则失败',
        };
        Message.error(corsResult.value.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '配置跨域规则失败';
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
