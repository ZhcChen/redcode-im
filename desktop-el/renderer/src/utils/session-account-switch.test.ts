import { describe, expect, test } from "bun:test";
import { buildLogoutFallbackPlan, buildSwitchAccountPlan } from "./session-account-switch";
import type { SessionAccount } from "@/store/session";

const createAccount = (id: string, nickname: string, activeView: SessionAccount["activeView"], token = `token-${id}`): SessionAccount => ({
  id,
  displayName: nickname,
  user: {
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
  },
  accessToken: token,
  refreshToken: `refresh-${id}`,
  activeView,
});

describe("session account switch helpers", () => {
  test("builds reconnect plan for switching to another stored account", () => {
    const plan = buildSwitchAccountPlan(
      [createAccount("u-1", "Alice", "contact"), createAccount("u-2", "Bob", "settings")],
      "u-1",
      "u-2",
    );

    expect(plan).toEqual({
      previousAccountId: "u-1",
      nextAccount: expect.objectContaining({
        id: "u-2",
        activeView: "settings",
        accessToken: "token-u-2",
      }),
    });
  });

  test("builds logout fallback plan when another account remains", () => {
    const plan = buildLogoutFallbackPlan(
      [createAccount("u-1", "Alice", "contact"), createAccount("u-2", "Bob", "settings")],
      "u-2",
    );

    expect(plan).toEqual({
      removedAccountId: "u-2",
      nextAccount: expect.objectContaining({
        id: "u-1",
        activeView: "contact",
        accessToken: "token-u-1",
      }),
    });
  });

  test("returns null when target account is missing or cannot reconnect", () => {
    expect(buildSwitchAccountPlan([createAccount("u-1", "Alice", "chat")], "u-1", "u-3")).toBeNull();
    expect(
      buildSwitchAccountPlan(
        [createAccount("u-1", "Alice", "chat"), createAccount("u-2", "Bob", "settings", "")],
        "u-1",
        "u-2",
      ),
    ).toBeNull();
    expect(buildLogoutFallbackPlan([createAccount("u-1", "Alice", "chat")], "u-1")).toBeNull();
  });
});
