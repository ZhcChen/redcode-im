import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { SystemApi, type LegacyUserInfo } from "./system";

const createLegacyUser = (id: string, nickname: string): LegacyUserInfo => ({
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

describe("system api", () => {
  const originalWindow = globalThis.window;
  let calls: Array<{ method: string; params: Record<string, unknown> | undefined }> = [];

  beforeEach(() => {
    calls = [];
  });

  afterEach(() => {
    if (originalWindow) {
      globalThis.window = originalWindow;
      return;
    }
    Reflect.deleteProperty(globalThis, "window");
  });

  test("switches active account through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return { success: true };
          },
        },
      },
    } as Window;

    const response = await SystemApi.switchAccount("u-2");

    expect(calls).toEqual([
      {
        method: "auth.account.switch",
        params: {
          account_id: "u-2",
        },
      },
    ]);
    expect(response).toEqual({ success: true });
  });

  test("restores persisted accounts through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return { success: true };
          },
        },
      },
    } as Window;

    const alice = createLegacyUser("u-1", "Alice");
    const bob = createLegacyUser("u-2", "Bob");

    const response = await SystemApi.restoreAccounts({
      currentAccountId: "u-2",
      accounts: [
        {
          id: "u-1",
          accessToken: "token-alice",
          refreshToken: "refresh-alice",
          userInfo: alice,
        },
        {
          id: "u-2",
          accessToken: "token-bob",
          refreshToken: "refresh-bob",
          userInfo: bob,
        },
      ],
    });

    expect(calls).toEqual([
      {
        method: "auth.accounts.restore",
        params: {
          current_account_id: "u-2",
          accounts: [
            {
              id: "u-1",
              token: "token-alice",
              refresh_token: "refresh-alice",
              user: {
                id: "u-1",
                username: "u-1-username",
                email: "u-1@example.com",
                nickname: "Alice",
                avatar_url: null,
                status: "active",
              },
            },
            {
              id: "u-2",
              token: "token-bob",
              refresh_token: "refresh-bob",
              user: {
                id: "u-2",
                username: "u-2-username",
                email: "u-2@example.com",
                nickname: "Bob",
                avatar_url: null,
                status: "active",
              },
            },
          ],
        },
      },
    ]);
    expect(response).toEqual({ success: true });
  });
});
