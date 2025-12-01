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

        <a-tab-pane key="ip-geolocation" title="IP地理位置解析">
          <a-form
            :model="ipGeoForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleIpGeoSubmit"
          >
            <a-form-item field="enabled" label="功能开关">
              <a-switch v-model="ipGeoForm.enabled" />
              <template #help>
                控制是否启用用户IP地址地理位置解析功能，用于管理员数据统计。关闭后不会记录用户的地理位置信息。
              </template>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  保存设置
                </a-button>
                <a-button @click="handleIpGeoReset"> 重置 </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="user-account-limit" title="用户账号限制">
          <a-form
            :model="accountLimitForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleAccountLimitSubmit"
          >
            <a-form-item field="enable_phone_validation" label="启用手机号校验">
              <a-switch v-model="accountLimitForm.enable_phone_validation" />
              <template #help>
                启用后，注册用户账号（用户名）必须符合手机号格式
              </template>
            </a-form-item>

            <a-form-item field="enable_email_validation" label="启用邮箱校验">
              <a-switch v-model="accountLimitForm.enable_email_validation" />
              <template #help>
                启用后，注册用户账号（用户名）必须符合邮箱格式
              </template>
            </a-form-item>

            <a-form-item field="enable_length_validation" label="启用长度校验">
              <a-switch v-model="accountLimitForm.enable_length_validation" />
              <template #help>
                启用后，注册用户账号（用户名）必须符合长度限制
              </template>
            </a-form-item>

            <a-form-item
              v-if="accountLimitForm.enable_length_validation"
              field="min_length"
              label="最小长度"
              :rules="[
                { required: true, message: '请输入最小长度' },
                { type: 'number', min: 3, max: 50, message: '长度范围：3-50' },
              ]"
            >
              <a-input-number
                v-model="accountLimitForm.min_length"
                :min="3"
                :max="50"
                placeholder="最小长度"
                style="width: 200px"
              />
            </a-form-item>

            <a-form-item
              v-if="accountLimitForm.enable_length_validation"
              field="max_length"
              label="最大长度"
              :rules="[
                { required: true, message: '请输入最大长度' },
                { type: 'number', min: 3, max: 50, message: '长度范围：3-50' },
              ]"
            >
              <a-input-number
                v-model="accountLimitForm.max_length"
                :min="3"
                :max="50"
                placeholder="最大长度"
                style="width: 200px"
              />
            </a-form-item>

            <a-form-item
              field="enable_alphanumeric_validation"
              label="启用字母数字混合校验"
            >
              <a-switch
                v-model="accountLimitForm.enable_alphanumeric_validation"
              />
              <template #help>
                启用后，注册用户账号（用户名）必须同时包含字母和数字
              </template>
            </a-form-item>

            <a-alert
              v-if="!isAnyValidationEnabled"
              type="warning"
              closable="false"
              style="margin-bottom: 20px"
            >
              至少需要启用一种校验规则
            </a-alert>

            <a-form-item>
              <a-space>
                <a-button
                  type="primary"
                  html-type="submit"
                  :loading="loading"
                  :disabled="!isAnyValidationEnabled"
                >
                  保存设置
                </a-button>
                <a-button @click="handleAccountLimitReset"> 重置 </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="api-test" title="API测试">
          <ApiTest />
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted, computed } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import {
    getAppName,
    updateAppName,
    getIpGeolocationEnabled,
    setIpGeolocationEnabled,
    getUserAccountLimit,
    updateUserAccountLimit,
  } from '@/api/settings';
  import ApiTest from '../api-test/index.vue';

  const { loading, setLoading } = useLoading(false);

  const appNameForm = reactive({
    app_name: '',
  });

  const ipGeoForm = reactive({
    enabled: false,
  });

  const accountLimitForm = reactive({
    enable_phone_validation: false,
    enable_email_validation: false,
    enable_length_validation: false,
    min_length: 3,
    max_length: 20,
    enable_alphanumeric_validation: false,
  });

  const isAnyValidationEnabled = computed(() => {
    return (
      accountLimitForm.enable_phone_validation ||
      accountLimitForm.enable_email_validation ||
      accountLimitForm.enable_length_validation ||
      accountLimitForm.enable_alphanumeric_validation
    );
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

  const fetchIpGeolocation = async () => {
    try {
      const { data } = await getIpGeolocationEnabled();
      if (data) {
        ipGeoForm.enabled = data.enabled;
      }
    } catch (error) {
      Message.error('获取IP地理位置解析开关状态失败');
    }
  };

  const fetchAccountLimit = async () => {
    try {
      const { data } = await getUserAccountLimit();
      if (data) {
        Object.assign(accountLimitForm, data);
      }
    } catch (error) {
      Message.error('获取用户账号限制设置失败');
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

  const handleIpGeoSubmit = async () => {
    try {
      setLoading(true);
      await setIpGeolocationEnabled({
        enabled: ipGeoForm.enabled,
      });
      Message.success('IP地理位置解析开关保存成功');
      await fetchIpGeolocation();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '保存失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleIpGeoReset = () => {
    fetchIpGeolocation();
  };

  const handleAccountLimitSubmit = async () => {
    if (!isAnyValidationEnabled.value) {
      Message.warning('至少需要启用一种校验规则');
      return;
    }

    if (
      accountLimitForm.enable_length_validation &&
      accountLimitForm.min_length > accountLimitForm.max_length
    ) {
      Message.warning('最小长度不能大于最大长度');
      return;
    }

    try {
      setLoading(true);
      await updateUserAccountLimit({ ...accountLimitForm });
      Message.success('用户账号限制设置保存成功');
      await fetchAccountLimit();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '保存失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleAccountLimitReset = () => {
    fetchAccountLimit();
  };

  onMounted(() => {
    fetchAppName();
    fetchIpGeolocation();
    fetchAccountLimit();
  });
</script>

<style lang="less" scoped>
  .general-settings-container {
    padding: 0 20px 20px;
  }

  .settings-form {
    max-width: 800px;
    margin-top: 20px;
  }
</style>
