import { reactive } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import type { BootstrapSnapshot } from "@/types/bootstrap";
import { mapBootstrapUserToLegacy } from "@/types/bootstrap";

export type HomeView = "chat" | "contact" | "settings";
export type SessionRouteName = "Chat" | "Contact" | "Settings";

export interface SessionRouteState {
  path: string;
  name: SessionRouteName;
  params: Record<string, string>;
  query: Record<string, string>;
}

export interface SessionPageState {
  currentChatGroupId: string | null;
}

export interface SessionAccount {
  id: string;
  displayName: string;
  user: LegacyUserInfo;
  accessToken: string | null;
  refreshToken: string | null;
  activeView: HomeView;
  routeState: SessionRouteState;
  pageState: SessionPageState;
}

interface PersistedSessionState {
  accounts: SessionAccount[];
  currentAccountId: string | null;
}

interface SessionState {
  accounts: SessionAccount[];
  currentAccountId: string | null;
  currentUser: LegacyUserInfo | null;
  activeView: HomeView;
  accessToken: string | null;
  refreshToken: string | null;
  currentChatGroupId: string | null;
}

type StorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

export const SESSION_STORAGE_KEY = "desktop-el.session-state";
const DEFAULT_HOME_VIEW: HomeView = "chat";

const isHomeView = (value: string): value is HomeView =>
  value === "chat" || value === "contact" || value === "settings";

const getDefaultStorage = (): StorageLike | null => {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      return window.localStorage;
    }
  } catch {
    // Ignore storage access failures.
  }

  return null;
};

const cloneLegacyUser = (user: LegacyUserInfo): LegacyUserInfo => ({
  ...user,
  powerList: Array.isArray(user.powerList) ? [...user.powerList] : user.powerList ?? null,
});

const buildRouteState = (view: HomeView): SessionRouteState => {
  switch (view) {
    case "contact":
      return {
        path: "/home/contact",
        name: "Contact",
        params: {},
        query: {},
      };
    case "settings":
      return {
        path: "/home/settings",
        name: "Settings",
        params: {},
        query: {},
      };
    case "chat":
    default:
      return {
        path: "/home/chat",
        name: "Chat",
        params: {},
        query: {},
      };
  }
};

const buildPageState = (currentChatGroupId: string | null = null): SessionPageState => ({
  currentChatGroupId,
});

const cloneRouteState = (routeState: SessionRouteState): SessionRouteState => ({
  path: routeState.path,
  name: routeState.name,
  params: { ...routeState.params },
  query: { ...routeState.query },
});

const clonePageState = (pageState: SessionPageState): SessionPageState => ({
  currentChatGroupId: pageState.currentChatGroupId ?? null,
});

const cloneAccount = (account: SessionAccount): SessionAccount => ({
  ...account,
  user: cloneLegacyUser(account.user),
  routeState: cloneRouteState(account.routeState),
  pageState: clonePageState(account.pageState),
});

const normalizeRouteState = (
  routeState: SessionRouteState | undefined,
  activeView: HomeView,
): SessionRouteState => {
  if (!routeState?.path || !routeState?.name) {
    return buildRouteState(activeView);
  }

  return {
    path: routeState.path,
    name: routeState.name,
    params: { ...routeState.params },
    query: { ...routeState.query },
  };
};

const normalizePageState = (pageState: SessionPageState | undefined): SessionPageState =>
  buildPageState(pageState?.currentChatGroupId ?? null);

const normalizeAccount = (account: SessionAccount): SessionAccount => {
  const activeView = isHomeView(account.activeView) ? account.activeView : DEFAULT_HOME_VIEW;

  return {
    id: account.id,
    displayName: account.displayName,
    user: cloneLegacyUser(account.user),
    accessToken: account.accessToken ?? null,
    refreshToken: account.refreshToken ?? null,
    activeView,
    routeState: normalizeRouteState(account.routeState, activeView),
    pageState: normalizePageState(account.pageState),
  };
};

const readPersistedState = (storage: StorageLike | null = getDefaultStorage()): PersistedSessionState | null => {
  if (!storage) {
    return null;
  }

  try {
    const raw = storage.getItem(SESSION_STORAGE_KEY);
    if (!raw) {
      return null;
    }

    const parsed = JSON.parse(raw) as PersistedSessionState;
    if (!Array.isArray(parsed.accounts)) {
      return null;
    }

    const accounts = parsed.accounts
      .filter((account): account is SessionAccount => Boolean(account?.id) && Boolean(account?.user?.id))
      .map(normalizeAccount);

    return {
      accounts,
      currentAccountId: typeof parsed.currentAccountId === "string" ? parsed.currentAccountId : null,
    };
  } catch {
    return null;
  }
};

const state = reactive<SessionState>({
  accounts: [],
  currentAccountId: null,
  currentUser: null,
  activeView: DEFAULT_HOME_VIEW,
  accessToken: null,
  refreshToken: null,
  currentChatGroupId: null,
});

const applyCurrentAccount = (account: SessionAccount | null) => {
  state.currentAccountId = account?.id ?? null;
  state.currentUser = account ? cloneLegacyUser(account.user) : null;
  state.activeView = account?.activeView ?? DEFAULT_HOME_VIEW;
  state.accessToken = account?.accessToken ?? null;
  state.refreshToken = account?.refreshToken ?? null;
  state.currentChatGroupId = account?.pageState.currentChatGroupId ?? null;
};

