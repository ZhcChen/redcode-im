<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import { SettingsApi, type AppNameResponse, type DocumentContent, type GeneralSettingsResponse } from "@/api/settings";
import { VersionApi, type AppVersionInfo } from "@/api/version";
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
}>();

const generalSettings = ref<GeneralSettingsResponse | null>(null);
const appNameResponse = ref<AppNameResponse | null>(null);
const isCheckingUpdate = ref(false);
const latestVersion = ref<AppVersionInfo | null>(null);
const hasUpdate = ref(false);
const noticeTone = ref<NoticeTone>("neutral");
const noticeMessage = ref("设置页已切回真实业务面板，后续继续补资料编辑与下载更新。");
const agreementVisible = ref(false);
const agreementTitle = ref("文档");
const agreementContent = ref("");

const userDisplayName = computed(() => props.currentUser.nickname || props.currentUser.username || "用户");
const userInitial = computed(() => userDisplayName.value.slice(0, 1).toUpperCase());
const displayAppName = computed(
  () => generalSettings.value?.app_name || appNameResponse.value?.app_name || props.bootstrap?.config.app_name || "Chatly"
);
const currentVersion = computed(() => props.bootstrap?.config.version || "0.1.0");
const currentBuild = computed(() => props.bootstrap?.config.build_number || 0);
const currentChannel = computed(() => props.bootstrap?.config.channel || "stable");
const featureFlags = computed(() => Object.entries(props.bootstrap?.feature_flags ?? {}));

const setNotice = (tone: NoticeTone, message: string) => {
  noticeTone.value = tone;
  noticeMessage.value = message;
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
      setNotice("success", `发现新版本 v${response.data.version.version}，可继续接入下载与安装流程。`);
      return;
    }

    setNotice("success", "当前已经是最新版本。");
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "检查更新失败");
  } finally {
    isCheckingUpdate.value = false;
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
          <div class="settings-avatar">{{ userInitial }}</div>
          <div class="settings-card__copy">
            <h2>{{ userDisplayName }}</h2>
            <p>{{ props.currentUser.mobile }}</p>
            <span>{{ props.currentUser.email || "未绑定邮箱" }}</span>
          </div>
          <div class="settings-card__tag">资料编辑下一批接入</div>
        </article>

        <article class="settings-card">
          <div class="settings-card__header">
            <h3>桌面端版本</h3>
            <button type="button" class="settings-action" :disabled="isCheckingUpdate" @click="handleCheckUpdate">
              {{ isCheckingUpdate ? "检查中..." : "检查更新" }}
            </button>
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
          </dl>
          <p v-if="latestVersion?.release_notes" class="settings-hint">{{ latestVersion.release_notes }}</p>
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
}
</style>
