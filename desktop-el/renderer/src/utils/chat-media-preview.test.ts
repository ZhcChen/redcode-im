import { describe, expect, test } from "bun:test";
import {
  buildImagePreviewGalleryEntries,
  clampImagePreviewScale,
  clampMediaPreviewProgressRatio,
  findMediaPreviewSource,
  formatMediaPreviewPlaybackTime,
  getMediaPreviewPlaybackProgress,
  getMediaPreviewKeyboardAction,
  getImagePreviewGalleryNeighbor,
  getNextImagePreviewRotation,
  getNextImagePreviewScaleFromWheel,
  getNextVideoPreviewCurrentTime,
  getVideoPreviewCurrentTimeFromProgressRatio,
  IMAGE_PREVIEW_MAX_SCALE,
  IMAGE_PREVIEW_MIN_SCALE,
  normalizeImagePreviewRotation,
} from "./chat-media-preview";

describe("chat media preview helpers", () => {
  test("clamps image preview scale into the supported range", () => {
    expect(clampImagePreviewScale(0.2)).toBe(IMAGE_PREVIEW_MIN_SCALE);
    expect(clampImagePreviewScale(1)).toBe(1);
    expect(clampImagePreviewScale(6)).toBe(IMAGE_PREVIEW_MAX_SCALE);
  });

  test("zooms in on negative wheel delta and zooms out on positive wheel delta", () => {
    expect(getNextImagePreviewScaleFromWheel(1, -120)).toBe(1.2);
    expect(getNextImagePreviewScaleFromWheel(1.6, 80)).toBe(1.4);
  });

  test("keeps wheel zoom results within the supported range", () => {
    expect(getNextImagePreviewScaleFromWheel(IMAGE_PREVIEW_MIN_SCALE, 120)).toBe(
      IMAGE_PREVIEW_MIN_SCALE,
    );
    expect(getNextImagePreviewScaleFromWheel(IMAGE_PREVIEW_MAX_SCALE, -120)).toBe(
      IMAGE_PREVIEW_MAX_SCALE,
    );
  });

  test("normalizes image preview rotation into right-angle values", () => {
    expect(normalizeImagePreviewRotation(0)).toBe(0);
    expect(normalizeImagePreviewRotation(90)).toBe(90);
    expect(normalizeImagePreviewRotation(450)).toBe(90);
    expect(normalizeImagePreviewRotation(-90)).toBe(270);
  });

  test("rotates image preview clockwise and counter-clockwise by 90 degrees", () => {
    expect(getNextImagePreviewRotation(0, "clockwise")).toBe(90);
    expect(getNextImagePreviewRotation(90, "clockwise")).toBe(180);
    expect(getNextImagePreviewRotation(0, "counterclockwise")).toBe(270);
    expect(getNextImagePreviewRotation(270, "counterclockwise")).toBe(180);
  });

  test("builds image preview gallery entries from image parts only", () => {
    expect(
      buildImagePreviewGalleryEntries([
        {
          id: "message-1",
          parts: [
            { partType: "text", position: 0 },
            { partType: "image", position: 1 },
            { partType: "video", position: 2 },
          ],
        },
        {
          id: "message-2",
          parts: [
            { partType: "image", position: 0 },
            { partType: "audio", position: 1 },
          ],
        },
      ]),
    ).toEqual([
      {
        id: "message-1:1",
        messageId: "message-1",
        partPosition: 1,
      },
      {
        id: "message-2:0",
        messageId: "message-2",
        partPosition: 0,
      },
    ]);
  });

  test("finds previous and next image preview gallery neighbors", () => {
    const entries = buildImagePreviewGalleryEntries([
      {
        id: "message-1",
        parts: [{ partType: "image", position: 0 }],
      },
      {
        id: "message-2",
        parts: [{ partType: "image", position: 0 }],
      },
      {
        id: "message-3",
        parts: [{ partType: "image", position: 0 }],
      },
    ]);

    expect(getImagePreviewGalleryNeighbor(entries, "message-2:0", "previous")).toEqual({
      id: "message-1:0",
      messageId: "message-1",
      partPosition: 0,
    });
    expect(getImagePreviewGalleryNeighbor(entries, "message-2:0", "next")).toEqual({
      id: "message-3:0",
      messageId: "message-3",
      partPosition: 0,
    });
    expect(getImagePreviewGalleryNeighbor(entries, "message-1:0", "previous")).toBeNull();
    expect(getImagePreviewGalleryNeighbor(entries, "message-3:0", "next")).toBeNull();
  });

  test("maps keyboard input to image preview actions", () => {
    expect(getMediaPreviewKeyboardAction({ previewType: "image", key: "Escape" })).toBe(
      "close",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: "image", key: "ArrowLeft" })).toBe(
      "previous",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: "image", key: "ArrowRight" })).toBe(
      "next",
    );
  });

  test("only allows escape for non-image preview keyboard handling", () => {
    expect(getMediaPreviewKeyboardAction({ previewType: "video", key: "Escape" })).toBe(
      "close",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: null, key: "Escape" })).toBeNull();
  });

  test("maps keyboard input to video preview actions", () => {
    expect(getMediaPreviewKeyboardAction({ previewType: "video", key: " " })).toBe(
      "toggle-play",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: "video", key: "Spacebar" })).toBe(
      "toggle-play",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: "video", key: "ArrowLeft" })).toBe(
      "seek-backward",
    );
    expect(getMediaPreviewKeyboardAction({ previewType: "video", key: "ArrowRight" })).toBe(
      "seek-forward",
    );
  });

  test("formats video playback time labels", () => {
    expect(formatMediaPreviewPlaybackTime(null)).toBe("00:00");
    expect(formatMediaPreviewPlaybackTime(9.9)).toBe("00:09");
    expect(formatMediaPreviewPlaybackTime(65)).toBe("01:05");
    expect(formatMediaPreviewPlaybackTime(3661)).toBe("1:01:01");
  });

  test("computes video playback progress within 0-100 percent", () => {
    expect(getMediaPreviewPlaybackProgress(0, 0)).toBe(0);
    expect(getMediaPreviewPlaybackProgress(15, 60)).toBe(25);
    expect(getMediaPreviewPlaybackProgress(-5, 60)).toBe(0);
    expect(getMediaPreviewPlaybackProgress(90, 60)).toBe(100);
  });

  test("seeks video preview time and clamps within duration bounds", () => {
    expect(getNextVideoPreviewCurrentTime(10, 60, "backward")).toBe(5);
    expect(getNextVideoPreviewCurrentTime(10, 60, "forward")).toBe(15);
    expect(getNextVideoPreviewCurrentTime(2, 60, "backward")).toBe(0);
    expect(getNextVideoPreviewCurrentTime(58, 60, "forward")).toBe(60);
  });

  test("clamps media preview progress ratio into 0-1 range", () => {
    expect(clampMediaPreviewProgressRatio(-0.2)).toBe(0);
    expect(clampMediaPreviewProgressRatio(0.4)).toBe(0.4);
    expect(clampMediaPreviewProgressRatio(1.6)).toBe(1);
  });

  test("maps progress ratio to video preview current time", () => {
    expect(getVideoPreviewCurrentTimeFromProgressRatio(0, 0.4)).toBe(0);
    expect(getVideoPreviewCurrentTimeFromProgressRatio(120, 0.25)).toBe(30);
    expect(getVideoPreviewCurrentTimeFromProgressRatio(120, -0.1)).toBe(0);
    expect(getVideoPreviewCurrentTimeFromProgressRatio(120, 1.2)).toBe(120);
  });

  test("finds media preview source message and part by source coordinates", () => {
    expect(
      findMediaPreviewSource(
        [
          {
            id: "message-1",
            parts: [
              { position: 0, partType: "text" },
              { position: 1, partType: "image" },
            ],
          },
          {
            id: "message-2",
            parts: [{ position: 0, partType: "video" }],
          },
        ],
        {
          messageId: "message-1",
          partPosition: 1,
        },
      ),
    ).toEqual({
      message: {
        id: "message-1",
        parts: [
          { position: 0, partType: "text" },
          { position: 1, partType: "image" },
        ],
      },
      part: {
        position: 1,
        partType: "image",
      },
    });
  });

  test("returns null when media preview source no longer exists", () => {
    expect(
      findMediaPreviewSource(
        [
          {
            id: "message-1",
            parts: [{ position: 0, partType: "image" }],
          },
        ],
        {
          messageId: "message-2",
          partPosition: 0,
        },
      ),
    ).toBeNull();
  });
});
