import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { UserApi } from "./user";

describe("user api search", () => {
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

  test("searches users through go-core rpc and maps result", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: [
                {
                  id: "u-2",
                  username: "alice",
                  email: "alice@example.com",
                  nickname: "Alice",
                  avatar_url: "https://example.com/alice.png",
                  avatar_object_key: "avatars/u-2.png",
                  status: "active"
                }
              ]
            };
          }
        }
      }
    } as Window;

    const response = await UserApi.searchUsers({
      keyword: " alice ",
      limit: 5
    });

    expect(calls).toEqual([
      {
        method: "user.search",
        params: {
          keyword: "alice",
          limit: 5
        }
      }
    ]);
    expect(response.success).toBe(true);
    expect(response.data).toEqual([
      {
        id: "u-2",
        username: "alice",
        email: "alice@example.com",
        nickname: "Alice",
        avatarUrl: "https://example.com/alice.png",
        avatarObjectKey: "avatars/u-2.png",
        status: "active"
      }
    ]);
  });
});
