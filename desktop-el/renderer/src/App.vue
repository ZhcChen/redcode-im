<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import type { RpcEvent } from "../../electron/preload/types.js";
import LoginScreen from "./components/LoginScreen.vue";
import WorkspaceShell from "./components/WorkspaceShell.vue";
import { getRuntimeConfig } from "./api/config";
import type { LegacyUserInfo } from "./api/system";
import { WebSocketApi } from "./api/websocket";

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

const bootstrap = ref<BootstrapSnapshot | null>(null);
const hostVersion = ref<string | null>(null);
const lastEvent = ref("尚未收到事件");
const runtimeAvailable = ref(false);
const currentUser = ref<LegacyUserInfo | null>(null);
const wsStatus = ref("disconnected");

let cleanupEventListener: (() => void) | undefined;

const appName = computed(() => bootstrap.value?.config.app_name || "CHATLY");

const loadRuntimeState = async () => {
  if (!window.desktopEl) {
    runtimeAvailable.value = false;
    return;
  }

  runtimeAvailable.value = true;
  hostVersion.value = await window.desktopEl.app.getVersion();
  bootstrap.value = await window.desktopEl.rpc.invoke<BootstrapSnapshot>("core.bootstrap.get");
  await getRuntimeConfig();
};

const handleRpcEvent = (event: RpcEvent) => {
  lastEvent.value = event.event;

  if (event.event === "core.bootstrap.snapshot" && event.data) {
    bootstrap.value = event.data as BootstrapSnapshot;
  }

  if (event.event === "ws.status.updated" && event.data) {
    const data = event.data as { status?: string };
    if (data.status) {
      wsStatus.value = data.status;
    }
  }
};

const handleLoginSuccess = async (payload: { token: string; user: LegacyUserInfo }) => {
  currentUser.value = payload.user;

  if (!window.desktopEl) {
    return;
  }

  try {
    await WebSocketApi.connect({ userId: payload.user.id, token: payload.token });
    wsStatus.value = await WebSocketApi.getStatus();
  } catch (error) {
    wsStatus.value = "disconnected";
    console.warn("[desktop-el-renderer] websocket connect failed", error);
  }
};

const handleLogout = async () => {
  try {
    await WebSocketApi.disconnect();
  } catch (error) {
    console.warn("[desktop-el-renderer] websocket disconnect failed", error);
  }

  currentUser.value = null;
  wsStatus.value = "disconnected";
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
</script>

<template>
  <LoginScreen
    v-if="!currentUser"
    :app-name="appName"
    :host-version="hostVersion"
    :runtime-available="runtimeAvailable"
    @login-success="handleLoginSuccess"
  />
  <WorkspaceShell
    v-else
    :current-user="currentUser"
    :host-version="hostVersion"
    :last-event="lastEvent"
    :ws-status="wsStatus"
    :bootstrap="bootstrap"
    @logout="handleLogout"
  />
</template>
