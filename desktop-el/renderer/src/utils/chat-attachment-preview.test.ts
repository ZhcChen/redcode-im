import { describe, expect, test } from "bun:test";
import {
  createAttachmentPreviewUrlStore,
  getInlinePreviewAssetKey,
  shouldInlinePreviewAttachment
} from "./chat-attachment-preview";

describe("chat attachment preview helpers", () => {
  test("marks image, video and audio attachments as inline-previewable", () => {
    expect(shouldInlinePreviewAttachment("image")).toBe(true);
    expect(shouldInlinePreviewAttachment("video")).toBe(true);
    expect(shouldInlinePreviewAttachment("audio")).toBe(true);
    expect(shouldInlinePreviewAttachment("file")).toBe(false);
  });

  test("prefers video thumbnail key for inline preview asset when available", () => {
    expect(
      getInlinePreviewAssetKey({
        partType: "video",
        attachment: {
          key: "messages/room-2/video.mp4",
          thumbnailKey: "messages/room-2/video-thumb.jpg"
        }
      })
    ).toBe("messages/room-2/video-thumb.jpg");

    expect(
      getInlinePreviewAssetKey({
        partType: "video",
        attachment: {
          key: "messages/room-2/video.mp4",
          thumbnailKey: null
        }
      })
    ).toBe("messages/room-2/video.mp4");
  });

  test("deduplicates concurrent preview URL requests and caches successful responses", async () => {
    let callCount = 0;
    const store = createAttachmentPreviewUrlStore({
      getAttachmentDownloadUrl: async ({ roomId, key, expiresInSeconds }) => {
        callCount += 1;
        expect(roomId).toBe("room-2");
        expect(key).toBe("messages/room-2/image.png");
        expect(expiresInSeconds).toBe(900);
        await Promise.resolve();
        return {
          code: 0,
          success: true,
          message: "",
          data: {
            success: true,
            message: "",
            downloadUrl: "https://example.com/image.png?sign=1"
          }
        };
      }
    });

    const [first, second] = await Promise.all([
      store.resolve({
        roomId: "room-2",
        key: "messages/room-2/image.png",
        expiresInSeconds: 900
      }),
      store.resolve({
        roomId: "room-2",
        key: "messages/room-2/image.png",
        expiresInSeconds: 900
      })
    ]);

    expect(first).toBe("https://example.com/image.png?sign=1");
    expect(second).toBe("https://example.com/image.png?sign=1");
    expect(callCount).toBe(1);
    expect(
      store.getCached({
        roomId: "room-2",
        key: "messages/room-2/image.png"
      })
    ).toBe("https://example.com/image.png?sign=1");

    const third = await store.resolve({
      roomId: "room-2",
      key: "messages/room-2/image.png",
      expiresInSeconds: 900
    });
    expect(third).toBe("https://example.com/image.png?sign=1");
    expect(callCount).toBe(1);
  });

  test("clears inflight state on failure so later requests can retry", async () => {
    let shouldFail = true;
    let callCount = 0;
    const store = createAttachmentPreviewUrlStore({
      getAttachmentDownloadUrl: async () => {
        callCount += 1;
        if (shouldFail) {
          return {
            code: 500,
            success: false,
            message: "temporary failure",
            data: null
          };
        }
        return {
          code: 0,
          success: true,
          message: "",
          data: {
            success: true,
            message: "",
            downloadUrl: "https://example.com/audio.m4a?sign=2"
          }
        };
      }
    });

    await expect(
      store.resolve({
        roomId: "room-3",
        key: "messages/room-3/audio.m4a",
        expiresInSeconds: 600
      })
    ).rejects.toThrow("temporary failure");

    expect(
      store.getCached({
        roomId: "room-3",
        key: "messages/room-3/audio.m4a"
      })
    ).toBeNull();

    shouldFail = false;
    const retried = await store.resolve({
      roomId: "room-3",
      key: "messages/room-3/audio.m4a",
      expiresInSeconds: 600
    });

    expect(retried).toBe("https://example.com/audio.m4a?sign=2");
    expect(callCount).toBe(2);
  });
});
