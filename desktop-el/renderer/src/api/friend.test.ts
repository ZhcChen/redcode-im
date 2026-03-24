import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { FriendApi } from "./friend";

describe("friend api request creation", () => {
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

  test("creates friend request through go-core rpc and maps result", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: {
                id: "request-1",
                requester: {
                  id: "u-1",
                  username: "me",
                  email: "me@example.com",
                  nickname: "Me",
                  status: "active"
                },
                addressee: {
                  id: "u-2",
                  username: "alice",
                  email: "alice@example.com",
                  nickname: "Alice",
                  status: "active"
                },
                status: "pending",
                message: "你好，我是 Alice",
                created_at: "2026-03-25T11:00:00Z",
                responded_at: null,
                is_incoming: false
              }
            };
          }
        }
      }
    } as Window;

    const response = await FriendApi.createFriendRequest({
      targetUserId: "u-2",
      message: "你好，我是 Alice"
    });

    expect(calls).toEqual([
      {
        method: "friend.request.create",
        params: {
          target_user_id: "u-2",
          message: "你好，我是 Alice"
        }
      }
    ]);
    expect(response.success).toBe(true);
    expect(response.data?.id).toBe("request-1");
    expect(response.data?.addressee.id).toBe("u-2");
    expect(response.data?.message).toBe("你好，我是 Alice");
  });

  test("updates friend remark through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: {
                remark: "Alice 同事"
              }
            };
          }
        }
      }
    } as Window;

    const response = await FriendApi.updateRemark({
      friendUserId: "u-2",
      remark: "Alice 同事"
    });

    expect(calls).toEqual([
      {
        method: "friend.remark.update",
        params: {
          friend_user_id: "u-2",
          remark: "Alice 同事"
        }
      }
    ]);
    expect(response.success).toBe(true);
    expect(response.data?.remark).toBe("Alice 同事");
  });

  test("deletes friend through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "删除好友成功",
              data: {
                success: true,
                message: "删除好友成功"
              }
            };
          }
        }
      }
    } as Window;

    const response = await FriendApi.deleteFriend({
      friendUserId: "u-2"
    });

    expect(calls).toEqual([
      {
        method: "friend.delete",
        params: {
          friend_user_id: "u-2"
        }
      }
    ]);
    expect(response.success).toBe(true);
    expect(response.message).toBe("删除好友成功");
  });
});
