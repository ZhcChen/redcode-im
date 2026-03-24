import { reactive } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import type { BootstrapSnapshot } from "@/types/bootstrap";
import { mapBootstrapUserToLegacy } from "@/types/bootstrap";

export type HomeView = "chat" | "contact" | "settings";

interface SessionState {
  currentUser: LegacyUserInfo | null;
  activeView: HomeView;
  accessToken: string | null;
}

const ACTIVE_VIEW_KEY = "desktop-el.active-view";

const loadInitialView = (): HomeView => {
  try {
    const value = window.localStorage.getItem(ACTIVE_VIEW_KEY);
    if (value === "chat" || value === "contact" || value === "settings") {
      return value;
    }
  } catch {
    // Ignore browser storage failures.
  }
  return "chat";
};

const persistActiveView = (view: HomeView) => {
  try {
    window.localStorage.setItem(ACTIVE_VIEW_KEY, view);
  } catch {
    // Ignore browser storage failures.
  }
};

const state = reactive<SessionState>({
  currentUser: null,
  activeView: loadInitialView(),
  accessToken: null
});

export const useSessionStore = () => {
  const setActiveView = (view: HomeView) => {
    state.activeView = view;
    persistActiveView(view);
  };

  const setAuthenticated = (user: LegacyUserInfo, accessToken?: string | null) => {
    state.currentUser = user;
    state.accessToken = accessToken ?? null;
  };

  const hydrateFromBootstrap = (snapshot: BootstrapSnapshot | null) => {
    if (!snapshot?.auth.logged_in || !snapshot.auth.current_user) {
      state.currentUser = null;
      state.accessToken = null;
      return;
    }

    state.currentUser = mapBootstrapUserToLegacy(snapshot.auth.current_user);
  };

  const clear = () => {
    state.currentUser = null;
    state.accessToken = null;
    setActiveView("chat");
  };

  return {
    state,
    setActiveView,
    setAuthenticated,
    hydrateFromBootstrap,
    clear
  };
};
