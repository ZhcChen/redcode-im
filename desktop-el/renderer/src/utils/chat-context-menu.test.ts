import { describe, expect, test } from "bun:test";
import {
  clampContextMenuPosition,
  getChatContextMenuLabels,
} from "./chat-context-menu";

describe("chat context menu helpers", () => {
  test("clamps context menu position inside viewport", () => {
    expect(
      clampContextMenuPosition(
        { x: 480, y: 380 },
        {
          menuWidth: 180,
          menuHeight: 160,
          viewportWidth: 500,
          viewportHeight: 400,
          padding: 8,
        },
      ),
    ).toEqual({
      x: 312,
      y: 232,
    });

    expect(
      clampContextMenuPosition(
        { x: 4, y: 2 },
        {
          menuWidth: 180,
          menuHeight: 160,
          viewportWidth: 500,
          viewportHeight: 400,
          padding: 8,
        },
      ),
    ).toEqual({
      x: 8,
      y: 8,
    });
  });

  test("builds chat context menu labels from pinned and muted state", () => {
    expect(
      getChatContextMenuLabels({
        isPinned: false,
        isMuted: false,
      }),
    ).toEqual({
      pinLabel: "置顶",
      muteLabel: "消息免打扰",
      deleteLabel: "删除对话",
    });

    expect(
      getChatContextMenuLabels({
        isPinned: true,
        isMuted: true,
      }),
    ).toEqual({
      pinLabel: "取消置顶",
      muteLabel: "允许消息通知",
      deleteLabel: "删除对话",
    });
  });
});
