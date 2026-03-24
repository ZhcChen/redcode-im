<script setup lang="ts">
import { computed } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import type { HomeView } from "@/store/session";
import type { BootstrapSnapshot } from "@/types/bootstrap";
import SettingsPanel from "./SettingsPanel.vue";

const props = defineProps<{
  currentUser: LegacyUserInfo;
  hostVersion: string | null;
  lastEvent: string;
  wsStatus: string;
  bootstrap: BootstrapSnapshot | null;
  activeView: HomeView;
}>();

const emit = defineEmits<{
  (event: "navigate", view: HomeView): void;
  (event: "logout"): void;
  (event: "profile-updated", user: LegacyUserInfo): void;
}>();

const menuItems: Array<{ value: HomeView; title: string; shortLabel: string; desc: string }> = [
  { value: "chat", title: "聊天", shortLabel: "聊", desc: "会话与消息" },
  { value: "contact", title: "联系人", shortLabel: "联", desc: "好友与群组" },
  { value: "settings", title: "设置", shortLabel: "设", desc: "账号与系统" }
];

const userDisplayName = computed(() => props.currentUser.nickname || props.currentUser.username || "用户");
const userInitial = computed(() => userDisplayName.value.slice(0, 1).toUpperCase());
const featureFlags = computed(() => Object.entries(props.bootstrap?.feature_flags ?? {}));
const recentConversations = computed(() => props.bootstrap?.recent_conversations ?? []);
const pageTitle = computed(() => {
  switch (props.activeView) {
    case "chat":
      return "聊天";
    case "contact":
      return "联系人";
    case "settings":
      return "设置";
    default:
      return "工作台";
  }
});
const pageSummary = computed(() => {
  switch (props.activeView) {
    case "chat":
      return "沿用旧 desktop 的左导航 + 主内容布局，当前先接上最近会话与运行状态。";
    case "contact":
      return "联系人页先恢复信息架构和左右分栏，后续逐步接真实联系人与好友申请业务。";
    case "settings":
      return "设置页先承接账号、版本、连接状态，后续继续平移旧桌面的资料编辑与更新逻辑。";
    default:
      return "主壳迁移中。";
  }
});
</script>

