<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import type { RpcEvent } from "../../electron/preload/types.js";

interface BootstrapSnapshot {
  accounts: Array<{ id: string; display_name: string }>;
  config: {
    app_name: string;
    environment: string;
  };
  recent_conversations: Array<{ id: string; title: string }>;
  connection: {
    status: string;
  };
  feature_flags: Record<string, boolean>;
}

const bootstrap = ref<BootstrapSnapshot | null>(null);
const status = ref("等待 Electron 宿主连接");
const hostVersion = ref<string | null>(null);
const lastEvent = ref<string>("尚未收到事件");

let cleanupEventListener: (() => void) | undefined;

const featureFlags = computed(() => {
  return Object.entries(bootstrap.value?.feature_flags ?? {});
});

const loadSnapshot = async () => {
  if (!window.desktopEl) {
    status.value = "当前仅运行在浏览器预览环境，尚未连接 Electron。";
    return;
  }

  status.value = "正在从 Go core 拉取 bootstrap snapshot";
  hostVersion.value = await window.desktopEl.app.getVersion();
  bootstrap.value = await window.desktopEl.rpc.invoke<BootstrapSnapshot>("core.bootstrap.get");
  status.value = "bootstrap snapshot 已同步";
  console.info("[desktop-el-renderer] bootstrap snapshot loaded");
};

onMounted(() => {
  if (!window.desktopEl) {
    status.value = "当前仅运行在浏览器预览环境，尚未连接 Electron。";
    return;
  }

  cleanupEventListener = window.desktopEl.rpc.onEvent((event: RpcEvent) => {
    lastEvent.value = event.event;
    if (event.event === "core.bootstrap.snapshot" && event.data) {
      bootstrap.value = event.data as BootstrapSnapshot;
      status.value = "已收到 Go core 推送的 bootstrap snapshot";
      console.info("[desktop-el-renderer] bootstrap snapshot event received");
    }
  });

  void loadSnapshot().catch((error) => {
    status.value = error instanceof Error ? error.message : String(error);
  });
});

onUnmounted(() => {
  cleanupEventListener?.();
});
</script>

<template>
  <main class="app-shell">
    <section class="hero">
      <p class="eyebrow">desktop-el / Electron + Go core</p>
      <h1>Bootstrap Snapshot 已接通</h1>
      <p class="summary">
        当前 Renderer 已通过 preload 受控桥接连接到 Go core，后续迁移会在这个状态入口上逐步接管旧
        Tauri 业务。
      </p>
    </section>

    <section class="grid">
      <article class="panel">
        <h2>宿主状态</h2>
        <dl class="facts">
          <div>
            <dt>同步状态</dt>
            <dd>{{ status }}</dd>
          </div>
          <div>
            <dt>宿主版本</dt>
            <dd>{{ hostVersion ?? "未获取" }}</dd>
          </div>
          <div>
            <dt>最后事件</dt>
            <dd>{{ lastEvent }}</dd>
          </div>
          <div>
            <dt>连接状态</dt>
            <dd>{{ bootstrap?.connection.status ?? "unknown" }}</dd>
          </div>
        </dl>
      </article>

      <article class="panel">
        <h2>应用配置</h2>
        <dl class="facts">
          <div>
            <dt>应用名</dt>
            <dd>{{ bootstrap?.config.app_name ?? "RedCode IM" }}</dd>
          </div>
          <div>
            <dt>环境</dt>
            <dd>{{ bootstrap?.config.environment ?? "development" }}</dd>
          </div>
          <div>
            <dt>账号数</dt>
            <dd>{{ bootstrap?.accounts.length ?? 0 }}</dd>
          </div>
          <div>
            <dt>最近会话</dt>
            <dd>{{ bootstrap?.recent_conversations.length ?? 0 }}</dd>
          </div>
        </dl>
      </article>

      <article class="panel panel-wide">
        <h2>Feature Flags</h2>
        <div v-if="featureFlags.length > 0" class="flags">
          <span
            v-for="[name, enabled] in featureFlags"
            :key="name"
            class="flag"
            :class="{ 'flag--enabled': enabled }"
          >
            {{ name }} / {{ enabled ? "on" : "off" }}
          </span>
        </div>
        <p v-else class="empty">尚未收到 feature flags。</p>
      </article>
    </section>
  </main>
</template>

<style scoped>
.app-shell {
  min-height: 100vh;
  padding: 48px;
  color: #14213d;
  background:
    radial-gradient(circle at top left, rgba(251, 191, 36, 0.28), transparent 28%),
    radial-gradient(circle at right center, rgba(59, 130, 246, 0.18), transparent 26%),
    linear-gradient(160deg, #f8fafc 0%, #eef6ff 45%, #f5f5f4 100%);
  font-family: "PingFang SC", "Noto Sans SC", sans-serif;
}

.hero {
  max-width: 760px;
  margin-bottom: 28px;
}

.eyebrow {
  margin: 0 0 12px;
  font-size: 13px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: #b45309;
}

h1 {
  margin: 0;
  font-size: clamp(34px, 5vw, 56px);
  line-height: 1.05;
}

.summary {
  max-width: 640px;
  margin: 16px 0 0;
  font-size: 16px;
  line-height: 1.7;
  color: #334155;
}

.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.panel {
  padding: 22px;
  border: 1px solid rgba(148, 163, 184, 0.24);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(12px);
  box-shadow: 0 18px 48px rgba(15, 23, 42, 0.08);
}

.panel-wide {
  grid-column: 1 / -1;
}

h2 {
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
  color: #64748b;
}

dd {
  margin: 0;
  font-size: 16px;
  color: #0f172a;
}

.flags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.flag {
  padding: 10px 14px;
  border-radius: 999px;
  background: #e2e8f0;
  color: #334155;
  font-size: 14px;
}

.flag--enabled {
  background: #d1fae5;
  color: #166534;
}

.empty {
  margin: 0;
  color: #64748b;
}

@media (max-width: 900px) {
  .app-shell {
    padding: 24px;
  }

  .grid {
    grid-template-columns: 1fr;
  }

  .panel-wide {
    grid-column: auto;
  }
}
</style>
