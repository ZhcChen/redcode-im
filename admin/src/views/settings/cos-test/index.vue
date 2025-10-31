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

        <!-- 文件上传测试 -->
        <a-card title="文件上传测试" size="small">
          <a-form :model="uploadForm" layout="vertical">
            <a-form-item label="文件路径（Key）">
              <a-input
                v-model="uploadForm.key"
                placeholder="例如：test/hello.txt"
                :default-value="`test/${Date.now()}.txt`"
              />
            </a-form-item>
            <a-form-item label="文件内容">
              <a-textarea
                v-model="uploadForm.content"
                placeholder="请输入要上传的文件内容"
                :rows="5"
                :default-value="`测试文件内容 - ${new Date().toLocaleString()}`"
              />
            </a-form-item>
            <a-form-item label="Content-Type（可选）">
              <a-input
                v-model="uploadForm.content_type"
                placeholder="例如：text/plain, image/png"
              />
            </a-form-item>
            <a-form-item label="选择本地文件（可选）">
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
              <a-space wrap>
                <a-button
                  type="primary"
                  :loading="uploadLoading"
                  @click="handleUpload"
                >
                  上传文本内容
                </a-button>
                <a-button
                  type="primary"
                  status="success"
                  :loading="uploadFileLoading"
                  :disabled="!selectedFile"
                  @click="handleUploadSelectedFile"
                >
                  上传所选文件
                </a-button>
              </a-space>
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

        <!-- 文件删除测试 -->
        <a-card title="文件删除测试" size="small">
          <a-form :model="deleteForm" layout="vertical">
            <a-form-item label="文件路径（Key）">
              <a-input
                v-model="deleteForm.key"
                placeholder="请输入要删除的文件路径"
              />
            </a-form-item>
            <a-form-item>
              <a-button
                type="primary"
                status="danger"
                :loading="deleteLoading"
                @click="handleDelete"
              >
                删除文件
              </a-button>
            </a-form-item>
          </a-form>
          <a-result
            v-if="deleteResult"
            :status="deleteResult.success ? 'success' : 'error'"
            :title="deleteResult.message"
          />
        </a-card>

        <!-- 文件存在性检查测试 -->
        <a-card title="文件存在性检查测试" size="small">
          <a-form :model="existsForm" layout="vertical">
            <a-form-item label="文件路径（Key）">
              <a-input
                v-model="existsForm.key"
                placeholder="请输入要检查的文件路径"
              />
            </a-form-item>
            <a-form-item>
              <a-button
                type="primary"
                :loading="existsLoading"
                @click="handleExists"
              >
                检查文件是否存在
              </a-button>
            </a-form-item>
          </a-form>
          <a-result
            v-if="existsResult"
            :status="existsResult.success ? 'success' : 'error'"
            :title="existsResult.message"
          >
            <template #subtitle>
              <a-tag :color="existsResult.exists ? 'green' : 'gray'">
                {{ existsResult.exists ? '文件存在' : '文件不存在' }}
              </a-tag>
            </template>
          </a-result>
        </a-card>

        <!-- Bucket 列表 -->
        <a-card title="Bucket 列表" size="small">
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
            />
            <a-empty v-else-if="bucketsLoaded" description="暂无 Bucket" />
            <a-result
              v-if="bucketsResult"
              :status="bucketsResult.success ? 'success' : 'error'"
              :title="bucketsResult.message"
            />
          </a-space>
        </a-card>

        <!-- 创建 Bucket -->
        <a-card title="创建 Bucket" size="small">
          <a-form :model="createBucketForm" layout="vertical">
            <a-form-item label="Bucket 名称">
              <a-input
                v-model="createBucketForm.bucket_name"
                placeholder="请输入 bucket 名称（只能包含小写字母、数字和连字符）"
              />
            </a-form-item>
            <a-form-item>
              <a-button
                type="primary"
                :loading="createBucketLoading"
                @click="handleCreateBucket"
              >
                创建 Bucket
              </a-button>
            </a-form-item>
          </a-form>
          <a-result
            v-if="createBucketResult"
            :status="createBucketResult.success ? 'success' : 'error'"
            :title="createBucketResult.message"
          />
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
    testCosDelete,
    testCosExists,
    testCosListBuckets,
    testCosCreateBucket,
    testCosUploadSignature,
    type StorageProvider,
    type TestCosDeleteRequest,
    type TestCosDeleteResponse,
    type TestCosExistsRequest,
    type TestCosExistsResponse,
    type TestCosListBucketsRequest,
    type TestCosListBucketsResponse,
    type TestCosCreateBucketRequest,
    type TestCosCreateBucketResponse,
    type TestCosUploadSignatureRequest,
    type TestCosUploadSignatureResponse,
    type DirectUploadSignature,
  } from '@/api/settings';

  const providers = ref<StorageProvider[]>([]);
  const providersLoading = ref(false);

  const formData = reactive({
    provider_id: undefined as string | undefined,
  });

  const uploadForm = reactive({
    key: `test/${Date.now()}.txt`,
    content: `测试文件内容 - ${new Date().toLocaleString()}`,
    content_type: 'text/plain',
  });

  const deleteForm = reactive({
    key: '',
  });

  const existsForm = reactive({
    key: '',
  });

  const createBucketForm = reactive({
    bucket_name: '',
  });

  type UploadTestResult = {
    success: boolean;
    message: string;
    url?: string;
  };

  const uploadLoading = ref(false);
  const uploadFileLoading = ref(false);
  const deleteLoading = ref(false);
  const existsLoading = ref(false);
  const bucketsLoading = ref(false);
  const createBucketLoading = ref(false);

  const uploadResult = ref<UploadTestResult | null>(null);
  const deleteResult = ref<TestCosDeleteResponse | null>(null);
  const existsResult = ref<TestCosExistsResponse | null>(null);
  const bucketsResult = ref<TestCosListBucketsResponse | null>(null);
  const createBucketResult = ref<TestCosCreateBucketResponse | null>(null);

  const buckets = ref<
    Array<{
      name: string;
      region: string;
      creation_date?: string | null;
    }>
  >([]);
  const bucketsLoaded = ref(false);

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

  const handleUpload = async () => {
    if (!uploadForm.key.trim()) {
      Message.error('请输入文件路径');
      return;
    }
    if (!uploadForm.content.trim()) {
      Message.error('请输入文件内容');
      return;
    }

    const contentType =
      uploadForm.content_type?.trim() || 'text/plain; charset=utf-8';
    const blob = new Blob([uploadForm.content], { type: contentType });
    await performDirectUpload(blob, contentType, uploadLoading);
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

  const handleUploadSelectedFile = async () => {
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
      uploadFileLoading
    );

    if (success) {
      resetFileSelection();
    }
  };

  const handleDelete = async () => {
    if (!deleteForm.key.trim()) {
      Message.error('请输入文件路径');
      return;
    }

    try {
      deleteLoading.value = true;
      deleteResult.value = null;

      const payload: TestCosDeleteRequest = {
        provider_id: formData.provider_id,
        key: deleteForm.key.trim(),
      };

      const response = await testCosDelete(payload);
      const data = response.data?.data || response.data;
      deleteResult.value = data;

      if (data.success) {
        Message.success('删除成功');
      } else {
        Message.error(data.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '删除失败';
      Message.error(errorMsg);
      deleteResult.value = {
        success: false,
        message: errorMsg,
      };
    } finally {
      deleteLoading.value = false;
    }
  };

  const handleExists = async () => {
    if (!existsForm.key.trim()) {
      Message.error('请输入文件路径');
      return;
    }

    try {
      existsLoading.value = true;
      existsResult.value = null;

      const payload: TestCosExistsRequest = {
        provider_id: formData.provider_id,
        key: existsForm.key.trim(),
      };

      const response = await testCosExists(payload);
      const data = response.data?.data || response.data;
      existsResult.value = data;

      if (data.success) {
        Message.success(data.exists ? '文件存在' : '文件不存在');
      } else {
        Message.error(data.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '检查失败';
      Message.error(errorMsg);
      existsResult.value = {
        success: false,
        exists: false,
        message: errorMsg,
      };
    } finally {
      existsLoading.value = false;
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
      const data = response.data?.data || response.data;
      bucketsResult.value = data;

      if (data.success) {
        buckets.value = data.buckets;
        bucketsLoaded.value = true;
        Message.success(data.message);
      } else {
        Message.error(data.message);
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
        buckets: [],
        message: errorMsg,
      };
    } finally {
      bucketsLoading.value = false;
    }
  };

  const handleCreateBucket = async () => {
    if (!createBucketForm.bucket_name.trim()) {
      Message.error('请输入 bucket 名称');
      return;
    }

    try {
      createBucketLoading.value = true;
      createBucketResult.value = null;

      const payload: TestCosCreateBucketRequest = {
        provider_id: formData.provider_id,
        bucket_name: createBucketForm.bucket_name.trim(),
      };

      const response = await testCosCreateBucket(payload);
      const data = response.data?.data || response.data;
      createBucketResult.value = data;

      if (data.success) {
        Message.success(data.message);
        // 创建成功后刷新 bucket 列表
        await handleListBuckets();
        // 清空表单
        createBucketForm.bucket_name = '';
      } else {
        Message.error(data.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '创建 bucket 失败';
      Message.error(errorMsg);
      createBucketResult.value = {
        success: false,
        message: errorMsg,
      };
    } finally {
      createBucketLoading.value = false;
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
