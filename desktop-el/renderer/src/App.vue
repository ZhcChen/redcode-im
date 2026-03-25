<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import type { RpcEvent } from "../../electron/preload/types.js";
import { getRuntimeConfig } from "./api/config";
import type { ChatWebSocketPush } from "./api/chat";
import { SystemApi, type LegacyUserInfo } from "./api/system";
import LoginScreen from "./components/LoginScreen.vue";
import HomeShell from "./components/HomeShell.vue";
import { useSessionStore } from "./store/session";
import type { BootstrapSnapshot } from "./types/bootstrap";
import { WebSocketApi } from "./api/websocket";
import { buildDesktopWindowTitle } from "./utils/desktop-window-title";

const bootstrap = ref<BootstrapSnapshot | null>(null);
const hostVersion = ref<string | null>(null);
const lastEvent = ref("尚未收到事件");
const runtimeAvailable = ref(false);
const wsStatus = ref("disconnected");
const lastWsPush = ref<ChatWebSocketPush | null>(null);
const sessionStore = useSessionStore();

let cleanupEventListener: (() => void) | undefined;

const appName = computed(() => bootstrap.value?.config.app_name || "CHATLY");
const currentUser = computed<LegacyUserInfo | null>(() => sessionStore.state.currentUser);

const syncWindowTitle = async () => {
  if (!window.desktopEl) {
    return;
  }

  const title = buildDesktopWindowTitle(appName.value, currentUser.value);
  await window.desktopEl.window.setTitle(title);
};

const syncBootstrapState = (snapshot: BootstrapSnapshot | null) => {
  if (!snapshot) {
    return;
  }

  sessionStore.hydrateFromBootstrap(snapshot);
  wsStatus.value = snapshot.connection.status || "disconnected";
};

const refreshBootstrap = async () => {
  if (!window.desktopEl) {
    return;
  }

  bootstrap.value = await window.desktopEl.rpc.invoke<BootstrapSnapshot>("core.bootstrap.get");
  syncBootstrapState(bootstrap.value);
};

const loadRuntimeState = async () => {
  if (!window.desktopEl) {
    runtimeAvailable.value = false;
    return;
  }

  runtimeAvailable.value = true;
  hostVersion.value = await window.desktopEl.app.getVersion();
  await refreshBootstrap();
  await getRuntimeConfig();
};

const handleRpcEvent = (event: RpcEvent) => {
  lastEvent.value = event.event;

  if (event.event === "core.bootstrap.snapshot" && event.data) {
    bootstrap.value = event.data as BootstrapSnapshot;
    syncBootstrapState(bootstrap.value);
  }

  if (event.event === "ws.status.updated" && event.data) {
    const data = event.data as { status?: string };
    if (data.status) {
      wsStatus.value = data.status;
    }
  }

  if (event.event === "ws.push") {
    lastWsPush.value = (event.data as ChatWebSocketPush | null) ?? null;
  }
};

const handleLoginSuccess = async (payload: { token: string; user: LegacyUserInfo }) => {
  sessionStore.setAuthenticated(payload.user, payload.token);

  if (!window.desktopEl) {
    return;
  }

  try {
    await WebSocketApi.connect({ userId: payload.user.id, token: payload.token });
    wsStatus.value = await WebSocketApi.getStatus();
    await refreshBootstrap();
  } catch (error) {
    wsStatus.value = "disconnected";
    console.warn("[desktop-el-renderer] websocket connect failed", error);
  }
};

const handleLogout = async () => {
  try {
    await SystemApi.logout();
  } catch (error) {
    console.warn("[desktop-el-renderer] logout failed", error);
  }

  sessionStore.clear();
  wsStatus.value = "disconnected";
  await refreshBootstrap().catch((error) => {
    console.warn("[desktop-el-renderer] bootstrap refresh after logout failed", error);
  });
};

const handleProfileUpdated = async (user: LegacyUserInfo) => {
  sessionStore.setAuthenticated(user, sessionStore.state.accessToken);
  await refreshBootstrap().catch((error) => {
    console.warn("[desktop-el-renderer] bootstrap refresh after profile update failed", error);
  });
};

onMounted(() => {
  if (!window.desktopEl) {
    runtimeAvailable.value = false;
    return;
  }

  cleanupEventListener = window.desktopEl.rpc.onEvent(handleRpcEvent);

  void loadRuntimeState().catch((error) => {
    runtimeAvailable.value = false;
    console.warn("[desktop-el-renderer] failed to load runtime state", error);
  });
});

onUnmounted(() => {
  cleanupEventListener?.();
});

watch(
  [appName, currentUser],
  () => {
    if (!runtimeAvailable.value || !window.desktopEl) {
      return;
    }

    void syncWindowTitle().catch((error) => {
      console.warn("[desktop-el-renderer] failed to sync window title", error);
    });
  },
  { immediate: true },
);
</script>

<template>
  <LoginScreen
    v-if="!currentUser"
    :app-name="appName"
    :host-version="hostVersion"
    :runtime-available="runtimeAvailable"
    @login-success="handleLoginSuccess"
  />
  <HomeShell
    v-else
    :current-user="currentUser"
    :host-version="hostVersion"
    :last-event="lastEvent"
    :ws-status="wsStatus"
    :bootstrap="bootstrap"
    :last-ws-push="lastWsPush"
    :active-view="sessionStore.state.activeView"
    @navigate="sessionStore.setActiveView"
    @profile-updated="handleProfileUpdated"
    @logout="handleLogout"
  />
</template>
