<template>
  <div class="general-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.general']" />
    <a-card class="general-card" title="通用设置" :bordered="false">
      <a-tabs default-active-key="app-name">
        <a-tab-pane key="app-name" title="应用名称">
          <a-form
            :model="appNameForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleAppNameSubmit"
          >
            <a-form-item
              field="app_name"
              label="应用名称"
              :rules="[
                { required: true, message: '请输入应用名称' },
                { maxLength: 50, message: '应用名称不能超过50个字符' },
              ]"
            >
              <a-input
                v-model="appNameForm.app_name"
                placeholder="请输入应用名称"
                maxlength="50"
                show-word-limit
              />
              <template #help>
                应用名称将在桌面端和移动端应用启动时显示，修改后需要重启应用才能生效。
              </template>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  保存设置
                </a-button>
                <a-button @click="handleAppNameReset"> 重置 </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import { getAppName, updateAppName } from '@/api/settings';

  const { loading, setLoading } = useLoading(false);

  const appNameForm = reactive({
    app_name: '',
  });

  const fetchAppName = async () => {
    try {
      const { data } = await getAppName();
      if (data) {
        appNameForm.app_name = data.app_name || '';
      }
    } catch (error) {
      Message.error('获取应用名称失败');
    }
  };

  const handleAppNameSubmit = async () => {
    if (!appNameForm.app_name.trim()) {
      Message.warning('请输入应用名称');
      return;
    }

    try {
      setLoading(true);
      await updateAppName({
        app_name: appNameForm.app_name.trim(),
      });
      Message.success('应用名称保存成功');
      await fetchAppName();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '保存失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleAppNameReset = () => {
    fetchAppName();
  };

  onMounted(() => {
    fetchAppName();
  });
</script>

<style lang="less" scoped>
  .general-settings-container {
    padding: 0 20px 20px;
  }

  .general-card {
    margin-top: 16px;
  }

  .settings-form {
    max-width: 800px;
    margin-top: 20px;
  }
</style>
