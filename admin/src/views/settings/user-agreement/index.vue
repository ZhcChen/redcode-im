<template>
  <div class="user-agreement-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.userAgreement']" />
    <a-card class="general-card" title="用户协议" :bordered="false">
      <a-spin :loading="loading" tip="加载中...">
        <div v-if="!loading" class="policy-editor">
          <a-form layout="vertical">
            <a-form-item label="标题">
              <a-input
                v-model="form.title"
                placeholder="请输入文档标题"
                allow-clear
              />
            </a-form-item>
            <a-form-item label="正文内容">
              <RichTextEditor v-model="form.content" />
            </a-form-item>
          </a-form>
          <div class="policy-editor__footer">
            <div class="policy-editor__meta">
              <span>最后更新：</span>
              <strong>{{ formatTime(documentMeta?.updated_at) }}</strong>
            </div>
            <a-space>
              <a-button :disabled="saving" @click="handleReset">重置</a-button>
              <a-button type="primary" :loading="saving" @click="handleSave">
                保存
              </a-button>
            </a-space>
          </div>
        </div>
      </a-spin>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, onMounted } from 'vue';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import RichTextEditor from '@/components/rich-text-editor/index.vue';
  import {
    getUserAgreement,
    updateUserAgreement,
    type DocumentContent,
  } from '@/api/settings';

  const form = reactive({
    title: '',
    content: '',
  });

  const documentMeta = ref<DocumentContent | null>(null);
  const { loading, setLoading } = useLoading(true);
  const saving = ref(false);

  const fetchData = async () => {
    setLoading(true);
    try {
      const { data } = await getUserAgreement();
      documentMeta.value = data;
      form.title = data.title ?? '';
      form.content = data.content ?? '';
    } catch (error) {
      Message.error('加载用户协议失败，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    if (!documentMeta.value) return;
    form.title = documentMeta.value.title ?? '';
    form.content = documentMeta.value.content ?? '';
  };

  const handleSave = async () => {
    if (!form.content || form.content.trim() === '') {
      Message.warning('请填写用户协议正文内容');
      return;
    }

    saving.value = true;
    try {
      const { data } = await updateUserAgreement({
        title: form.title,
        content: form.content,
      });
      documentMeta.value = data;
      Message.success('保存成功');
    } catch (error) {
      Message.error('保存失败，请稍后重试');
    } finally {
      saving.value = false;
    }
  };

  const formatTime = (value?: string) => {
    if (!value) return '暂无';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .user-agreement-container {
    padding: 0 20px 20px;

    .general-card {
      .policy-editor {
        display: flex;
        flex-direction: column;
        gap: 16px;

        &__footer {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-top: 16px;
        }

        &__meta {
          color: var(--color-text-3, #4e5969);
          font-size: 13px;

          strong {
            margin-left: 4px;
            color: var(--color-text-1, #1d2129);
            font-weight: 600;
          }
        }
      }
    }
  }
</style>
