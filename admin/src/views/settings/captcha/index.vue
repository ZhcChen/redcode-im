<template>
  <div class="captcha-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.captcha']" />
    <a-card class="general-card" title="验证码设置" :bordered="false">
      <div class="warning-alert">
        <a-alert type="warning" show-icon>
          <template #message>
            <div>
              <strong>⚠️ 测试人员请注意：</strong
              >这里设置的通用验证码仅用于测试环境，请勿在生产环境中使用，存在安全风险。
            </div>
          </template>
        </a-alert>
      </div>

      <a-form
        :model="formData"
        label-align="left"
        :label-col-props="{ span: 6 }"
        :wrapper-col-props="{ span: 18 }"
        class="settings-form"
        @submit="handleSubmit"
      >
        <a-form-item field="enabled" label="启用验证码">
          <a-switch
            v-model="formData.enabled"
            checked-text="开启"
            unchecked-text="关闭"
            :checked-value="true"
            :unchecked-value="false"
          />
        </a-form-item>

        <a-form-item
          field="captcha_code"
          label="通用验证码"
          :rules="[
            { required: formData.enabled, message: '请输入验证码' },
            { minLength: 4, message: '验证码至少4位' },
            { maxLength: 8, message: '验证码最多8位' },
          ]"
        >
          <a-input
            v-model="formData.captcha_code"
            placeholder="请输入4-8位验证码"
            :disabled="!formData.enabled"
            maxlength="8"
          />
          <template #help>
            设置后，用户登录/注册时可以使用此验证码绕过验证。仅用于测试环境。
          </template>
        </a-form-item>

        <a-form-item field="description" label="说明备注">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入验证码的使用说明或备注"
            :rows="3"
            :disabled="!formData.enabled"
            maxlength="100"
          />
          <template #help> 可选，记录此验证码的用途和使用说明。 </template>
        </a-form-item>

        <a-form-item field="preview" label="预览效果">
          <a-card
            class="preview-card"
            :bordered="true"
            size="small"
            style="max-width: 300px"
          >
            <div class="preview-content">
              <div v-if="formData.enabled && formData.captcha_code">
                <div class="demo-label">用户登录/注册页面将显示：</div>
                <div class="demo-captcha">
                  <a-input
                    :value="formData.captcha_code"
                    readonly
                    placeholder="验证码"
                    style="text-align: center; font-weight: bold"
                  />
                  <div class="demo-help">
                    测试人员可直接输入此验证码完成验证
                  </div>
                </div>
              </div>
              <div v-else class="demo-disabled"> 验证码功能已关闭 </div>
            </div>
          </a-card>
        </a-form-item>

        <a-form-item>
          <a-space>
            <a-button type="primary" html-type="submit" :loading="loading">
              保存设置
            </a-button>
            <a-button @click="handleReset"> 重置 </a-button>
            <a-button
              v-if="formData.enabled"
              type="outline"
              status="warning"
              @click="clearCaptcha"
            >
              清空验证码
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import { getCaptchaSetting, updateCaptchaSetting } from '@/api/user';

  const { loading, setLoading } = useLoading(false);

  const formData = reactive({
    enabled: false,
    captcha_code: '',
    description: '',
  });

  const fetchSettings = async () => {
    try {
      const { data } = await getCaptchaSetting();
      if (data) {
        formData.enabled = data.enabled;
        formData.captcha_code = data.captcha_code || '';
        formData.description = data.description || '';
      }
    } catch (error) {
      // 使用默认设置
      formData.enabled = false;
      formData.captcha_code = '';
      formData.description = '';
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

      Message.success('验证码已清空，功能已关闭');
    } catch (error) {
      Message.error('操作失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    if (formData.enabled && !formData.captcha_code.trim()) {
      Message.warning('请输入验证码');
      return;
    }

    try {
      setLoading(true);
      const settings = {
        enabled: formData.enabled,
        captcha_code: formData.enabled ? formData.captcha_code.trim() : '',
        description: formData.enabled ? formData.description.trim() : '',
      };

      await updateCaptchaSetting(settings);
      Message.success('验证码设置保存成功');

      await fetchSettings();
    } catch (error) {
      Message.error('保存失败，请重试');
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
    padding: 0 20px 20px 20px;

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
              font-size: 12px;
              color: var(--color-text-3);
              margin-bottom: 12px;
            }

            .demo-captcha {
              .demo-help {
                text-align: center;
                font-size: 12px;
                color: var(--color-text-3);
                margin-top: 8px;
              }
            }

            .demo-disabled {
              color: var(--color-text-3);
              font-size: 14px;
              padding: 20px 0;
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
