<template>
  <div class="cos-test-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.cosTest']" />
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
                <span v-if="provider.is_default" style="color: #1890ff">
                  (默认)</span
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
        <a-card title="Bucket 列表测试" size="small">
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
            <a-empty v-else-if="bucketsLoaded" description="暂无 Bucket" />
            <a-result
              v-if="bucketsResult"
              :status="bucketsResult.success ? 'success' : 'error'"
              :title="bucketsResult.message"
            />
          </a-space>
        </a-card>

        <!-- 测试二：本地文件直传 -->
        <a-card title="本地文件直传测试" size="small">
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
              <a :href="uploadResult.url" target="_blank">{{
                uploadResult.url
              }}</a>
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
    type StorageProvider,
    type TestCosListBucketsRequest,
    type TestCosListBucketsResponse,
    type TestCosUploadSignatureRequest,
    type TestCosUploadSignatureResponse,
    type DirectUploadSignature,
  } from '@/api/settings';

  type UploadTestResult = {
    success: boolean;
    message: string;
    url?: string;
  };

  const providers = ref<StorageProvider[]>([]);
  const providersLoading = ref(false);
  const buckets = ref<
    Array<{
      name: string;
      region: string;
      creation_date?: string | null;
    }>
  >([]);
  const bucketsLoaded = ref(false);
  const bucketsLoading = ref(false);
  const bucketsResult = ref<{
    success: boolean;
    message?: string;
  } | null>(null);

  const uploadForm = reactive({
    key: `test/${Date.now()}.txt`,
    content_type: '',
  });

  const uploadLoading = ref(false);
  const uploadResult = ref<UploadTestResult | null>(null);

  const fileInputRef = ref<HTMLInputElement | null>(null);
  const selectedFile = ref<File | null>(null);

  const formData = reactive({
    provider_id: undefined as string | undefined,
  });

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

  const fetchProviders = async () => {
    try {
      providersLoading.value = true;
      const response = await listStorageProviders();
      const data = response.data?.data || response.data;
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

  const handleListBuckets = async () => {
    try {
      bucketsLoading.value = true;
      bucketsResult.value = null;

      const payload: TestCosListBucketsRequest = {
        provider_id: formData.provider_id,
      };

      const response = await testCosListBuckets(payload);
      const data =
        (
          response.data as TestCosListBucketsResponse & {
            data?: TestCosListBucketsResponse;
          }
        ).data || response.data;

      if (data?.success) {
        buckets.value = data?.buckets || [];
        bucketsLoaded.value = true;
        bucketsResult.value = {
          success: true,
          message: data?.message || '获取 bucket 列表成功',
        };
        Message.success('获取 bucket 列表成功');
      } else {
        Message.error(data?.message || '获取 bucket 列表失败');
        bucketsResult.value = {
          success: false,
          message: data?.message || '获取 bucket 列表失败',
        };
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '获取 bucket 列表失败';
      Message.error(errorMsg);
      bucketsResult.value = {
        success: false,
        message: errorMsg,
      };
    } finally {
      bucketsLoading.value = false;
    }
  };

  const requestUploadSignature = async (
    key: string,
    contentType?: string
  ): Promise<DirectUploadSignature> => {
    const payload: TestCosUploadSignatureRequest = {
      provider_id: formData.provider_id,
      key,
      content_type: contentType?.trim() || undefined,
    };
    const response = await testCosUploadSignature(payload);
    const data =
      (
        response.data as TestCosUploadSignatureResponse & {
          data?: TestCosUploadSignatureResponse;
        }
      ).data || response.data;

    if (!data.success || !data.signature) {
      throw new Error(data.message || '生成直传签名失败');
    }

    return data.signature;
  };

  const performDirectUpload = async (
    blob: Blob,
    contentType: string | undefined,
    loadingRef: typeof uploadLoading
  ): Promise<boolean> => {
    try {
      loadingRef.value = true;
      uploadResult.value = null;

      const signature = await requestUploadSignature(
        uploadForm.key.trim(),
        contentType
      );

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
      Message.success('上传成功');
      return true;
    } catch (error: any) {
      const errorMsg = error?.message || '上传失败';
      Message.error(errorMsg);
      uploadResult.value = {
        success: false,
        message: errorMsg,
      };
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

    const success = await performDirectUpload(
      selectedFile.value,
      contentType,
      uploadLoading
    );

    if (success) {
      resetFileSelection();
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

  .cos-test-container .general-card {
    margin-top: 16px;
  }
</style>
