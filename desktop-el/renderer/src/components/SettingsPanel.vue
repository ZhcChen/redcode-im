<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import { FeedbackApi } from "@/api/feedback";
import { SettingsApi, type AppNameResponse, type DocumentContent, type GeneralSettingsResponse } from "@/api/settings";
import { UserApi } from "@/api/user";
import { VersionApi, type AppVersionInfo } from "@/api/version";
import { AVATAR_INPUT_ACCEPT, validateAvatarFile } from "@/utils/user-avatar-upload";
import AgreementModal from "./AgreementModal.vue";
import type { BootstrapSnapshot } from "@/types/bootstrap";

type NoticeTone = "neutral" | "success" | "error";

const props = defineProps<{
  currentUser: LegacyUserInfo;
  bootstrap: BootstrapSnapshot | null;
  hostVersion: string | null;
  wsStatus: string;
  lastEvent: string;
}>();

const emit = defineEmits<{
  (event: "logout"): void;
  (event: "profile-updated", user: LegacyUserInfo): void;
}>();

const generalSettings = ref<GeneralSettingsResponse | null>(null);
const appNameResponse = ref<AppNameResponse | null>(null);
const isCheckingUpdate = ref(false);
const isDownloadingUpdate = ref(false);
const latestVersion = ref<AppVersionInfo | null>(null);
const hasUpdate = ref(false);
const updateNotice = ref("");
const downloadedInstallerPath = ref<string | null>(null);
const downloadedVersionId = ref<string | null>(null);
const noticeTone = ref<NoticeTone>("neutral");
const noticeMessage = ref("设置页核心流程已接入，当前支持资料编辑、账号安全、反馈与安装包下载。");
const agreementVisible = ref(false);
const agreementTitle = ref("文档");
const agreementContent = ref("");
const isEditingNickname = ref(false);
const isSavingNickname = ref(false);
const isEditingPassword = ref(false);
const isSavingPassword = ref(false);
const isUploadingAvatar = ref(false);
const isSubmittingFeedback = ref(false);
const nicknameDraft = ref("");
const oldPasswordDraft = ref("");
const newPasswordDraft = ref("");
const confirmPasswordDraft = ref("");
const feedbackContentDraft = ref("");
const feedbackContactDraft = ref("");
const avatarInputRef = ref<HTMLInputElement | null>(null);

const userDisplayName = computed(() => props.currentUser.nickname || props.currentUser.username || "用户");
const userInitial = computed(() => userDisplayName.value.slice(0, 1).toUpperCase());
const userAvatarUrl = computed(() => props.currentUser.avatar?.trim() || "");
const displayAppName = computed(
  () => generalSettings.value?.app_name || appNameResponse.value?.app_name || props.bootstrap?.config.app_name || "Chatly"
);
const currentVersion = computed(() => props.bootstrap?.config.version || "0.1.0");
const currentBuild = computed(() => props.bootstrap?.config.build_number || 0);
const currentChannel = computed(() => props.bootstrap?.config.channel || "stable");
const featureFlags = computed(() => Object.entries(props.bootstrap?.feature_flags ?? {}));
const avatarActionLabel = computed(() => {
  if (isUploadingAvatar.value) {
    return "上传中...";
  }
  return userAvatarUrl.value ? "更换头像" : "上传头像";
});
const downloadUpdateLabel = computed(() => {
  if (isDownloadingUpdate.value) {
    return "下载中...";
  }
  if (latestVersion.value?.id && downloadedVersionId.value === latestVersion.value.id && downloadedInstallerPath.value) {
    return "重新打开安装包";
  }
  return "下载并安装";
});

const setNotice = (tone: NoticeTone, message: string) => {
  noticeTone.value = tone;
  noticeMessage.value = message;
};

const resetAvatarInput = () => {
  if (avatarInputRef.value) {
    avatarInputRef.value.value = "";
  }
};

const openAvatarPicker = () => {
  if (isUploadingAvatar.value) {
    return;
  }
  avatarInputRef.value?.click();
};

