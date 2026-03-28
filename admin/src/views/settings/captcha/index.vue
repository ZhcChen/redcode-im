<template>
  <div class="captcha-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.captcha']" />
    <a-card
      class="general-card"
      :title="$t('captcha.title')"
      :bordered="false"
    >
      <div class="warning-alert">
        <a-alert type="warning" show-icon>
          <strong>{{ $t('captcha.warning.title') }}</strong>
          {{ $t('captcha.warning.description') }}
        </a-alert>
      </div>

      <a-form
        :model="formData"
        label-align="left"
        :label-col-props="{ span: 8 }"
        :wrapper-col-props="{ span: 16 }"
        class="settings-form"
        @submit="handleSubmit"
      >
        <a-form-item
          field="enabled"
          :label="$t('captcha.enabled.label')"
        >
          <a-switch
            v-model="formData.enabled"
            :checked-text="$t('captcha.switch.on')"
            :unchecked-text="$t('captcha.switch.off')"
            :checked-value="true"
            :unchecked-value="false"
          />
          <template #help>
            {{ $t('captcha.enabled.help') }}
          </template>
        </a-form-item>

        <a-form-item
          field="require_captcha_for_login"
          :label="$t('captcha.requireLogin.label')"
        >
          <a-switch
            v-model="formData.require_captcha_for_login"
            :checked-text="$t('captcha.switch.on')"
            :unchecked-text="$t('captcha.switch.off')"
            :checked-value="true"
            :unchecked-value="false"
          />
          <template #help>
            {{ $t('captcha.requireLogin.help') }}
          </template>
        </a-form-item>

        <a-form-item
          field="captcha_code"
          :label="$t('captcha.captchaCode.label')"
          :rules="[
            {
              required: formData.enabled,
              message: $t('captcha.error.required'),
            },
            { minLength: 4, message: $t('captcha.error.minLength') },
            { maxLength: 8, message: $t('captcha.error.maxLength') },
          ]"
        >
          <a-input
            v-model="formData.captcha_code"
            :placeholder="$t('captcha.captchaCode.placeholder')"
            :disabled="!formData.enabled"
            maxlength="8"
          />
          <template #help>
            {{ $t('captcha.captchaCode.help') }}
          </template>
        </a-form-item>

        <a-form-item field="description" :label="$t('captcha.description.label')">
          <a-textarea
            v-model="formData.description"
            :placeholder="$t('captcha.description.placeholder')"
            :rows="3"
            :disabled="!formData.enabled"
            maxlength="100"
          />
          <template #help>
            {{ $t('captcha.description.help') }}
          </template>
        </a-form-item>

        <a-form-item field="preview" :label="$t('captcha.preview.label')">
          <a-card
            class="preview-card"
            :bordered="true"
            size="small"
            style="max-width: 300px"
          >
            <div class="preview-content">
              <div v-if="formData.enabled && formData.captcha_code">
                <div class="demo-label">{{ $t('captcha.demo.label') }}</div>
                <div class="demo-captcha">
                  <a-input
                    :value="formData.captcha_code"
                    readonly
                    :placeholder="$t('captcha.demo.placeholder')"
                    style="font-weight: bold; text-align: center"
                  />
                  <div class="demo-help">
                    {{ $t('captcha.demo.help') }}
                  </div>
                </div>
              </div>
              <div v-else class="demo-disabled">
                {{ $t('captcha.demo.disabled') }}
              </div>
            </div>
          </a-card>
        </a-form-item>

        <a-form-item>
          <a-space>
            <a-button type="primary" html-type="submit" :loading="loading">
              {{ $t('captcha.save') }}
            </a-button>
            <a-button @click="handleReset"> {{ $t('captcha.reset') }} </a-button>
            <a-button
              v-if="formData.enabled"
              type="outline"
              status="warning"
              @click="clearCaptcha"
            >
              {{ $t('captcha.clear') }}
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import { getCaptchaSetting, updateCaptchaSetting } from '@/api/user';

  const { loading, setLoading } = useLoading(false);
  const { t } = useI18n();

  const formData = reactive({
    enabled: false,
    captcha_code: '',
    description: '',
    require_captcha_for_login: false,
  });

  const fetchSettings = async () => {
    try {
      const { data } = await getCaptchaSetting();
      if (data) {
        formData.enabled = data.enabled;
        formData.captcha_code = data.captcha_code || '';
        formData.description = data.description || '';
        formData.require_captcha_for_login =
          data.require_captcha_for_login ?? false;
      }
    } catch (error) {
      Message.error(t('captcha.fetch.error'));
      formData.enabled = false;
      formData.captcha_code = '';
      formData.description = '';
      formData.require_captcha_for_login = false;
    }
  };

  const clearCaptcha = async () => {
    try {
      setLoading(true);
      await updateCaptchaSetting({
        enabled: false,
        captcha_code: '',
        description: '',
      });

      formData.enabled = false;
      formData.captcha_code = '';
      formData.description = '';

      Message.success(t('captcha.success.clear'));
    } catch (error) {
      Message.error(t('captcha.error.clear'));
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    if (formData.enabled && !formData.captcha_code.trim()) {
      Message.warning(t('captcha.error.required'));
      return;
    }

    try {
      setLoading(true);
      const settings = {
        enabled: formData.enabled,
        captcha_code: formData.enabled ? formData.captcha_code.trim() : '',
        description: formData.enabled ? formData.description.trim() : '',
        require_captcha_for_login: formData.require_captcha_for_login,
      };

      await updateCaptchaSetting(settings);
      Message.success(t('captcha.success.save'));

      await fetchSettings();
    } catch (error) {
      Message.error(t('captcha.error.save'));
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
  .captcha-settings-container {
    padding: 0 20px 20px;

    .general-card {
      .warning-alert {
        margin-bottom: 24px;
      }

      .settings-form {
        max-width: 600px;

        .preview-card {
          background-color: var(--color-fill-1);

          .preview-content {
            .demo-label {
              margin-bottom: 12px;
              color: var(--color-text-3);
              font-size: 12px;
            }

            .demo-captcha {
              .demo-help {
                margin-top: 8px;
                color: var(--color-text-3);
                font-size: 12px;
                text-align: center;
              }
            }

            .demo-disabled {
              padding: 20px 0;
              color: var(--color-text-3);
              font-size: 14px;
              text-align: center;
            }
          }
        }
      }
    }
  }

  :deep(.arco-form-item-content-flex) {
    flex-wrap: wrap;

    .arco-button {
      margin-right: 8px;
      margin-bottom: 8px;
    }
  }

  :deep(.arco-alert-warning) {
    background-color: #fff7e6;
    border-color: #ffd591;

    .arco-alert-message {
      color: #d46b08;
    }
  }
</style>