<template>
  <main class="home-shell">
    <aside class="home-shell__sidebar">
      <button type="button" class="profile-card" @click="emit('navigate', 'settings')">
        <span class="profile-card__avatar">{{ userInitial }}</span>
        <span class="profile-card__name">{{ userDisplayName }}</span>
        <span class="profile-card__hint">{{ props.currentUser.mobile }}</span>
      </button>

      <nav class="home-shell__nav">
        <button
          v-for="item in menuItems"
          :key="item.value"
          type="button"
          class="nav-item"
          :class="{ 'nav-item--active': props.activeView === item.value }"
          @click="emit('navigate', item.value)"
        >
          <span class="nav-item__badge">{{ item.shortLabel }}</span>
          <span class="nav-item__copy">
            <strong>{{ item.title }}</strong>
            <small>{{ item.desc }}</small>
          </span>
        </button>
      </nav>

      <div class="home-shell__sidebar-footer">
        <button type="button" class="ghost-action" @click="emit('navigate', 'settings')">账号设置</button>
        <button type="button" class="ghost-action ghost-action--danger" @click="emit('logout')">退出登录</button>
      </div>
    </aside>

    <section class="home-shell__content">
      <header class="content-header">
        <div>
          <p class="content-header__eyebrow">desktop-el / Home shell</p>
          <h1>{{ pageTitle }}</h1>
          <p class="content-header__summary">{{ pageSummary }}</p>
        </div>
        <div class="status-cluster">
          <div class="status-pill">
            <span>WS</span>
            <strong>{{ props.wsStatus }}</strong>
          </div>
          <div class="status-pill">
            <span>Host</span>
            <strong>{{ props.hostVersion ?? "unknown" }}</strong>
          </div>
          <div class="status-pill">
            <span>Env</span>
            <strong>{{ props.bootstrap?.config.environment ?? "development" }}</strong>
          </div>
        </div>
      </header>

      <section v-if="props.activeView === 'chat'" class="content-grid content-grid--chat">
        <article class="panel panel--sidebar">
          <div class="panel__header">
            <h2>最近会话</h2>
            <span>{{ recentConversations.length }} 个</span>
          </div>
          <div v-if="recentConversations.length" class="conversation-list">
            <button
              v-for="conversation in recentConversations"
              :key="conversation.id"
              type="button"
              class="conversation-card"
            >
              <span class="conversation-card__avatar">{{ conversation.title.slice(0, 1) }}</span>
              <span class="conversation-card__copy">
                <strong>{{ conversation.title }}</strong>
                <small>ID {{ conversation.id }}</small>
              </span>
            </button>
          </div>
          <div v-else class="empty-state">
            <strong>暂无会话</strong>
            <p>旧 Chat 列表结构已经对齐到主壳，下一批开始挂真实会话数据。</p>
          </div>
        </article>

        <article class="panel panel--stage">
          <div class="panel__header">
            <h2>聊天主区域</h2>
            <span>迁移中</span>
          </div>
          <div class="hero-card">
            <strong>当前账号 {{ userDisplayName }}</strong>
            <p>这里会继续平移旧 `Chat.vue` 的消息区、会话头部和输入区域。</p>
          </div>
          <dl class="detail-list">
            <div>
              <dt>API</dt>
              <dd>{{ props.bootstrap?.config.api_base_url ?? "未同步" }}</dd>
            </div>
            <div>
              <dt>最后事件</dt>
              <dd>{{ props.lastEvent }}</dd>
            </div>
            <div>
              <dt>Bootstrap 连接</dt>
              <dd>{{ props.bootstrap?.connection.status ?? "unknown" }}</dd>
            </div>
          </dl>
        </article>
      </section>

      <section v-else-if="props.activeView === 'contact'" class="content-grid content-grid--contact">
        <article class="panel panel--sidebar">
          <div class="panel__header">
            <h2>固定入口</h2>
            <span>Contact</span>
          </div>
          <div class="shortcut-list">
            <button type="button" class="shortcut-card">
              <strong>新的朋友</strong>
              <small>好友申请与验证</small>
            </button>
            <button type="button" class="shortcut-card">
              <strong>群组</strong>
              <small>群聊与成员关系</small>
            </button>
          </div>
        </article>

        <article class="panel panel--stage">
          <div class="panel__header">
            <h2>联系人详情</h2>
            <span>待接业务</span>
          </div>
          <div class="hero-card">
            <strong>联系人页主框架已挂入 desktop-el</strong>
            <p>下一步会把旧联系人列表、好友申请面板和详情区分批平移过来。</p>
          </div>
          <dl class="detail-list">
            <div>
              <dt>当前用户</dt>
              <dd>{{ props.currentUser.username }}</dd>
            </div>
            <div>
              <dt>账号数</dt>
              <dd>{{ props.bootstrap?.accounts.length ?? 0 }}</dd>
            </div>
            <div>
              <dt>Feature Flags</dt>
              <dd>{{ featureFlags.length }}</dd>
            </div>
          </dl>
        </article>
      </section>

      <SettingsPanel
        v-else
        :current-user="props.currentUser"
        :bootstrap="props.bootstrap"
        :host-version="props.hostVersion"
        :ws-status="props.wsStatus"
        :last-event="props.lastEvent"
        @profile-updated="emit('profile-updated', $event)"
        @logout="emit('logout')"
      />
    </section>
  </main>
</template>

<style scoped>
.home-shell {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(0, 194, 179, 0.14), transparent 26%),
    radial-gradient(circle at right top, rgba(15, 23, 42, 0.08), transparent 24%),
    linear-gradient(180deg, #effcf9 0%, #f8fafc 100%);
}

.home-shell__sidebar {
  display: flex;
  flex-direction: column;
  gap: 24px;
  padding: 24px 20px;
  border-right: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.86);
  backdrop-filter: blur(16px);
}

.profile-card {
  display: grid;
  justify-items: start;
  gap: 10px;
  padding: 18px;
  border: 1px solid rgba(0, 155, 143, 0.12);
  border-radius: 24px;
  background: linear-gradient(180deg, rgba(0, 194, 179, 0.08), rgba(255, 255, 255, 0.96));
  text-align: left;
  cursor: pointer;
}

.profile-card__avatar {
  display: grid;
  place-items: center;
  width: 52px;
  height: 52px;
  border-radius: 18px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-size: 22px;
  font-weight: 700;
}

.profile-card__name {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
}

.profile-card__hint {
  color: var(--text-secondary);
  font-size: 13px;
}

.home-shell__nav {
  display: grid;
  gap: 10px;
}

.nav-item {
  display: grid;
  grid-template-columns: 46px minmax(0, 1fr);
  gap: 14px;
  align-items: center;
  padding: 14px;
  border: 1px solid transparent;
  border-radius: 20px;
  text-align: left;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.nav-item:hover {
  transform: translateX(2px);
  border-color: rgba(0, 155, 143, 0.12);
  background: rgba(255, 255, 255, 0.8);
}

.nav-item--active {
  border-color: rgba(0, 155, 143, 0.18);
  background: rgba(0, 194, 179, 0.1);
}

.nav-item__badge {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  border-radius: 16px;
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-primary);
  font-size: 18px;
  font-weight: 700;
}

