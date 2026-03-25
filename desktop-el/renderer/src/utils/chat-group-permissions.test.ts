import { describe, expect, test } from "bun:test";
import { resolveGroupComposerState, resolveGroupManageState } from "./chat-group-permissions";

describe("chat group permission helpers", () => {
  test("marks owner and admin as manageable roles", () => {
    expect(
      resolveGroupManageState({
        currentUserId: "u-1",
        ownerId: "u-1",
        members: [
          { userId: "u-1", role: "owner" },
          { userId: "u-2", role: "member" },
        ],
      }),
    ).toEqual({
      isOwner: true,
      isAdmin: false,
      canManage: true,
    });

    expect(
      resolveGroupManageState({
        currentUserId: "u-2",
        ownerId: "u-1",
        members: [
          { userId: "u-1", role: "owner" },
          { userId: "u-2", role: "admin" },
        ],
      }),
    ).toEqual({
      isOwner: false,
      isAdmin: true,
      canManage: true,
    });
  });

  test("disables composer when current user is personally muted", () => {
    expect(
      resolveGroupComposerState({
        isGroupChat: true,
        canManageGroup: false,
        groupSettings: {
          globalMuteEnabled: false,
          myMute: {
            isMuted: true,
            reason: "刷屏",
          },
        },
      }),
    ).toEqual({
      disabled: true,
      placeholder: "你已被禁言",
      tip: "你已在当前群被禁言，暂时无法发送消息。",
    });
  });

  test("disables composer when global mute is enabled for non-managers", () => {
    expect(
      resolveGroupComposerState({
        isGroupChat: true,
        canManageGroup: false,
        groupSettings: {
          globalMuteEnabled: true,
          myMute: null,
        },
      }),
    ).toEqual({
      disabled: true,
      placeholder: "当前群已开启全员禁言",
      tip: "当前群已开启全员禁言，仅群主或管理员可发送消息。",
    });
  });

  test("keeps composer available for managers during global mute", () => {
    expect(
      resolveGroupComposerState({
        isGroupChat: true,
        canManageGroup: true,
        groupSettings: {
          globalMuteEnabled: true,
          myMute: null,
        },
      }),
    ).toEqual({
      disabled: false,
      placeholder: "输入一条文本消息...",
      tip: null,
    });
  });
});
