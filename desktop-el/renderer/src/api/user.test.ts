import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { UserApi } from "./user";

class MockXMLHttpRequest {
  static instances: MockXMLHttpRequest[] = [];

  method = "";
  url = "";
  headers: Record<string, string> = {};
  body: BodyInit | null = null;
  status = 200;
  upload = {
    onprogress: null as ((event: ProgressEvent<EventTarget>) => void) | null
  };
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  onload: (() => void) | null = null;

  constructor() {
    MockXMLHttpRequest.instances.push(this);
  }

  open(method: string, url: string) {
    this.method = method;
    this.url = url;
  }

  setRequestHeader(headerKey: string, headerValue: string) {
    this.headers[headerKey] = headerValue;
  }

  send(body: BodyInit | null) {
    this.body = body;
    this.onload?.();
  }
}

describe("user api", () => {
  const originalWindow = globalThis.window;
  const originalXMLHttpRequest = globalThis.XMLHttpRequest;
  let calls: Array<{ method: string; params: Record<string, unknown> | undefined }> = [];

  beforeEach(() => {
    calls = [];
    MockXMLHttpRequest.instances = [];
  });

  afterEach(() => {
    globalThis.XMLHttpRequest = originalXMLHttpRequest;
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

  test("uploads avatar through direct upload, commits it, and refreshes current profile", async () => {
    globalThis.XMLHttpRequest = MockXMLHttpRequest as unknown as typeof XMLHttpRequest;
    const file = new File(["avatar-image"], "avatar.png", { type: "image/png" });

    globalThis.window = {
      crypto: {
        subtle: {
          digest: async () => new Uint8Array([0, 1, 255]).buffer
        }
      },
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            const path = params?.path;

            if (method === "http.request" && path === "/users/me/avatar/direct-upload") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "signature ready",
                  key: "avatars/u-1/new-avatar.png",
                  signature: {
                    url: "https://upload.example.com/avatar",
                    method: "PUT",
                    headers: {
                      Authorization: "signed-token",
                      Host: "upload.example.com"
                    },
                    key: "avatars/u-1/new-avatar.png"
                  }
                }
              };
            }

            if (method === "http.request" && path === "/users/me/avatar/commit") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "avatar committed",
                  download_url: "https://download.example.com/avatar.png"
                }
              };
            }

            if (method === "http.request" && path === "/auth/me") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  id: "u-1",
                  username: "alice",
                  email: "alice@example.com",
                  nickname: "Alice",
                  avatar_url: "https://static.example.com/avatar.png",
                  avatar_object_key: "avatars/u-1/new-avatar.png",
                  status: "active"
                }
              };
            }

            throw new Error(`unexpected rpc call: ${method} ${path ?? ""}`);
          }
        }
      }
    } as unknown as Window;

    const response = await UserApi.uploadAvatar(file);

    expect(calls).toEqual([
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/users/me/avatar/direct-upload",
          headers: undefined,
          body: {
            content_type: "image/png",
            file_size: file.size,
            hash_value: "0001ff",
            hash_alg: 2
          },
          query_params: undefined,
          inject_token: undefined
        }
      },
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/users/me/avatar/commit",
          headers: undefined,
          body: {
            key: "avatars/u-1/new-avatar.png",
            delete_previous: true,
            expires_in_seconds: 600
          },
          query_params: undefined,
          inject_token: undefined
        }
      },
      {
        method: "http.request",
        params: {
          method: "GET",
          path: "/auth/me",
          headers: undefined,
          body: undefined,
          query_params: undefined,
          inject_token: undefined
        }
      }
    ]);
    expect(MockXMLHttpRequest.instances).toHaveLength(1);
    expect(MockXMLHttpRequest.instances[0]).toMatchObject({
      method: "PUT",
      url: "https://upload.example.com/avatar",
      headers: {
        Authorization: "signed-token",
        "Content-Type": "image/png"
      },
      body: file
    });
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "avatar committed",
      data: {
        id: "u-1",
        username: "alice",
        nickname: "Alice",
        avatar: "https://static.example.com/avatar.png",
        avatarObjectKey: "avatars/u-1/new-avatar.png",
        avatarLocalPath: null,
        mobile: "alice",
        email: "alice@example.com",
        isLoggedIn: true,
        realName: "Alice",
        chatNumber: "alice",
        address: "",
        createTime: null,
        lastLoginTime: null,
        activeStatus: 1,
        delFlag: null,
        level: null,
        userDeviceId: null,
        userSign: null,
        trcSdkAppId: null,
        powerList: null
      }
    });
  });

  test("commits reused avatar object without uploading when backend skips signature", async () => {
    globalThis.XMLHttpRequest = MockXMLHttpRequest as unknown as typeof XMLHttpRequest;
    const file = new File(["avatar-reuse"], "avatar.webp", { type: "image/webp" });

    globalThis.window = {
      crypto: {
        subtle: {
          digest: async () => new Uint8Array([16, 32, 48]).buffer
        }
      },
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            const path = params?.path;

            if (method === "http.request" && path === "/users/me/avatar/direct-upload") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "reused",
                  key: "avatars/u-1/reused-avatar.webp",
                  signature: null
                }
              };
            }

            if (method === "http.request" && path === "/users/me/avatar/commit") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "avatar committed",
                  download_url: "https://download.example.com/reused-avatar.webp"
                }
              };
            }

            if (method === "http.request" && path === "/auth/me") {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  id: "u-1",
                  username: "alice",
                  email: "alice@example.com",
                  nickname: "Alice",
                  avatar_url: "https://static.example.com/reused-avatar.webp",
                  avatar_object_key: "avatars/u-1/reused-avatar.webp",
                  status: "active"
                }
              };
            }

            throw new Error(`unexpected rpc call: ${method} ${path ?? ""}`);
          }
        }
      }
    } as unknown as Window;

    const response = await UserApi.uploadAvatar(file);

    expect(MockXMLHttpRequest.instances).toHaveLength(0);
    expect(response.success).toBe(true);
    expect(response.data?.avatarObjectKey).toBe("avatars/u-1/reused-avatar.webp");
    expect(response.data?.avatar).toBe("https://static.example.com/reused-avatar.webp");
  });

  test("updates current user password through backend request", async () => {
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
                success: true,
                message: "Password changed successfully"
              }
            };
          }
        }
      }
    } as Window;

    const response = await UserApi.updateUserPassword({
      oldPwd: "oldpass123",
      newPwd: "newpass456"
    });

    expect(calls).toEqual([
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/users/me/password",
          headers: undefined,
          body: {
            old_password: "oldpass123",
            new_password: "newpass456"
          },
          query_params: undefined,
          inject_token: undefined
        }
      }
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        success: true,
        message: "Password changed successfully"
      }
    });
  });
});