.nav-item--active .nav-item__badge {
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
}

.nav-item__copy {
  display: grid;
  gap: 4px;
}

.nav-item__copy strong {
  font-size: 16px;
  color: var(--text-primary);
}

.nav-item__copy small {
  color: var(--text-secondary);
  font-size: 12px;
}

.home-shell__sidebar-footer {
  display: grid;
  gap: 10px;
  margin-top: auto;
}

.ghost-action {
  height: 42px;
  border-radius: 18px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
  cursor: pointer;
}

.ghost-action--danger {
  background: rgba(220, 38, 38, 0.08);
  color: var(--error-color);
}

.home-shell__content {
  padding: 28px;
}

.content-header {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  align-items: flex-start;
  margin-bottom: 24px;
}

.content-header__eyebrow {
  margin: 0 0 10px;
  font-size: 12px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.content-header h1 {
  margin: 0;
  font-size: clamp(32px, 5vw, 46px);
}

.content-header__summary {
  max-width: 720px;
  margin: 14px 0 0;
  color: var(--text-secondary);
  line-height: 1.7;
}

.status-cluster {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.status-pill {
  display: grid;
  gap: 6px;
  min-width: 110px;
  padding: 12px 14px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.88);
  box-shadow: var(--panel-shadow);
}

.status-pill span {
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.status-pill strong {
  color: var(--text-primary);
}

.content-grid {
  display: grid;
  gap: 18px;
}

.content-grid--chat,
.content-grid--contact {
  grid-template-columns: minmax(280px, 360px) minmax(0, 1fr);
}

.content-grid--settings {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.panel {
  padding: 22px;
  border: 1px solid var(--panel-border);
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.86);
  box-shadow: var(--panel-shadow);
  backdrop-filter: blur(12px);
}

.panel--wide {
  grid-column: 1 / -1;
}

.panel__header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
  margin-bottom: 18px;
}

.panel__header h2 {
  margin: 0;
  font-size: 18px;
}

.panel__header span {
  color: var(--text-secondary);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.conversation-list,
.shortcut-list {
  display: grid;
  gap: 12px;
}

.conversation-card,
.shortcut-card {
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
  padding: 14px;
  border-radius: 20px;
  background: rgba(15, 23, 42, 0.04);
  text-align: left;
  cursor: pointer;
}

.shortcut-card {
  grid-template-columns: 1fr;
}

.conversation-card__avatar {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 16px;
  background: rgba(0, 194, 179, 0.12);
  color: var(--primary-color-strong);
  font-weight: 700;
}

.conversation-card__copy,
.shortcut-card {
  display: grid;
  gap: 4px;
}

.conversation-card__copy strong,
.shortcut-card strong {
  color: var(--text-primary);
  font-size: 15px;
}

.conversation-card__copy small,
.shortcut-card small {
  color: var(--text-secondary);
}

.hero-card {
  display: grid;
  gap: 8px;
  padding: 18px 20px;
  border-radius: 22px;
  background:
    radial-gradient(circle at top right, rgba(0, 194, 179, 0.16), transparent 26%),
    rgba(15, 23, 42, 0.03);
  margin-bottom: 18px;
}

.hero-card strong {
  font-size: 18px;
  color: var(--text-primary);
}

.hero-card p {
  margin: 0;
  color: var(--text-secondary);
  line-height: 1.7;
}

.detail-list {
  display: grid;
  gap: 14px;
  margin: 0;
}

.detail-list div {
  display: grid;
  gap: 4px;
}

.detail-list dt {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.detail-list dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-all;
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

.empty-state {
  display: grid;
  gap: 8px;
  padding: 18px;
  border-radius: 22px;
  background: rgba(15, 23, 42, 0.04);
}

.empty-state strong {
  color: var(--text-primary);
}

.empty-state p {
  margin: 0;
  color: var(--text-secondary);
  line-height: 1.7;
}

@media (max-width: 980px) {
  .home-shell {
    grid-template-columns: 1fr;
  }

  .home-shell__sidebar {
    border-right: none;
    border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  }

  .content-grid--chat,
  .content-grid--contact,
  .content-grid--settings {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .home-shell__content {
    padding: 18px 14px 24px;
  }

  .content-header {
    flex-direction: column;
  }

  .status-cluster {
    width: 100%;
  }

  .status-pill {
    flex: 1;
  }
}
</style>
