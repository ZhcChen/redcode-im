<script setup lang="ts">
import { computed } from "vue";
import type { LegacyUserInfo } from "@/api/system";

interface BootstrapSnapshot {
  accounts: Array<{ id: string; display_name: string }>;
  config: {
    app_name: string;
    environment: string;
    api_base_url?: string;
    ws_url?: string;
    version?: string;
    build_number?: number;
    channel?: string;
  };
  recent_conversations: Array<{ id: string; title: string }>;
  connection: {
    status: string;
  };
  feature_flags: Record<string, boolean>;
}

const props = defineProps<{
  currentUser: LegacyUserInfo;
  hostVersion: string | null;
  lastEvent: string;
  wsStatus: string;
  bootstrap: BootstrapSnapshot | null;
}>();

const emit = defineEmits<{
  (event: "logout"): void;
}>();

const featureFlags = computed(() => Object.entries(props.bootstrap?.feature_flags ?? {}));
</script>

<template>
  <main class="workspace-shell">
    <section class="workspace-shell__hero">
      <div>
        <p class="workspace-shell__eyebrow">desktop-el / auth bridged</p>
        <h1>登录入口已经挂到 Go core</h1>
        <p class="workspace-shell__summary">
          这一屏先作为迁移中的工作台，展示当前账号、宿主状态和 Go core bootstrap 信息。后续会继续把旧
          `Home / Chat / Contact` UI 原样平移进来。
        </p>
      </div>
      <button type="button" class="workspace-shell__logout" @click="emit('logout')">退出当前会话</button>
    </section>

    <section class="workspace-shell__grid">
      <article class="panel">
        <h2>当前账号</h2>
        <dl class="facts">
          <div>
            <dt>昵称</dt>
            <dd>{{ props.currentUser.nickname }}</dd>
          </div>
          <div>
            <dt>账号</dt>
            <dd>{{ props.currentUser.username }}</dd>
          </div>
          <div>
            <dt>手机号</dt>
            <dd>{{ props.currentUser.mobile }}</dd>
          </div>
          <div>
            <dt>邮箱</dt>
            <dd>{{ props.currentUser.email || "未设置" }}</dd>
          </div>
        </dl>
      </article>

      <article class="panel">
        <h2>宿主状态</h2>
        <dl class="facts">
          <div>
            <dt>Electron 版本</dt>
            <dd>{{ props.hostVersion ?? "未获取" }}</dd>
          </div>
          <div>
            <dt>最后事件</dt>
            <dd>{{ props.lastEvent }}</dd>
          </div>
          <div>
            <dt>WebSocket</dt>
            <dd>{{ props.wsStatus }}</dd>
          </div>
          <div>
            <dt>Bootstrap 连接</dt>
            <dd>{{ props.bootstrap?.connection.status ?? "unknown" }}</dd>
          </div>
        </dl>
      </article>

      <article class="panel">
        <h2>运行配置</h2>
        <dl class="facts">
          <div>
            <dt>应用名</dt>
            <dd>{{ props.bootstrap?.config.app_name ?? "RedCode IM" }}</dd>
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

      <article class="panel panel--wide">
        <h2>Feature Flags</h2>
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
        <p v-else class="empty">还没有收到 feature flags。</p>
      </article>
    </section>
  </main>
</template>

<style scoped>
.workspace-shell {
  min-height: 100vh;
  padding: 40px;
  background:
    radial-gradient(circle at top left, rgba(0, 194, 179, 0.18), transparent 28%),
    radial-gradient(circle at right center, rgba(253, 224, 71, 0.18), transparent 24%),
    linear-gradient(180deg, #f2fffd 0%, #f8fafc 100%);
}

.workspace-shell__hero {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  align-items: flex-start;
  margin-bottom: 28px;
}

.workspace-shell__eyebrow {
  margin: 0 0 12px;
  font-size: 12px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.workspace-shell__hero h1 {
  margin: 0;
  font-size: clamp(34px, 5vw, 54px);
  line-height: 1.04;
}

.workspace-shell__summary {
  max-width: 720px;
  margin: 16px 0 0;
  color: var(--text-secondary);
  line-height: 1.7;
}

.workspace-shell__logout {
  flex-shrink: 0;
  height: 44px;
  padding: 0 18px;
  border-radius: 999px;
  background: #0f172a;
  color: #ffffff;
  cursor: pointer;
}

.workspace-shell__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.panel {
  padding: 22px;
  border: 1px solid var(--panel-border);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.82);
  box-shadow: var(--panel-shadow);
  backdrop-filter: blur(10px);
}

.panel--wide {
  grid-column: 1 / -1;
}

.panel h2 {
  margin: 0 0 16px;
  font-size: 18px;
}

.facts {
  display: grid;
  gap: 14px;
  margin: 0;
}

.facts div {
  display: grid;
  gap: 4px;
}

dt {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

dd {
  margin: 0;
  font-size: 16px;
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
  background: rgba(148, 163, 184, 0.18);
  color: #334155;
  font-size: 14px;
}

.flag-pill--enabled {
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
}

.empty {
  margin: 0;
  color: var(--text-secondary);
}

@media (max-width: 900px) {
  .workspace-shell {
    padding: 24px;
  }

  .workspace-shell__hero {
    flex-direction: column;
  }

  .workspace-shell__grid {
    grid-template-columns: 1fr;
  }

  .panel--wide {
    grid-column: auto;
  }
}
</style>