const handleAvatarChange = async (event: Event) => {
  const input = event.target as HTMLInputElement | null;
  const file = input?.files?.[0];
  if (!file) {
    resetAvatarInput();
    return;
  }

  const validationMessage = validateAvatarFile(file);
  if (validationMessage) {
    setNotice("error", validationMessage);
    resetAvatarInput();
    return;
  }

  isUploadingAvatar.value = true;
  setNotice("neutral", "头像上传中，请稍候...");
  try {
    const response = await UserApi.uploadAvatar(file);
    if (!response.success || !response.data) {
      setNotice("error", response.message || "头像上传失败");
      return;
    }

    emit("profile-updated", response.data);
    setNotice("success", response.message || "头像更新成功");
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "头像上传失败");
  } finally {
    isUploadingAvatar.value = false;
    resetAvatarInput();
  }
};

const beginEditNickname = () => {
  nicknameDraft.value = props.currentUser.nickname || props.currentUser.username;
  isEditingNickname.value = true;
};

const beginEditPassword = () => {
  oldPasswordDraft.value = "";
  newPasswordDraft.value = "";
  confirmPasswordDraft.value = "";
  isEditingPassword.value = true;
};

const cancelEditNickname = () => {
  isEditingNickname.value = false;
  nicknameDraft.value = "";
};

const cancelEditPassword = () => {
  isEditingPassword.value = false;
  oldPasswordDraft.value = "";
  newPasswordDraft.value = "";
  confirmPasswordDraft.value = "";
};

const saveNickname = async () => {
  const nickname = nicknameDraft.value.trim();
  if (!nickname) {
    setNotice("error", "昵称不能为空");
    return;
  }
  if (nickname.length > 20) {
    setNotice("error", "昵称不能超过 20 个字符");
    return;
  }
  if (nickname === (props.currentUser.nickname || props.currentUser.username)) {
    setNotice("error", "新昵称与当前昵称相同");
    return;
  }

  isSavingNickname.value = true;
  try {
    const response = await UserApi.updateMe({ nickname });
    if (!response.success || !response.data) {
      setNotice("error", response.message || "昵称修改失败");
      return;
    }

    emit("profile-updated", response.data);
    isEditingNickname.value = false;
    nicknameDraft.value = "";
    setNotice("success", `昵称已更新为 ${response.data.nickname}`);
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "昵称修改失败");
  } finally {
    isSavingNickname.value = false;
  }
};

const savePassword = async () => {
  const oldPassword = oldPasswordDraft.value.trim();
  const newPassword = newPasswordDraft.value.trim();
  const confirmPassword = confirmPasswordDraft.value.trim();

  if (!oldPassword || !newPassword || !confirmPassword) {
    setNotice("error", "请完整填写当前密码、新密码和确认密码");
    return;
  }
  if (newPassword.length < 6) {
    setNotice("error", "新密码至少需要 6 位");
    return;
  }
  if (newPassword !== confirmPassword) {
    setNotice("error", "两次输入的新密码不一致");
    return;
  }
  if (oldPassword === newPassword) {
    setNotice("error", "新密码不能与当前密码相同");
    return;
  }

  isSavingPassword.value = true;
  try {
    const response = await UserApi.updateUserPassword({
      oldPwd: oldPassword,
      newPwd: newPassword
    });
    if (!response.success || !response.data?.success) {
      setNotice("error", response.data?.message || response.message || "修改密码失败");
      return;
    }

    cancelEditPassword();
    setNotice("success", response.data.message || response.message || "密码修改成功");
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "修改密码失败");
  } finally {
    isSavingPassword.value = false;
  }
};

