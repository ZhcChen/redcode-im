<template>
  <div class="api-test-container">
    <a-form
      :model="testForm"
      label-align="left"
      :label-col-props="{ span: 6 }"
      :wrapper-col-props="{ span: 18 }"
      class="settings-form"
      @submit="handleTestSubmit"
    >
      <a-form-item
        field="ip_address"
        :label="t('settingsApiTest.label.ipAddress')"
        :rules="[
          {
            required: true,
            message: t('settingsApiTest.validation.required'),
          },
          {
            validator: (value: any) => {
              const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
              if (!ipRegex.test(value)) {
                return t('settingsApiTest.validation.invalid');
              }
              return '';
            },
          },
        ]"
      >
        <a-input
          v-model="testForm.ip_address"
          :placeholder="t('settingsApiTest.placeholder.ipAddress')"
          :max-length="15"
        />
        <template #help>
          {{ t('settingsApiTest.help.ipAddress') }}
        </template>
      </a-form-item>

      <a-form-item>
        <a-space>
          <a-button type="primary" html-type="submit" :loading="loading">
            {{ t('settingsApiTest.action.test') }}
          </a-button>
          <a-button @click="handleClear">
            {{ t('settingsApiTest.action.clear') }}
          </a-button>
        </a-space>
      </a-form-item>
    </a-form>

    <a-card
      v-if="testResult"
      :title="t('settingsApiTest.result.title')"
      :bordered="false"
      class="result-card"
    >
      <a-descriptions :data="resultData" bordered :column="1" />
    </a-card>

    <a-alert
      v-if="errorMessage"
      type="error"
      :message="errorMessage"
      class="error-alert"
      closable
      @close="errorMessage = ''"
    />
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import axios, { type AxiosRequestConfig } from 'axios';
  import { resolveHttpErrorMessage } from '@/utils/i18n';

  type AdminRequestConfig = AxiosRequestConfig & {
    suppressGlobalErrorMessage?: boolean;
  };

  const { loading, setLoading } = useLoading(false);
  const { t } = useI18n();

  const testForm = reactive({
    ip_address: '',
  });

  const testResult = ref<any>(null);
  const errorMessage = ref('');

  const resultData = computed(() => {
    if (!testResult.value) return [];

    return [
      {
        label: t('settingsApiTest.result.ipAddress'),
        value: testResult.value.ip || '-',
      },
      {
        label: t('settingsApiTest.result.hostname'),
        value: testResult.value.hostname || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.city'),
        value: testResult.value.city || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.region'),
        value: testResult.value.region || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.country'),
        value: testResult.value.country || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.location'),
        value: testResult.value.loc || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.org'),
        value: testResult.value.org || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.postal'),
        value: testResult.value.postal || t('settingsApiTest.result.unknown'),
      },
      {
        label: t('settingsApiTest.result.timezone'),
        value: testResult.value.timezone || t('settingsApiTest.result.unknown'),
      },
    ];
  });

  const handleTestSubmit = async () => {
    if (!testForm.ip_address.trim()) {
      Message.warning(t('settingsApiTest.validation.required'));
      return;
    }

    const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!ipRegex.test(testForm.ip_address.trim())) {
      Message.warning(t('settingsApiTest.validation.invalid'));
      return;
    }

    try {
      setLoading(true);
      errorMessage.value = '';
      testResult.value = null;

      const requestConfig: AdminRequestConfig = {
        suppressGlobalErrorMessage: true,
      };
      const response = await axios.post(
        '/api/admin/test-geolocation-api',
        {
          ip_address: testForm.ip_address.trim(),
        },
        requestConfig
      );

      if (response.data && response.data.data) {
        testResult.value = response.data.data;
        Message.success(t('settingsApiTest.test.success'));
      } else {
        throw new Error(t('settingsApiTest.test.invalidResponse'));
      }
    } catch (error: any) {
      errorMessage.value = resolveHttpErrorMessage(error, {
        fallbackMessage: t('settingsApiTest.test.error'),
      });
      Message.error(errorMessage.value);
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    testForm.ip_address = '';
    testResult.value = null;
    errorMessage.value = '';
  };
</script>

<style lang="less" scoped>
  .api-test-container {
    padding: 20px 0;
  }

  .settings-form {
    max-width: 800px;
  }

  .result-card {
    max-width: 800px;
    margin-top: 20px;
  }

  .error-alert {
    max-width: 800px;
    margin-top: 20px;
  }
</style>
