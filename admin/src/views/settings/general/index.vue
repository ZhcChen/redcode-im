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
              :closable="false"
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

        <a-tab-pane key="upload-policy" title="上传策略">
          <a-form
            :model="uploadPolicyForm"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            class="settings-form"
            @submit="handleUploadPolicySubmit"
          >
            <a-alert type="info" :closable="false" style="margin-bottom: 20px">
              用于下发给客户端（Flutter/Desktop）统一附件大小/数量/MIME
              白名单等限制；当客户端未能拉取策略时会回退到本地默认值。
            </a-alert>

            <a-form-item field="version" label="策略版本">
              <a-input
                v-model="uploadPolicyForm.version"
                placeholder="例如 2025-12-31 或 v1"
                maxlength="50"
              />
              <template #help>
                可用于排查“客户端未刷新策略”的问题，建议每次变更时递增版本。
              </template>
            </a-form-item>

            <a-form-item label="消息级限制">
              <a-space>
                <a-input-number
                  v-model="uploadPolicyForm.max_attachments_per_message"
                  :min="0"
                  :max="200"
                  style="width: 200px"
                  placeholder="单条消息最多附件数"
                />
                <a-input-number
                  v-model="uploadPolicyForm.max_total_size_mb"
                  :min="1"
                  :max="10000"
                  style="width: 200px"
                  placeholder="单条消息附件总大小（MB）"
                />
              </a-space>
            </a-form-item>

            <a-form-item label="单文件大小上限（MB）">
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

            <a-form-item label="语音消息规则（audio_only）">
              <a-space wrap>
                <a-switch v-model="uploadPolicyForm.audio_only.enabled" />
                <span>启用</span>
                <a-switch
                  v-model="uploadPolicyForm.audio_only.force_single_attachment"
                />
                <span>强制单附件</span>
                <a-switch v-model="uploadPolicyForm.audio_only.allow_text" />
                <span>允许携带文本</span>
              </a-space>
            </a-form-item>

            <a-form-item label="MIME 白名单（image，每行一个）">
              <a-textarea
                v-model="uploadPolicyMimeText.image"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                placeholder="例如 image/png"
              />
            </a-form-item>

            <a-form-item label="MIME 白名单（video，每行一个）">
              <a-textarea
                v-model="uploadPolicyMimeText.video"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                placeholder="例如 video/mp4"
              />
            </a-form-item>

            <a-form-item label="MIME 白名单（audio，每行一个）">
              <a-textarea
                v-model="uploadPolicyMimeText.audio"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                placeholder="例如 audio/mp4"
              />
            </a-form-item>

            <a-form-item label="MIME 白名单（file，每行一个）">
              <a-textarea
                v-model="uploadPolicyMimeText.file"
                :auto-size="{ minRows: 4, maxRows: 10 }"
                placeholder="例如 application/pdf"
              />
              <template #help>
                当前汇总白名单数量：{{ uploadPolicyMimeWhitelist.length }}
                （后台会自动去重/转小写，并过滤危险类型）。
              </template>
            </a-form-item>

            <a-form-item label="最后更新">
              <a-space>
                <span>{{ formatTime(uploadPolicyMeta.updated_at) }}</span>
                <span v-if="uploadPolicyMeta.updated_by">
                  updated_by: {{ uploadPolicyMeta.updated_by }}
                </span>
              </a-space>
            </a-form-item>

            <a-form-item>
              <a-space>
                <a-button type="primary" html-type="submit" :loading="loading">
                  保存设置
                </a-button>
                <a-button @click="handleUploadPolicyReset"> 重置 </a-button>
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
    getUploadPolicy,
    updateUploadPolicy,
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

  const formatTime = (value?: string) => {
    if (!value) return '暂无';
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
    } catch (error) {
      Message.error('获取上传策略失败');
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

  const handleUploadPolicySubmit = async () => {
    if (!uploadPolicyForm.version.trim()) {
      Message.warning('请输入策略版本');
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
      Message.success('上传策略保存成功');
      await fetchUploadPolicy();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '保存失败，请重试');
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
