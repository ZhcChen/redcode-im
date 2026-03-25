import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { SESSION_STORAGE_KEY, useSessionStore } from "./session";
import type { BootstrapSnapshot } from "@/types/bootstrap";

const createMemoryStorage = () => {
  const store = new Map<string, string>();

  return {
    getItem(key: string) {
      return store.get(key) ?? null;
    },
    setItem(key: string, value: string) {
      store.set(key, value);
    },
    removeItem(key: string) {
      store.delete(key);
    },
  };
};

const createLegacyUser = (id: string, nickname: string) => ({
  id,
  username: `${id}-username`,
  nickname,
  avatar: "",
  avatarObjectKey: null,
  avatarLocalPath: null,
  mobile: `${id}-mobile`,
  email: `${id}@example.com`,
  isLoggedIn: true,
  realName: nickname,
  chatNumber: `${id}-chat`,
  address: "",
  createTime: null,
  lastLoginTime: null,
  activeStatus: 1,
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null,
});

describe("session store", () => {
  const originalWindow = globalThis.window;
  const sessionStore = useSessionStore();

  beforeEach(() => {
    globalThis.window = {
      localStorage: createMemoryStorage(),
    } as Window;
    sessionStore.clear();
  });

  afterEach(() => {
    sessionStore.clear();
    if (originalWindow) {
      globalThis.window = originalWindow;
      return;
    }
    Reflect.deleteProperty(globalThis, "window");
  });

  test("keeps multiple accounts and restores each account active view on switch", () => {
    const alice = createLegacyUser("u-1", "Alice");
    const bob = createLegacyUser("u-2", "Bob");

    sessionStore.setAuthenticated(alice, "token-alice", "refresh-alice");
    sessionStore.setActiveView("contact");

    sessionStore.setAuthenticated(bob, "token-bob", "refresh-bob");
    sessionStore.setActiveView("settings");

    sessionStore.switchAccount("u-1");
    expect(sessionStore.state.currentAccountId).toBe("u-1");
    expect(sessionStore.state.currentUser?.id).toBe("u-1");
    expect(sessionStore.state.accessToken).toBe("token-alice");
    expect(sessionStore.state.activeView).toBe("contact");

    sessionStore.switchAccount("u-2");
    expect(sessionStore.state.currentAccountId).toBe("u-2");
    expect(sessionStore.state.currentUser?.id).toBe("u-2");
    expect(sessionStore.state.accessToken).toBe("token-bob");
    expect(sessionStore.state.activeView).toBe("settings");
    expect(sessionStore.getAccountById("u-1")?.routeState).toEqual({
      path: "/home/contact",
      name: "Contact",
      params: {},
      query: {},
    });
    expect(sessionStore.getAccountById("u-2")?.routeState).toEqual({
      path: "/home/settings",
      name: "Settings",
      params: {},
      query: {},
    });
    expect(sessionStore.state.accounts).toHaveLength(2);
  });

  test("restores persisted accounts and keeps current account active view", () => {
    const alice = createLegacyUser("u-1", "Alice");
    const bob = createLegacyUser("u-2", "Bob");

    sessionStore.setAuthenticated(alice, "token-alice", "refresh-alice");
    sessionStore.setActiveView("contact");
    sessionStore.setCurrentChatGroupId("room-alice");
    sessionStore.setCurrentContactPageState({
      mode: "discover",
      searchQuery: "ali",
      discoverKeyword: "alice@example.com",
      selectedContactUserId: "friend-alice",
      selectedRequestId: "request-alice",
      selectedSearchUserId: "search-alice",
      hasSearchedUsers: true,
      friendRequestMessage: "我是 Alice",
    });
    sessionStore.setAuthenticated(bob, "token-bob", "refresh-bob");
    sessionStore.setActiveView("settings");
    sessionStore.setCurrentChatGroupId("room-bob");
    sessionStore.setCurrentSettingsPageState({
      isEditingNickname: true,
      nicknameDraft: "Bobby",
      feedbackContentDraft: "桌面端有个问题需要反馈",
      feedbackContactDraft: "bob@example.com",
    });

    const raw = globalThis.window.localStorage.getItem(SESSION_STORAGE_KEY);
    sessionStore.clear();
    globalThis.window = {
      localStorage: createMemoryStorage(),
    } as Window;
    if (raw) {
      globalThis.window.localStorage.setItem(SESSION_STORAGE_KEY, raw);
    }
    sessionStore.restorePersistedState();

    expect(sessionStore.state.accounts.map((account) => account.id)).toEqual(["u-1", "u-2"]);
    expect(sessionStore.state.currentAccountId).toBe("u-2");
    expect(sessionStore.state.currentUser?.nickname).toBe("Bob");
    expect(sessionStore.state.activeView).toBe("settings");
    expect(sessionStore.state.currentChatGroupId).toBe("room-bob");
    expect(sessionStore.state.currentSettingsPageState).toEqual({
      isEditingNickname: true,
      nicknameDraft: "Bobby",
      feedbackContentDraft: "桌面端有个问题需要反馈",
      feedbackContactDraft: "bob@example.com",
    });

    sessionStore.switchAccount("u-1");
    expect(sessionStore.state.activeView).toBe("contact");
    expect(sessionStore.state.currentChatGroupId).toBe("room-alice");
    expect(sessionStore.state.currentContactPageState).toEqual({
      mode: "discover",
      searchQuery: "ali",
      discoverKeyword: "alice@example.com",
      selectedContactUserId: "friend-alice",
      selectedRequestId: "request-alice",
      selectedSearchUserId: "search-alice",
      hasSearchedUsers: true,
      friendRequestMessage: "我是 Alice",
    });
  });

  test("keeps contact and settings page state isolated per account when switching", () => {
    const alice = createLegacyUser("u-1", "Alice");
    const bob = createLegacyUser("u-2", "Bob");

    sessionStore.setAuthenticated(alice, "token-alice", "refresh-alice");
    sessionStore.setCurrentContactPageState({
      mode: "requests",
      searchQuery: "alice-contact",
      discoverKeyword: "alice-discover",
      selectedContactUserId: "friend-u-1",
      selectedRequestId: "request-u-1",
      selectedSearchUserId: "search-u-1",
      hasSearchedUsers: true,
      friendRequestMessage: "Alice 申请",
    });
    sessionStore.setCurrentSettingsPageState({
      isEditingNickname: true,
      nicknameDraft: "Alice Draft",
      feedbackContentDraft: "Alice feedback",
      feedbackContactDraft: "alice@example.com",
    });

    sessionStore.setAuthenticated(bob, "token-bob", "refresh-bob");
    sessionStore.setCurrentContactPageState({
      mode: "discover",
      searchQuery: "bob-contact",
      discoverKeyword: "bob-discover",
      selectedContactUserId: "friend-u-2",
      selectedRequestId: "request-u-2",
      selectedSearchUserId: "search-u-2",
      hasSearchedUsers: false,
      friendRequestMessage: "Bob 申请",
    });
    sessionStore.setCurrentSettingsPageState({
      isEditingNickname: false,
      nicknameDraft: "Bob Draft",
      feedbackContentDraft: "Bob feedback",
      feedbackContactDraft: "bob@example.com",
    });

    sessionStore.switchAccount("u-1");
    expect(sessionStore.state.currentContactPageState).toEqual({
      mode: "requests",
      searchQuery: "alice-contact",
      discoverKeyword: "alice-discover",
      selectedContactUserId: "friend-u-1",
      selectedRequestId: "request-u-1",
      selectedSearchUserId: "search-u-1",
      hasSearchedUsers: true,
      friendRequestMessage: "Alice 申请",
    });
    expect(sessionStore.state.currentSettingsPageState).toEqual({
      isEditingNickname: true,
      nicknameDraft: "Alice Draft",
      feedbackContentDraft: "Alice feedback",
      feedbackContactDraft: "alice@example.com",
    });

    sessionStore.switchAccount("u-2");
    expect(sessionStore.state.currentContactPageState).toEqual({
      mode: "discover",
      searchQuery: "bob-contact",
      discoverKeyword: "bob-discover",
      selectedContactUserId: "friend-u-2",
      selectedRequestId: "request-u-2",
      selectedSearchUserId: "search-u-2",
      hasSearchedUsers: false,
      friendRequestMessage: "Bob 申请",
    });
    expect(sessionStore.state.currentSettingsPageState).toEqual({
      isEditingNickname: false,
      nicknameDraft: "Bob Draft",
      feedbackContentDraft: "Bob feedback",
      feedbackContactDraft: "bob@example.com",
    });
  });

  test("hydrates bootstrap accounts without dropping current account tokens", () => {
    const alice = createLegacyUser("u-1", "Alice");
    sessionStore.setAuthenticated(alice, "token-alice", "refresh-alice");

    const snapshot: BootstrapSnapshot = {
      accounts: [
        {
          id: "u-1",
          display_name: "Alice Display",
        },
      ],
      config: {
        app_name: "RedCode IM",
        environment: "development",
      },
      recent_conversations: [],
      connection: {
        status: "authenticated",
      },
      feature_flags: {},
      auth: {
        logged_in: true,
        current_user: {
          id: "u-1",
          username: "u-1-username",
          email: "u-1@example.com",
          nickname: "Alice Display",
          avatar_url: null,
          status: "active",
        },
      },
    };

    sessionStore.hydrateFromBootstrap(snapshot);

    expect(sessionStore.state.currentUser?.nickname).toBe("Alice Display");
    expect(sessionStore.state.accessToken).toBe("token-alice");
    expect(sessionStore.state.accounts).toEqual([
      expect.objectContaining({
        id: "u-1",
        displayName: "Alice Display",
        accessToken: "token-alice",
      }),
    ]);
  });
});
