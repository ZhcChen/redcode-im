<template>
  <div class="user-account-limit-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.userAccountLimit']" />
    <a-card
      class="user-account-limit-card"
      title="用户账号限制"
      :bordered="false"
    >
      <a-form
        :model="form"
        label-align="left"
        :label-col-props="{ span: 6 }"
        :wrapper-col-props="{ span: 18 }"
        class="settings-form"
        @submit="handleSubmit"
      >
        <a-form-item field="enable_phone_validation" label="启用手机号校验">
          <a-switch v-model="form.enable_phone_validation" />
          <template #help>
            启用后，注册用户账号（用户名）必须符合手机号格式
          </template>
        </a-form-item>

        <a-form-item field="enable_email_validation" label="启用邮箱校验">
          <a-switch v-model="form.enable_email_validation" />
          <template #help>
            启用后，注册用户账号（用户名）必须符合邮箱格式
          </template>
        </a-form-item>

        <a-form-item field="enable_length_validation" label="启用长度校验">
          <a-switch v-model="form.enable_length_validation" />
          <template #help>
            启用后，注册用户账号（用户名）必须符合长度限制
          </template>
        </a-form-item>

        <a-form-item
          v-if="form.enable_length_validation"
          field="min_length"
          label="最小长度"
          :rules="[
            { required: true, message: '请输入最小长度' },
            { type: 'number', min: 3, max: 50, message: '长度范围：3-50' },
          ]"
        >
          <a-input-number
            v-model="form.min_length"
            :min="3"
            :max="50"
            placeholder="最小长度"
            style="width: 200px"
          />
        </a-form-item>

        <a-form-item
          v-if="form.enable_length_validation"
          field="max_length"
          label="最大长度"
          :rules="[
            { required: true, message: '请输入最大长度' },
            { type: 'number', min: 3, max: 50, message: '长度范围：3-50' },
          ]"
        >
          <a-input-number
            v-model="form.max_length"
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
          <a-switch v-model="form.enable_alphanumeric_validation" />
          <template #help>
            启用后，注册用户账号（用户名）必须同时包含字母和数字
          </template>
        </a-form-item>

        <a-alert
          v-if="!isAnyValidationEnabled"
          type="warning"
          :
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
            <a-button @click="handleReset"> 重置 </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted, computed } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import { getUserAccountLimit, updateUserAccountLimit } from '@/api/settings';

  const { loading, setLoading } = useLoading(false);

  const form = reactive({
    enable_phone_validation: false,
    enable_email_validation: false,
    enable_length_validation: false,
    min_length: 3,
    max_length: 20,
    enable_alphanumeric_validation: false,
  });

  const isAnyValidationEnabled = computed(() => {
    return (
      form.enable_phone_validation ||
      form.enable_email_validation ||
      form.enable_length_validation ||
      form.enable_alphanumeric_validation
    );
  });

  const fetchSettings = async () => {
    try {
      const { data } = await getUserAccountLimit();
      if (data) {
        Object.assign(form, data);
      }
    } catch (error) {
      Message.error('获取设置失败');
    }
  };

  const handleSubmit = async () => {
    if (!isAnyValidationEnabled.value) {
      Message.warning('至少需要启用一种校验规则');
      return;
    }

    if (form.enable_length_validation && form.min_length > form.max_length) {
      Message.warning('最小长度不能大于最大长度');
      return;
    }

    try {
      setLoading(true);
      await updateUserAccountLimit({ ...form });
      Message.success('设置保存成功');
      await fetchSettings();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '保存失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    fetchSettings();
  };

  onMounted(() => {
    fetchSettings();
  });
</script>

<style lang="less" scoped>
  .user-account-limit-container {
    padding: 0 20px 20px;
  }

  .settings-form {
    max-width: 800px;
    margin-top: 20px;
  }
</style>
