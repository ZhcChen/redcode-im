import { beforeEach, describe, expect, test } from "bun:test";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const { createNotificationService } = await import("./notification.js");

describe("createNotificationService", () => {
  beforeEach(() => {
    resetElectronMockState();
  });

  test("reports support and shows notifications only when supported", async () => {
    const service = createNotificationService();

    electronMockState.notificationSupported = true;
    await expect(service.isSupported()).resolves.toBe(true);

    await service.show({
      title: "新消息",
      body: "你有一条未读消息",
      silent: true,
    });

    expect(electronMockState.notifications).toEqual([
      {
        options: {
          title: "新消息",
          body: "你有一条未读消息",
          silent: true,
        },
        shown: true,
      },
    ]);

    electronMockState.notificationSupported = false;
    await expect(service.isSupported()).resolves.toBe(false);
    await service.show({
      title: "不会展示",
    });

    expect(electronMockState.notifications).toHaveLength(1);
  });
});
