import { describe, expect, test } from "bun:test";
import {
  clampImagePreviewScale,
  getNextImagePreviewRotation,
  getNextImagePreviewScaleFromWheel,
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
});
