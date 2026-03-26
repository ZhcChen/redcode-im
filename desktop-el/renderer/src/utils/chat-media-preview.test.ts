import { describe, expect, test } from "bun:test";
import {
  clampImagePreviewScale,
  getNextImagePreviewScaleFromWheel,
  IMAGE_PREVIEW_MAX_SCALE,
  IMAGE_PREVIEW_MIN_SCALE,
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
});
