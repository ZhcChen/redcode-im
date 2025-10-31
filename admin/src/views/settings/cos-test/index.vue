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
            <a-form-item>
              <a-button
                type="primary"
                :loading="uploadLoading"
                @click="handleUpload"
              >
                上传文件
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
      </a-space>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import {
    listStorageProviders,
    testCosUpload,
    testCosDelete,
    testCosExists,
    type StorageProvider,
    type TestCosUploadRequest,
    type TestCosUploadResponse,
    type TestCosDeleteRequest,
    type TestCosDeleteResponse,
    type TestCosExistsRequest,
    type TestCosExistsResponse,
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

  const uploadLoading = ref(false);
  const deleteLoading = ref(false);
  const existsLoading = ref(false);

  const uploadResult = ref<TestCosUploadResponse | null>(null);
  const deleteResult = ref<TestCosDeleteResponse | null>(null);
  const existsResult = ref<TestCosExistsResponse | null>(null);

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

  const handleUpload = async () => {
    if (!uploadForm.key.trim()) {
      Message.error('请输入文件路径');
      return;
    }
    if (!uploadForm.content.trim()) {
      Message.error('请输入文件内容');
      return;
    }

    try {
      uploadLoading.value = true;
      uploadResult.value = null;

      const payload: TestCosUploadRequest = {
        provider_id: formData.provider_id,
        key: uploadForm.key.trim(),
        content: uploadForm.content,
        content_type: uploadForm.content_type || undefined,
      };

      const response = await testCosUpload(payload);
      const data = response.data?.data || response.data;
      uploadResult.value = data;

      if (data.success) {
        Message.success('上传成功');
      } else {
        Message.error(data.message);
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '上传失败';
      Message.error(errorMsg);
      uploadResult.value = {
        success: false,
        message: errorMsg,
      };
    } finally {
      uploadLoading.value = false;
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
