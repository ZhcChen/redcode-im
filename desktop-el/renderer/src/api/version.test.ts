import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { VersionApi } from "./version";

describe("version api", () => {
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

  test("requests version download url through backend request", async () => {
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
                message: "生成下载链接成功",
                download_url: "https://download.example.com/desktop-el.dmg"
              }
            };
          }
        }
      }
    } as Window;

    const response = await VersionApi.getDownloadUrl({
      id: "version-1",
      expiresInSeconds: 900
    });

    expect(calls).toEqual([
      {
        method: "http.request",
        params: {
          method: "GET",
          path: "/versions/download",
          headers: undefined,
          body: undefined,
          query_params: {
            id: "version-1",
            expires_in_seconds: "900"
          },
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
        message: "生成下载链接成功",
        downloadUrl: "https://download.example.com/desktop-el.dmg"
      }
    });
  });
});
