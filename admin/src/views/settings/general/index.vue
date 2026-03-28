<template>
  <div class="general-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.general']" />
    <a-card
      class="general-card"
      :title="t('settingsGeneral.title')"
      :bordered="false"
    >
      <a-tabs default-active-key="app-name">
        <a-tab-pane key="app-name" :title="t('settingsGeneral.tab.appName')">
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
              :label="t('settingsGeneral.appName.label')"
              :rules="[
                {
                  required: true,
                  message: t('settingsGeneral.appName.validation.required'),
                },
                {
                  maxLength: 50,
                  message: t('settingsGeneral.appName.validation.maxLength'),
                },
              ]"
            >
              <a-input
                v-model="appNameForm.app_name"
                :placeholder="t('settingsGeneral.appName.placeholder')"
                maxlength="50"
                show-word-limit
              />
              <template #help>
                {{ t('settingsGeneral.appName.help') }}
              </template>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  {{ t('settingsGeneral.action.save') }}
                </a-button>
                <a-button @click="handleAppNameReset">
                  {{ t('settingsGeneral.action.reset') }}
                </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane
          key="ip-geolocation"
          :title="t('settingsGeneral.tab.ipGeolocation')"
        >
          <a-form
            :model="ipGeoForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleIpGeoSubmit"
          >
            <a-form-item
              field="enabled"
              :label="t('settingsGeneral.ipGeolocation.label')"
            >
              <a-switch v-model="ipGeoForm.enabled" />
              <template #help>
                {{ t('settingsGeneral.ipGeolocation.help') }}
              </template>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  {{ t('settingsGeneral.action.save') }}
                </a-button>
                <a-button @click="handleIpGeoReset">
                  {{ t('settingsGeneral.action.reset') }}
                </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane
          key="user-account-limit"
          :title="t('settingsGeneral.tab.userAccountLimit')"
        >
          <a-form
            :model="accountLimitForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleAccountLimitSubmit"
          >
            <a-form-item
              field="enable_phone_validation"
              :label="t('settingsGeneral.accountLimit.phone.label')"
            >
              <a-switch v-model="accountLimitForm.enable_phone_validation" />
              <template #help>
                {{ t('settingsGeneral.accountLimit.phone.help') }}
              </template>
            </a-form-item>

            <a-form-item
              field="enable_email_validation"
              :label="t('settingsGeneral.accountLimit.email.label')"
            >
              <a-switch v-model="accountLimitForm.enable_email_validation" />
              <template #help>
                {{ t('settingsGeneral.accountLimit.email.help') }}
              </template>
            </a-form-item>

            <a-form-item
              field="enable_length_validation"
              :label="t('settingsGeneral.accountLimit.length.label')"
            >
              <a-switch v-model="accountLimitForm.enable_length_validation" />
              <template #help>
                {{ t('settingsGeneral.accountLimit.length.help') }}
              </template>
            </a-form-item>

            <a-form-item
              v-if="accountLimitForm.enable_length_validation"
              field="min_length"
              :label="t('settingsGeneral.accountLimit.minLength.label')"
              :rules="[
                {
                  required: true,
                  message: t(
                    'settingsGeneral.accountLimit.validation.minLengthRequired'
                  ),
                },
                {
                  type: 'number',
                  min: 3,
                  max: 50,
                  message: t(
                    'settingsGeneral.accountLimit.validation.lengthRange'
                  ),
                },
              ]"
            >
              <a-input-number
                v-model="accountLimitForm.min_length"
                :min="3"
                :max="50"
                :placeholder="
                  t('settingsGeneral.accountLimit.minLength.placeholder')
                "
                style="width: 200px"
              />
            </a-form-item>

            <a-form-item
              v-if="accountLimitForm.enable_length_validation"
              field="max_length"
              :label="t('settingsGeneral.accountLimit.maxLength.label')"
              :rules="[
                {
                  required: true,
                  message: t(
                    'settingsGeneral.accountLimit.validation.maxLengthRequired'
                  ),
                },
                {
                  type: 'number',
                  min: 3,
                  max: 50,
                  message: t(
                    'settingsGeneral.accountLimit.validation.lengthRange'
                  ),
                },
              ]"
            >
              <a-input-number
                v-model="accountLimitForm.max_length"
                :min="3"
                :max="50"
                :placeholder="
                  t('settingsGeneral.accountLimit.maxLength.placeholder')
                "
                style="width: 200px"
              />
            </a-form-item>

            <a-form-item
              field="enable_alphanumeric_validation"
              :label="t('settingsGeneral.accountLimit.alphanumeric.label')"
            >
              <a-switch
                v-model="accountLimitForm.enable_alphanumeric_validation"
              />
              <template #help>
                {{ t('settingsGeneral.accountLimit.alphanumeric.help') }}
              </template>
            </a-form-item>

            <a-alert
              v-if="!isAnyValidationEnabled"
              type="warning"
              :closable="false"
              style="margin-bottom: 20px"
            >
              {{ t('settingsGeneral.accountLimit.validation.minRequired') }}
            </a-alert>

            <a-form-item>
              <a-space>
                <a-button
                  type="primary"
                  html-type="submit"
                  :loading="loading"
                  :disabled="!isAnyValidationEnabled"
                >
                  {{ t('settingsGeneral.action.save') }}
                </a-button>
                <a-button @click="handleAccountLimitReset">
                  {{ t('settingsGeneral.action.reset') }}
                </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane
          key="upload-policy"
          :title="t('settingsGeneral.tab.uploadPolicy')"
        >
          <a-form
            :model="uploadPolicyForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleUploadPolicySubmit"
          >
            <a-alert type="info" :closable="false" style="margin-bottom: 20px">
              {{ t('settingsGeneral.uploadPolicy.info') }}
            </a-alert>

            <a-form-item
              field="version"
              :label="t('settingsGeneral.uploadPolicy.version.label')"
            >
              <a-input
                v-model="uploadPolicyForm.version"
                :placeholder="
                  t('settingsGeneral.uploadPolicy.version.placeholder')
                "
                maxlength="50"
              />
              <template #help>
                {{ t('settingsGeneral.uploadPolicy.version.help') }}
              </template>
            </a-form-item>

            <a-form-item
              :label="t('settingsGeneral.uploadPolicy.messageLimit.label')"
            >
              <a-space>
                <a-input-number
                  v-model="uploadPolicyForm.max_attachments_per_message"
                  :min="0"
                  :max="200"
                  style="width: 200px"
                  :placeholder="
                    t('settingsGeneral.uploadPolicy.messageLimit.attachments')
                  "
                />
                <a-input-number
                  v-model="uploadPolicyForm.max_total_size_mb"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  :placeholder="
                    t('settingsGeneral.uploadPolicy.messageLimit.totalSize')
                  "
                />
              </a-space>
            </a-form-item>

            <a-form-item
              :label="t('settingsGeneral.uploadPolicy.fileMaxSize.label')"
            >
              <a-space wrap>
                <a-input-number
                  v-model="uploadPolicyForm.max_size_mb_by_part_type.image"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  placeholder="image"
                />
                <a-input-number
                  v-model="uploadPolicyForm.max_size_mb_by_part_type.video"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  placeholder="video"
                />
                <a-input-number
                  v-model="uploadPolicyForm.max_size_mb_by_part_type.audio"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  placeholder="audio"
                />
                <a-input-number
                  v-model="uploadPolicyForm.max_size_mb_by_part_type.file"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  placeholder="file"
                />
              </a-space>
            </a-form-item>

            <a-form-item
              :label="t('settingsGeneral.uploadPolicy.audioOnly.label')"
            >
              <a-space wrap>
                <a-switch
                  v-model="uploadPolicyForm.audio_only.enabled"
                  disabled
                />
                <span>{{ t('settingsGeneral.uploadPolicy.audioOnly.enabled') }}</span>
                <a-switch
                  v-model="uploadPolicyForm.audio_only.force_single_attachment"
                  disabled
                />
                <span>
                  {{ t('settingsGeneral.uploadPolicy.audioOnly.forceSingle') }}
                </span>
                <a-switch
                  v-model="uploadPolicyForm.audio_only.allow_text"
                  disabled
                />
                <span>
                  {{ t('settingsGeneral.uploadPolicy.audioOnly.allowText') }}
                </span>
              </a-space>
              <template #help>
                {{ t('settingsGeneral.uploadPolicy.audioOnly.help') }}
              </template>
            </a-form-item>

            <a-form-item :label="t('settingsGeneral.uploadPolicy.mime.image')">
              <a-textarea
                v-model="uploadPolicyMimeText.image"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                :placeholder="
                  t('settingsGeneral.uploadPolicy.mime.imagePlaceholder')
                "
              />
            </a-form-item>

            <a-form-item :label="t('settingsGeneral.uploadPolicy.mime.video')">
              <a-textarea
                v-model="uploadPolicyMimeText.video"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                :placeholder="
                  t('settingsGeneral.uploadPolicy.mime.videoPlaceholder')
                "
              />
            </a-form-item>

            <a-form-item :label="t('settingsGeneral.uploadPolicy.mime.audio')">
              <a-textarea
                v-model="uploadPolicyMimeText.audio"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                :placeholder="
                  t('settingsGeneral.uploadPolicy.mime.audioPlaceholder')
                "
              />
            </a-form-item>

            <a-form-item :label="t('settingsGeneral.uploadPolicy.mime.file')">
              <a-textarea
                v-model="uploadPolicyMimeText.file"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                :placeholder="
                  t('settingsGeneral.uploadPolicy.mime.filePlaceholder')
                "
              />
              <template #help>
                {{
                  t('settingsGeneral.uploadPolicy.mime.fileHelp', {
                    count: uploadPolicyMimeWhitelist.length,
                  })
                }}
              </template>
            </a-form-item>

            <a-form-item :label="t('settingsGeneral.uploadPolicy.updatedAt')">
              <a-space>
                <span>{{ formatTime(uploadPolicyMeta.updated_at) }}</span>
                <span v-if="uploadPolicyMeta.updated_by">
                  {{
                    t('settingsGeneral.uploadPolicy.updatedBy', {
                      user: uploadPolicyMeta.updated_by,
                    })
                  }}
                </span>
              </a-space>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  {{ t('settingsGeneral.action.save') }}
                </a-button>
                <a-button @click="handleUploadPolicyReset">
                  {{ t('settingsGeneral.action.reset') }}
                </a-button>
              </a-space>
            </a-form-item>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="api-test" :title="t('settingsGeneral.tab.apiTest')">
          <ApiTest />
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { reactive, onMounted, computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    getAppName,
    updateAppName,
    getIpGeolocationEnabled,
    setIpGeolocationEnabled,
    getUserAccountLimit,
    updateUserAccountLimit,
    getUploadPolicy,
    updateUploadPolicy,
  } from '@/api/settings';
  import ApiTest from '../api-test/index.vue';

  const { loading, setLoading } = useLoading(false);
  const { t } = useI18n();

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

  const uploadPolicyMeta = reactive({
    updated_at: '',
    updated_by: '',
  });

  const uploadPolicyForm = reactive({
    version: '',
    max_total_size_mb: 100,
    max_attachments_per_message: 10,
    max_size_mb_by_part_type: {
      image: 5,
      video: 100,
      audio: 20,
      file: 50,
    },
    audio_only: {
      enabled: true,
      force_single_attachment: true,
      allow_text: false,
    },
  });

  const uploadPolicyMimeText = reactive({
    image: '',
    video: '',
    audio: '',
    file: '',
  });

  const splitMimeLines = (raw: string): string[] => {
    return raw
      .split(/[\n,]/g)
      .map((v) => v.trim())
      .filter((v) => v);
  };

  const uploadPolicyMimeWhitelist = computed(() => {
    const list = [
      ...splitMimeLines(uploadPolicyMimeText.image),
      ...splitMimeLines(uploadPolicyMimeText.video),
      ...splitMimeLines(uploadPolicyMimeText.audio),
      ...splitMimeLines(uploadPolicyMimeText.file),
    ];
    const set = new Set(
      list.map((v) => v.trim().toLowerCase()).filter((v) => v)
    );
    return Array.from(set).sort();
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
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.appName.fetch.error'),
        })
      );
    }
  };

  const fetchIpGeolocation = async () => {
    try {
      const { data } = await getIpGeolocationEnabled();
      if (data) {
        ipGeoForm.enabled = data.enabled;
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.ipGeolocation.fetch.error'),
        })
      );
    }
  };

  const fetchAccountLimit = async () => {
    try {
      const { data } = await getUserAccountLimit();
      if (data) {
        Object.assign(accountLimitForm, data);
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.accountLimit.fetch.error'),
        })
      );
    }
  };

  const formatTime = (value?: string) => {
    if (!value) return t('settingsGeneral.empty');
    return new Date(value).toLocaleString();
  };

  const fetchUploadPolicy = async () => {
    try {
      const { data } = await getUploadPolicy();
      const policy = data?.policy;
      if (!policy) return;

      uploadPolicyMeta.updated_at = data.updated_at || '';
      uploadPolicyMeta.updated_by = data.updated_by || '';

      uploadPolicyForm.version = policy.version || '';
      uploadPolicyForm.max_total_size_mb = policy.max_total_size_mb ?? 100;
      uploadPolicyForm.max_attachments_per_message =
        policy.max_attachments_per_message ?? 10;
      uploadPolicyForm.max_size_mb_by_part_type = {
        image: policy.max_size_mb_by_part_type?.image ?? 5,
        video: policy.max_size_mb_by_part_type?.video ?? 100,
        audio: policy.max_size_mb_by_part_type?.audio ?? 20,
        file: policy.max_size_mb_by_part_type?.file ?? 50,
      };
      uploadPolicyForm.audio_only = {
        enabled: policy.audio_only?.enabled ?? true,
        force_single_attachment:
          policy.audio_only?.force_single_attachment ?? true,
        allow_text: policy.audio_only?.allow_text ?? false,
      };

      uploadPolicyMimeText.image = (policy.mime_by_part_type?.image ?? []).join(
        '\n'
      );
      uploadPolicyMimeText.video = (policy.mime_by_part_type?.video ?? []).join(
        '\n'
      );
      uploadPolicyMimeText.audio = (policy.mime_by_part_type?.audio ?? []).join(
        '\n'
      );
      uploadPolicyMimeText.file = (policy.mime_by_part_type?.file ?? []).join(
        '\n'
      );
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.uploadPolicy.fetch.error'),
        })
      );
    }
  };

  const handleAppNameSubmit = async () => {
    if (!appNameForm.app_name.trim()) {
      Message.warning(t('settingsGeneral.appName.validation.required'));
      return;
    }

    try {
      setLoading(true);
      await updateAppName({
        app_name: appNameForm.app_name.trim(),
      });
      Message.success(t('settingsGeneral.appName.save.success'));
      await fetchAppName();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.appName.save.error'),
        })
      );
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
      Message.success(t('settingsGeneral.ipGeolocation.save.success'));
      await fetchIpGeolocation();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.ipGeolocation.save.error'),
        })
      );
    } finally {
      setLoading(false);
    }
  };

  const handleIpGeoReset = () => {
    fetchIpGeolocation();
  };

  const handleAccountLimitSubmit = async () => {
    if (!isAnyValidationEnabled.value) {
      Message.warning(t('settingsGeneral.accountLimit.validation.minRequired'));
      return;
    }

    if (
      accountLimitForm.enable_length_validation &&
      accountLimitForm.min_length > accountLimitForm.max_length
    ) {
      Message.warning(
        t('settingsGeneral.accountLimit.validation.minGreaterThanMax')
      );
      return;
    }

    try {
      setLoading(true);
      await updateUserAccountLimit({ ...accountLimitForm });
      Message.success(t('settingsGeneral.accountLimit.save.success'));
      await fetchAccountLimit();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.accountLimit.save.error'),
        })
      );
    } finally {
      setLoading(false);
    }
  };

  const handleAccountLimitReset = () => {
    fetchAccountLimit();
  };

  const handleUploadPolicySubmit = async () => {
    if (!uploadPolicyForm.version.trim()) {
      Message.warning(
        t('settingsGeneral.uploadPolicy.validation.versionRequired')
      );
      return;
    }

    try {
      setLoading(true);
      await updateUploadPolicy({
        version: uploadPolicyForm.version.trim(),
        max_total_size_mb: uploadPolicyForm.max_total_size_mb,
        max_attachments_per_message:
          uploadPolicyForm.max_attachments_per_message,
        max_size_mb_by_part_type: uploadPolicyForm.max_size_mb_by_part_type,
        mime_by_part_type: {
          image: splitMimeLines(uploadPolicyMimeText.image),
          video: splitMimeLines(uploadPolicyMimeText.video),
          audio: splitMimeLines(uploadPolicyMimeText.audio),
          file: splitMimeLines(uploadPolicyMimeText.file),
        },
        audio_only: uploadPolicyForm.audio_only,
      });
      Message.success(t('settingsGeneral.uploadPolicy.save.success'));
      await fetchUploadPolicy();
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('settingsGeneral.uploadPolicy.save.error'),
        })
      );
    } finally {
      setLoading(false);
    }
  };

  const handleUploadPolicyReset = () => {
    fetchUploadPolicy();
  };

  onMounted(() => {
    fetchAppName();
    fetchIpGeolocation();
    fetchAccountLimit();
    fetchUploadPolicy();
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
