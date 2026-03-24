import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { FeedbackApi } from "./feedback";

describe("feedback api", () => {
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

  test("submits feedback through backend request", async () => {
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
                message: "反馈提交成功，感谢您的支持！"
              }
            };
          }
        }
      }
    } as Window;

    const response = await FeedbackApi.submit({
      content: "  桌面端这块体验不错，但设置页还想再补一点提示。  ",
      contact: "  alice@example.com  "
    });

    expect(calls).toEqual([
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/feedbacks",
          headers: undefined,
          body: {
            content: "桌面端这块体验不错，但设置页还想再补一点提示。",
            contact: "alice@example.com"
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
        message: "反馈提交成功，感谢您的支持！"
      }
    });
  });

  test("rejects empty feedback content before request", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            throw new Error("should not be called");
          }
        }
      }
    } as Window;

    const response = await FeedbackApi.submit({
      content: "   "
    });

    expect(calls).toEqual([]);
    expect(response).toEqual({
      code: 400,
      success: false,
      message: "反馈内容不能为空",
      data: null
    });
  });
});