const formatFileSize = (bytes?: number | null) => {
  if (!bytes || bytes <= 0) {
    return "未知大小";
  }

  if (bytes >= 1024 * 1024 * 1024) {
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  if (bytes >= 1024 * 1024) {
    return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
  }
  if (bytes >= 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${bytes} B`;
};

const inferInstallerFileName = (version: AppVersionInfo) => {
  const rawPath = (version.download_key || version.download_url || "").split("?")[0];
  const fileName = rawPath.split("/").pop();
  if (fileName) {
    return fileName;
  }

  const extension = version.platform === "macos" ? "dmg" : version.platform === "linux" ? "AppImage" : "exe";
  return `redcode-im-${version.version}.${extension}`;
};

const buildInstallerFilters = (version: AppVersionInfo) => {
  switch (version.platform) {
    case "macos":
      return [{ name: "Installer", extensions: ["dmg", "pkg", "zip"] }];
    case "linux":
      return [{ name: "Installer", extensions: ["AppImage", "deb", "rpm", "tar.gz"] }];
    case "windows":
    default:
      return [{ name: "Installer", extensions: ["exe", "msi", "zip"] }];
  }
};

const openInstaller = async (filePath: string) => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }

  await window.desktopEl.file.openPath(filePath);
  const notificationSupported = await window.desktopEl.notification.isSupported().catch(() => false);
  if (notificationSupported) {
    await window.desktopEl.notification
      .show({
        title: "安装包已打开",
        body: "请按系统提示完成更新安装。",
        silent: true
      })
      .catch(() => undefined);
  }
};

const submitFeedback = async () => {
  const content = feedbackContentDraft.value.trim();
  const contact = feedbackContactDraft.value.trim();

  if (!content) {
    setNotice("error", "反馈内容不能为空");
    return;
  }
  if (content.length < 10) {
    setNotice("error", "反馈内容不少于 10 个字");
    return;
  }

  isSubmittingFeedback.value = true;
  try {
    const response = await FeedbackApi.submit({
      content,
      contact
    });
    if (!response.success || !response.data?.success) {
      setNotice("error", response.data?.message || response.message || "反馈提交失败");
      return;
    }

    feedbackContentDraft.value = "";
    feedbackContactDraft.value = "";
    setNotice("success", response.data.message || response.message || "反馈提交成功");
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "反馈提交失败");
  } finally {
    isSubmittingFeedback.value = false;
  }
};

const loadGeneralSettings = async () => {
  try {
    const [generalResponse, appNameResult] = await Promise.all([
      SettingsApi.getGeneralSettings(),
      SettingsApi.getAppName()
    ]);

    if (generalResponse.success && generalResponse.data) {
      generalSettings.value = generalResponse.data;
    }

    if (appNameResult.success && appNameResult.data) {
      appNameResponse.value = appNameResult.data;
    }
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "加载通用设置失败");
  }
};

const openDocument = async (
  loader: () => Promise<{ success: boolean; data: DocumentContent | null; message: string }>
) => {
  try {
    const response = await loader();
    if (!response.success || !response.data) {
      setNotice("error", response.message || "加载文档失败");
      return;
    }

    agreementTitle.value = response.data.title;
    agreementContent.value = response.data.content;
    agreementVisible.value = true;
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "加载文档失败");
  }
};

const openAbout = () => {
  agreementTitle.value = `关于 ${displayAppName.value}`;
  agreementContent.value = `
    <p>应用名称：${displayAppName.value}</p>
    <p>桌面版本：v${currentVersion.value}</p>
    <p>构建号：${currentBuild.value}</p>
    <p>渠道：${currentChannel.value}</p>
    <p>Electron Host：${props.hostVersion ?? "unknown"}</p>
    <p>连接状态：${props.wsStatus}</p>
  `;
  agreementVisible.value = true;
};

const handleCheckUpdate = async () => {
  isCheckingUpdate.value = true;
  try {
    const previousVersionId = latestVersion.value?.id ?? null;
    const response = await VersionApi.getLatestVersion({
      channel: currentChannel.value,
      currentVersion: currentVersion.value
    });
    if (!response.success || !response.data) {
      setNotice("error", response.message || "检查更新失败");
      return;
    }

    hasUpdate.value = response.data.has_update;
    latestVersion.value = response.data.version ?? null;
    if (response.data.has_update && response.data.version) {
      updateNotice.value = `发现新版本 v${response.data.version.version}，可下载安装包继续升级。`;
      if (previousVersionId !== response.data.version.id) {
        downloadedInstallerPath.value = null;
        downloadedVersionId.value = null;
      }
      setNotice("success", `发现新版本 v${response.data.version.version}，可下载安装包继续升级。`);
      return;
    }

    updateNotice.value = "当前已经是最新版本。";
    downloadedInstallerPath.value = null;
    downloadedVersionId.value = null;
    setNotice("success", "当前已经是最新版本。");
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "检查更新失败");
  } finally {
    isCheckingUpdate.value = false;
  }
};

const handleDownloadUpdate = async () => {
  if (!window.desktopEl) {
    setNotice("error", "desktop-el runtime is not available");
    return;
  }

  const version = latestVersion.value;
  if (!hasUpdate.value || !version) {
    setNotice("error", "当前没有可下载的新版本");
    return;
  }

  if (downloadedVersionId.value === version.id && downloadedInstallerPath.value) {
    try {
      await openInstaller(downloadedInstallerPath.value);
      updateNotice.value = "安装包已打开，请按系统提示完成更新。";
      setNotice("success", updateNotice.value);
    } catch (error) {
      const message = error instanceof Error ? error.message : "打开安装包失败";
      updateNotice.value = message;
      setNotice("error", message);
    }
    return;
  }

  isDownloadingUpdate.value = true;
  try {
    const response = await VersionApi.getDownloadUrl({
      id: version.id,
      expiresInSeconds: 600
    });
    if (!response.success || !response.data?.success || !response.data.downloadUrl) {
      const message = response.data?.message || response.message || "获取下载链接失败";
      updateNotice.value = message;
      setNotice("error", message);
      return;
    }

    const saveResult = await window.desktopEl.dialog.save({
      title: `保存 ${displayAppName.value} 安装包`,
      defaultPath: inferInstallerFileName(version),
      filters: buildInstallerFilters(version)
    });
    if (saveResult.canceled || !saveResult.filePath) {
      updateNotice.value = "已取消下载安装包。";
      setNotice("neutral", updateNotice.value);
      return;
    }

    updateNotice.value = "安装包下载中，请稍候...";
    const saved = await window.desktopEl.file.saveFromURL({
      url: response.data.downloadUrl,
      filePath: saveResult.filePath
    });
    downloadedInstallerPath.value = saved.filePath;
    downloadedVersionId.value = version.id;
    updateNotice.value = `安装包已下载到 ${saved.filePath}`;
    await openInstaller(saved.filePath);
    setNotice("success", "安装包已打开，请按系统提示完成更新。");
  } catch (error) {
    const message = error instanceof Error ? error.message : "下载安装包失败";
    updateNotice.value = message;
    setNotice("error", message);
  } finally {
    isDownloadingUpdate.value = false;
  }
};

onMounted(() => {
  void loadGeneralSettings();
});
</script>

<template>
  <section class="settings-panel">
    <div class="settings-panel__notice" :class="`settings-panel__notice--${noticeTone}`">
      <span>{{ noticeMessage }}</span>
      <small>{{ displayAppName }}</small>
    </div>

    <div class="settings-panel__grid">
      <div class="settings-panel__main">
        <article class="settings-card settings-card--profile">
          <div class="settings-avatar">
            <img
              v-if="userAvatarUrl"
              :src="userAvatarUrl"
              :alt="`${userDisplayName} avatar`"
              class="settings-avatar__image"
            />
            <span v-else>{{ userInitial }}</span>
          </div>
          <div class="settings-card__copy">
            <h2>{{ userDisplayName }}</h2>
            <p>{{ props.currentUser.mobile }}</p>
            <span>{{ props.currentUser.email || "未绑定邮箱" }}</span>
          </div>
          <div class="settings-profile-actions">
            <input
              ref="avatarInputRef"
              type="file"
              class="settings-avatar-input"
              :accept="AVATAR_INPUT_ACCEPT"
              @change="handleAvatarChange"
            />
            <button
              type="button"
              class="settings-card__tag settings-card__tag--action"
              :disabled="isUploadingAvatar"
              @click="openAvatarPicker"
            >
              {{ avatarActionLabel }}
            </button>
            <small class="settings-profile-actions__hint">支持 PNG、JPG、WEBP、GIF、HEIC、HEIF、SVG，最大 5MB</small>
            <button
              v-if="!isEditingNickname"
              type="button"
              class="settings-card__tag settings-card__tag--action"
              @click="beginEditNickname"
            >
              修改昵称
            </button>
            <div v-else class="nickname-editor">
              <input v-model="nicknameDraft" class="nickname-editor__input" maxlength="20" placeholder="请输入新昵称" />
              <div class="nickname-editor__actions">
                <button type="button" class="nickname-editor__button" @click="cancelEditNickname">取消</button>
                <button
                  type="button"
                  class="nickname-editor__button nickname-editor__button--primary"
                  :disabled="isSavingNickname"
                  @click="saveNickname"
                >
                  {{ isSavingNickname ? "保存中..." : "保存" }}
                </button>
              </div>
            </div>
          </div>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>桌面端版本</h3>
            <div class="settings-card__actions">
              <button type="button" class="settings-action" :disabled="isCheckingUpdate" @click="handleCheckUpdate">
                {{ isCheckingUpdate ? "检查中..." : "检查更新" }}
              </button>
              <button
                v-if="hasUpdate && latestVersion"
                type="button"
                class="settings-action"
                :disabled="isDownloadingUpdate"
                @click="handleDownloadUpdate"
              >
                {{ downloadUpdateLabel }}
              </button>
            </div>
          </div>
          <dl class="settings-detail-list">
            <div>
              <dt>当前版本</dt>
              <dd>v{{ currentVersion }}</dd>
            </div>
            <div>
              <dt>构建号</dt>
              <dd>{{ currentBuild }}</dd>
            </div>
            <div>
              <dt>渠道</dt>
              <dd>{{ currentChannel }}</dd>
            </div>
            <div>
              <dt>最新状态</dt>
              <dd>
                {{
                  hasUpdate && latestVersion
                    ? `发现 v${latestVersion.version}`
                    : "等待检查"
                }}
              </dd>
            </div>
            <div v-if="latestVersion">
              <dt>安装包大小</dt>
              <dd>{{ formatFileSize(latestVersion.file_size) }}</dd>
            </div>
          </dl>
          <p v-if="updateNotice" class="settings-hint">{{ updateNotice }}</p>
          <p v-if="latestVersion?.release_notes" class="settings-hint">{{ latestVersion.release_notes }}</p>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>账号与安全</h3>
            <span class="settings-card__meta">password</span>
          </div>
          <p class="settings-hint">当前已接入密码修改，新密码至少 6 位。</p>
          <button
            v-if="!isEditingPassword"
            type="button"
            class="settings-card__tag settings-card__tag--action"
            @click="beginEditPassword"
          >
            修改密码
          </button>
          <div v-else class="password-editor">
            <input
              v-model="oldPasswordDraft"
              type="password"
              class="password-editor__input"
              autocomplete="current-password"
              placeholder="请输入当前密码"
            />
            <input
              v-model="newPasswordDraft"
              type="password"
              class="password-editor__input"
              autocomplete="new-password"
              placeholder="请输入新密码（至少 6 位）"
            />
            <input
              v-model="confirmPasswordDraft"
              type="password"
              class="password-editor__input"
              autocomplete="new-password"
              placeholder="请再次输入新密码"
            />
            <div class="password-editor__actions">
              <button type="button" class="password-editor__button" @click="cancelEditPassword">取消</button>
              <button
                type="button"
                class="password-editor__button password-editor__button--primary"
                :disabled="isSavingPassword"
                @click="savePassword"
              >
                {{ isSavingPassword ? "提交中..." : "提交" }}
              </button>
            </div>
          </div>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>通用</h3>
            <span class="settings-card__meta">通过 Go core 拉取</span>
          </div>
          <dl class="settings-detail-list">
            <div>
              <dt>应用名称</dt>
              <dd>{{ displayAppName }}</dd>
            </div>
            <div>
              <dt>环境</dt>
              <dd>{{ props.bootstrap?.config.environment ?? "development" }}</dd>
            </div>
            <div>
              <dt>API</dt>
              <dd>{{ props.bootstrap?.config.api_base_url ?? "未同步" }}</dd>
            </div>
            <div>
              <dt>WS</dt>
              <dd>{{ props.bootstrap?.config.ws_url ?? "未同步" }}</dd>
            </div>
          </dl>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>意见反馈</h3>
            <span class="settings-card__meta">feedback</span>
          </div>
          <div class="feedback-editor">
            <p class="settings-hint">欢迎提交问题与建议，反馈内容不少于 10 个字。</p>
            <textarea
              v-model="feedbackContentDraft"
              class="feedback-editor__textarea"
              maxlength="500"
              placeholder="请详细描述你遇到的问题、场景或希望改进的地方"
            />
            <div class="feedback-editor__footer">
              <small class="feedback-editor__count">{{ feedbackContentDraft.trim().length }}/500</small>
            </div>
            <input
              v-model="feedbackContactDraft"
              type="text"
              class="feedback-editor__input"
              maxlength="60"
              placeholder="邮箱、手机号或微信号（选填）"
            />
            <button type="button" class="settings-action" :disabled="isSubmittingFeedback" @click="submitFeedback">
              {{ isSubmittingFeedback ? "提交中..." : "提交反馈" }}
            </button>
          </div>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>协议与关于</h3>
            <span class="settings-card__meta">公开文档</span>
          </div>
          <div class="settings-link-list">
            <button type="button" class="settings-link" @click="openDocument(() => SettingsApi.getUserAgreement())">
              <strong>用户协议</strong>
              <small>查看当前公开用户协议</small>
            </button>
            <button type="button" class="settings-link" @click="openDocument(() => SettingsApi.getPrivacyPolicy())">
              <strong>隐私协议</strong>
              <small>查看当前公开隐私协议</small>
            </button>
            <button type="button" class="settings-link" @click="openAbout">
              <strong>关于 {{ displayAppName }}</strong>
              <small>查看桌面版本、构建号与连接信息</small>
            </button>
          </div>
        </article>

        <article class="settings-card settings-card--danger">
          <div class="settings-card__header">
            <h3>退出登录</h3>
            <span class="settings-card__meta">当前会话</span>
          </div>
          <p class="settings-hint">退出时会同时清理 Go core 会话与 WebSocket 连接。</p>
          <button type="button" class="settings-action settings-action--danger" @click="emit('logout')">退出登录</button>
        </article>
      </div>

      <aside class="settings-panel__side">
        <article class="settings-card">
          <div class="settings-card__header">
            <h3>宿主状态</h3>
            <span class="settings-card__meta">runtime</span>
          </div>
          <dl class="settings-detail-list">
            <div>
              <dt>Electron Host</dt>
              <dd>{{ props.hostVersion ?? "unknown" }}</dd>
            </div>
            <div>
              <dt>WebSocket</dt>
              <dd>{{ props.wsStatus }}</dd>
            </div>
            <div>
              <dt>最后事件</dt>
              <dd>{{ props.lastEvent }}</dd>
            </div>
            <div>
              <dt>Bootstrap</dt>
              <dd>{{ props.bootstrap?.connection.status ?? "unknown" }}</dd>
            </div>
          </dl>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>Feature Flags</h3>
            <span class="settings-card__meta">{{ featureFlags.length }} 项</span>
          </div>
          <div v-if="featureFlags.length" class="flag-list">
            <span
              v-for="[name, enabled] in featureFlags"
              :key="name"
              class="flag-pill"
              :class="{ 'flag-pill--enabled': enabled }"
            >
              {{ name }} / {{ enabled ? "on" : "off" }}
            </span>
          </div>
          <p v-else class="settings-hint">当前环境没有额外 Feature Flag。</p>
        </article>
      </aside>
    </div>

    <AgreementModal
      v-model:visible="agreementVisible"
      :title="agreementTitle"
      :html-content="agreementContent"
    />
  </section>
</template>

<style scoped>
.settings-panel {
  display: grid;
  gap: 18px;
}

.settings-panel__notice {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
  padding: 14px 16px;
  border-radius: 18px;
  font-size: 13px;
  line-height: 1.6;
}

.settings-panel__notice small {
  flex-shrink: 0;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.settings-panel__notice--neutral {
  background: rgba(0, 194, 179, 0.08);
  color: #0f766e;
}

.settings-panel__notice--success {
  background: rgba(22, 163, 74, 0.1);
  color: var(--success-color);
}

.settings-panel__notice--error {
  background: rgba(220, 38, 38, 0.1);
  color: var(--error-color);
}

.settings-panel__grid {
  display: grid;
  grid-template-columns: minmax(0, 1.25fr) minmax(280px, 0.75fr);
  gap: 18px;
}

.settings-panel__main,
.settings-panel__side {
  display: grid;
  gap: 18px;
}

.settings-card {
  padding: 22px;
  border: 1px solid var(--panel-border);
  border-radius: 26px;
  background: rgba(255, 255, 255, 0.88);
  box-shadow: var(--panel-shadow);
}

.settings-card--profile {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr) auto;
  gap: 18px;
  align-items: center;
}

.settings-avatar {
  display: grid;
  place-items: center;
  width: 92px;
  height: 92px;
  border-radius: 28px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-size: 34px;
  font-weight: 700;
  overflow: hidden;
}

.settings-avatar__image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.settings-card__copy {
  display: grid;
  gap: 6px;
}

.settings-card__copy h2 {
  margin: 0;
  font-size: 28px;
}

.settings-card__copy p,
.settings-card__copy span {
  margin: 0;
  color: var(--text-secondary);
}

.settings-card__tag {
  padding: 10px 14px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.05);
  color: var(--text-secondary);
  font-size: 12px;
}

.settings-card__tag--action {
  cursor: pointer;
}

.settings-card__tag:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.settings-profile-actions {
  display: grid;
  justify-items: end;
  align-content: start;
  gap: 10px;
}

.settings-avatar-input {
  display: none;
}

.settings-profile-actions__hint {
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.5;
  text-align: right;
}

.nickname-editor,
.password-editor {
  display: grid;
  gap: 10px;
  min-width: 220px;
}

.nickname-editor__input,
.password-editor__input {
  height: 40px;
  border: 1px solid rgba(0, 155, 143, 0.18);
  border-radius: 14px;
  padding: 0 14px;
  background: #f8fffe;
  outline: none;
}

.nickname-editor__input:focus,
.password-editor__input:focus {
  border-color: rgba(0, 155, 143, 0.34);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.08);
}

.nickname-editor__actions,
.password-editor__actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.nickname-editor__button,
.password-editor__button {
  height: 34px;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
  cursor: pointer;
}

.nickname-editor__button--primary,
.password-editor__button--primary {
  background: rgba(0, 194, 179, 0.12);
  color: var(--primary-color-strong);
}

.nickname-editor__button:disabled,
.password-editor__button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.feedback-editor {
  display: grid;
  gap: 12px;
}

.feedback-editor__textarea,
.feedback-editor__input {
  border: 1px solid rgba(0, 155, 143, 0.18);
  border-radius: 14px;
  background: #f8fffe;
  color: var(--text-primary);
  outline: none;
}

.feedback-editor__textarea {
  min-height: 140px;
  resize: vertical;
  padding: 12px 14px;
  font: inherit;
  line-height: 1.6;
}

.feedback-editor__input {
  height: 40px;
  padding: 0 14px;
}

.feedback-editor__textarea:focus,
.feedback-editor__input:focus {
  border-color: rgba(0, 155, 143, 0.34);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.08);
}

.feedback-editor__footer {
  display: flex;
  justify-content: flex-end;
}

.feedback-editor__count {
  color: var(--text-secondary);
  font-size: 12px;
}

.settings-card__header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
  margin-bottom: 16px;
}

.settings-card__header h3 {
  margin: 0;
  font-size: 18px;
}

.settings-card__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
}

.settings-card__meta {
  color: var(--text-secondary);
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.settings-detail-list {
  display: grid;
  gap: 14px;
  margin: 0;
}

.settings-detail-list div {
  display: grid;
  gap: 4px;
}

.settings-detail-list dt {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.settings-detail-list dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-all;
}

.settings-action {
  height: 40px;
  padding: 0 16px;
  border-radius: 999px;
  background: rgba(0, 194, 179, 0.12);
  color: var(--primary-color-strong);
  cursor: pointer;
}

.settings-action:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.settings-action--danger {
  background: rgba(220, 38, 38, 0.1);
  color: var(--error-color);
}

.settings-link-list {
  display: grid;
  gap: 12px;
}

.settings-link {
  display: grid;
  gap: 4px;
  padding: 14px 16px;
  border-radius: 20px;
  background: rgba(15, 23, 42, 0.04);
  text-align: left;
  cursor: pointer;
}

.settings-link strong {
  color: var(--text-primary);
  font-size: 15px;
}

.settings-link small,
.settings-hint {
  margin: 0;
  color: var(--text-secondary);
  line-height: 1.6;
}

.settings-card--danger {
  border-color: rgba(220, 38, 38, 0.12);
}

.flag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.flag-pill {
  padding: 10px 14px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.16);
  color: #334155;
  font-size: 14px;
}

.flag-pill--enabled {
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
}

@media (max-width: 980px) {
  .settings-panel__grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .settings-panel__notice {
    flex-direction: column;
    align-items: flex-start;
  }

  .settings-card--profile {
    grid-template-columns: 1fr;
    justify-items: start;
  }

  .settings-profile-actions {
    width: 100%;
    justify-items: stretch;
  }

  .nickname-editor,
  .password-editor {
    min-width: 0;
    width: 100%;
  }
}
</style>