const getCurrentAccount = (): SessionAccount | null => {
  if (!state.currentAccountId) {
    return null;
  }

  return state.accounts.find((account) => account.id === state.currentAccountId) ?? null;
};

const persistState = (storage: StorageLike | null = getDefaultStorage()) => {
  if (!storage) {
    return;
  }

  try {
    if (state.accounts.length === 0) {
      storage.removeItem(SESSION_STORAGE_KEY);
      return;
    }

    const payload: PersistedSessionState = {
      accounts: state.accounts.map(cloneAccount),
      currentAccountId: state.currentAccountId,
    };
    storage.setItem(SESSION_STORAGE_KEY, JSON.stringify(payload));
  } catch {
    // Ignore storage write failures.
  }
};

const replaceAccounts = (accounts: SessionAccount[]) => {
  state.accounts = accounts.map(normalizeAccount);
};

const getAccountById = (accountId: string | null | undefined): SessionAccount | null => {
  if (!accountId) {
    return null;
  }

  return state.accounts.find((account) => account.id === accountId) ?? null;
};

const upsertAccount = (
  user: LegacyUserInfo,
  accessToken?: string | null,
  refreshToken?: string | null,
  displayName?: string | null,
): SessionAccount => {
  const existing = getAccountById(user.id);
  const nextAccount: SessionAccount = normalizeAccount({
    id: user.id,
    displayName: displayName || existing?.displayName || user.nickname || user.username || user.id,
    user,
    accessToken: accessToken ?? existing?.accessToken ?? null,
    refreshToken: refreshToken ?? existing?.refreshToken ?? null,
    activeView: existing?.activeView ?? DEFAULT_HOME_VIEW,
    routeState: existing?.routeState ?? buildRouteState(existing?.activeView ?? DEFAULT_HOME_VIEW),
    pageState: existing?.pageState ?? buildPageState(),
  });

  const nextAccounts = state.accounts.filter((account) => account.id !== user.id);
  nextAccounts.push(nextAccount);
  replaceAccounts(nextAccounts);
  return nextAccount;
};

const sessionStore = {
  state,
  getCurrentAccount,
  getAccountById,
  setActiveView(view: HomeView) {
    const currentAccount = getCurrentAccount();
    if (!currentAccount) {
      state.activeView = view;
      return;
    }

    currentAccount.activeView = view;
    currentAccount.routeState = buildRouteState(view);
    applyCurrentAccount(currentAccount);
    persistState();
  },
  setCurrentChatGroupId(roomId: string | null) {
    const currentAccount = getCurrentAccount();
    if (!currentAccount) {
      state.currentChatGroupId = roomId ?? null;
      return;
    }

    currentAccount.pageState = buildPageState(roomId ?? null);
    applyCurrentAccount(currentAccount);
    persistState();
  },
  setAuthenticated(user: LegacyUserInfo, accessToken?: string | null, refreshToken?: string | null) {
    const account = upsertAccount(user, accessToken, refreshToken);
    applyCurrentAccount(account);
    persistState();
  },
  updateCurrentUser(user: LegacyUserInfo) {
    const currentAccount = getCurrentAccount();
    if (!currentAccount) {
      return;
    }

    currentAccount.user = cloneLegacyUser(user);
    currentAccount.displayName = user.nickname || user.username || user.id;
    applyCurrentAccount(currentAccount);
    persistState();
  },
  switchAccount(accountId: string) {
    const nextAccount = getAccountById(accountId);
    if (!nextAccount) {
      return false;
    }

    applyCurrentAccount(nextAccount);
    persistState();
    return true;
  },
  removeAccount(accountId: string) {
    const nextAccounts = state.accounts.filter((account) => account.id !== accountId);
    replaceAccounts(nextAccounts);

    if (state.currentAccountId === accountId) {
      applyCurrentAccount(state.accounts[0] ?? null);
    } else {
      applyCurrentAccount(getCurrentAccount());
    }

    persistState();
  },
  restorePersistedState(storage: StorageLike | null = getDefaultStorage()) {
    const persisted = readPersistedState(storage);
    if (!persisted || persisted.accounts.length === 0) {
      return false;
    }

    replaceAccounts(persisted.accounts);
    const currentAccount = getAccountById(persisted.currentAccountId) ?? state.accounts[0] ?? null;
    applyCurrentAccount(currentAccount);
    persistState(storage);
    return true;
  },
  hydrateFromBootstrap(snapshot: BootstrapSnapshot | null) {
    if (!snapshot) {
      return;
    }

    const displayNameById = new Map(snapshot.accounts.map((account) => [account.id, account.display_name]));
    replaceAccounts(
      state.accounts.map((account) => ({
        ...account,
        displayName: displayNameById.get(account.id) || account.displayName,
      })),
    );

    if (!snapshot.auth.logged_in || !snapshot.auth.current_user) {
      if (state.accounts.length === 0) {
        applyCurrentAccount(null);
      }
      return;
    }

    const authUser = mapBootstrapUserToLegacy(snapshot.auth.current_user);
    const existing = getAccountById(authUser.id);
    const account = upsertAccount(
      authUser,
      existing?.accessToken ?? state.accessToken,
      existing?.refreshToken ?? state.refreshToken,
      displayNameById.get(authUser.id) || authUser.nickname,
    );
    applyCurrentAccount(account);
    persistState();
  },
  clear() {
    replaceAccounts([]);
    applyCurrentAccount(null);
    persistState();
  },
};

export const useSessionStore = () => sessionStore;
