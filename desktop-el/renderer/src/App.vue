<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import type { RpcEvent } from "../../electron/preload/types.js";
import { getRuntimeConfig } from "./api/config";
import type { ChatWebSocketPush } from "./api/chat";
import { SystemApi, type LegacyUserInfo } from "./api/system";
import LoginScreen from "./components/LoginScreen.vue";
import HomeShell from "./components/HomeShell.vue";
import { useSessionStore, type SessionAccount } from "./store/session";
import type { BootstrapSnapshot } from "./types/bootstrap";
import { WebSocketApi } from "./api/websocket";
import { buildDesktopWindowTitle } from "./utils/desktop-window-title";
import { buildLogoutFallbackPlan, buildSwitchAccountPlan } from "./utils/session-account-switch";

const bootstrap = ref<BootstrapSnapshot | null>(null);
const hostVersion = ref<string | null>(null);
const lastEvent = ref("尚未收到事件");
const runtimeAvailable = ref(false);
const wsStatus = ref("disconnected");
const lastWsPush = ref<ChatWebSocketPush | null>(null);
const sessionStore = useSessionStore();
if (typeof window !== "undefined" && window.desktopEl) {
  sessionStore.restorePersistedState();
}

let cleanupEventListener: (() => void) | undefined;

const appName = computed(() => bootstrap.value?.config.app_name || "CHATLY");
const accounts = computed(() => sessionStore.state.accounts);
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

const reconnectAccountSession = async (account: SessionAccount) => {
  if (!account.accessToken) {
    throw new Error(`account ${account.id} has no access token`);
  }

  lastWsPush.value = null;
  await WebSocketApi.disconnect().catch(() => undefined);
  await WebSocketApi.connect({ userId: account.user.id, token: account.accessToken });
  wsStatus.value = await WebSocketApi.getStatus();
};

const restorePersistedSession = async () => {
  if (!window.desktopEl || bootstrap.value?.auth.logged_in || sessionStore.state.accounts.length === 0) {
    return;
  }

  const currentAccount = sessionStore.getCurrentAccount();
  if (!currentAccount?.accessToken) {
    return;
  }

  try {
    await SystemApi.restoreAccounts({
      currentAccountId: sessionStore.state.currentAccountId,
      accounts: sessionStore.state.accounts.map((account) => ({
        id: account.id,
        accessToken: account.accessToken,
        refreshToken: account.refreshToken,
        userInfo: account.user,
      })),
    });
    await reconnectAccountSession(currentAccount);
    await refreshBootstrap();
  } catch (error) {
    sessionStore.clear();
    wsStatus.value = "disconnected";
    console.warn("[desktop-el-renderer] failed to restore persisted accounts", error);
    await refreshBootstrap().catch(() => undefined);
  }
};

const loadRuntimeState = async () => {
  if (!window.desktopEl) {
    runtimeAvailable.value = false;
    return;
  }

  runtimeAvailable.value = true;
  hostVersion.value = await window.desktopEl.app.getVersion();
  await refreshBootstrap();
  await restorePersistedSession();
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

const handleLoginSuccess = async (payload: { token: string; refreshToken?: string | null; user: LegacyUserInfo }) => {
  sessionStore.setAuthenticated(payload.user, payload.token, payload.refreshToken ?? null);
  const currentAccount = sessionStore.getCurrentAccount();
  if (!currentAccount) {
    return;
  }

  try {
    await reconnectAccountSession(currentAccount);
    await refreshBootstrap();
  } catch (error) {
    wsStatus.value = "disconnected";
    console.warn("[desktop-el-renderer] websocket connect failed", error);
  }
};

const handleSwitchAccount = async (accountId: string) => {
  const plan = buildSwitchAccountPlan(sessionStore.state.accounts, sessionStore.state.currentAccountId, accountId);
  if (!plan) {
    return;
  }

  try {
    await SystemApi.switchAccount(plan.nextAccount.id);
    sessionStore.switchAccount(plan.nextAccount.id);
    await reconnectAccountSession(plan.nextAccount);
    await refreshBootstrap();
  } catch (error) {
    wsStatus.value = "disconnected";
    console.warn("[desktop-el-renderer] switch account failed", error);
    await refreshBootstrap().catch(() => undefined);
  }
};

const handleLogout = async () => {
  const fallbackPlan = buildLogoutFallbackPlan(sessionStore.state.accounts, sessionStore.state.currentAccountId);
  const currentAccountId = sessionStore.state.currentAccountId;

  try {
    await SystemApi.logout();
  } catch (error) {
    console.warn("[desktop-el-renderer] logout failed", error);
    return;
  }

  if (currentAccountId) {
    sessionStore.removeAccount(currentAccountId);
  } else {
    sessionStore.clear();
  }

  if (fallbackPlan?.nextAccount) {
    try {
      await reconnectAccountSession(fallbackPlan.nextAccount);
      await refreshBootstrap();
      return;
    } catch (error) {
      wsStatus.value = "disconnected";
      console.warn("[desktop-el-renderer] websocket reconnect after logout failed", error);
    }
  }

  sessionStore.clear();
  wsStatus.value = "disconnected";
  await refreshBootstrap().catch((error) => {
    console.warn("[desktop-el-renderer] bootstrap refresh after logout failed", error);
  });
};

const handleProfileUpdated = async (user: LegacyUserInfo) => {
  sessionStore.updateCurrentUser(user);
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
    :accounts="accounts"
    :current-account-id="sessionStore.state.currentAccountId"
    :current-chat-group-id="sessionStore.state.currentChatGroupId"
    :current-contact-page-state="sessionStore.state.currentContactPageState"
    :current-settings-page-state="sessionStore.state.currentSettingsPageState"
    :host-version="hostVersion"
    :last-event="lastEvent"
    :ws-status="wsStatus"
    :bootstrap="bootstrap"
    :last-ws-push="lastWsPush"
    :active-view="sessionStore.state.activeView"
    @navigate="sessionStore.setActiveView"
    @selected-chat-change="sessionStore.setCurrentChatGroupId"
    @contact-page-state-change="sessionStore.setCurrentContactPageState"
    @settings-page-state-change="sessionStore.setCurrentSettingsPageState"
    @switch-account="handleSwitchAccount"
    @profile-updated="handleProfileUpdated"
    @logout="handleLogout"
  />
</template>
