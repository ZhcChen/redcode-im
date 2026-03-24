import { describe, expect, test } from "bun:test";
import {
  AVATAR_ALLOWED_MIME_TYPES,
  AVATAR_INPUT_ACCEPT,
  AVATAR_MAX_SIZE_BYTES,
  validateAvatarFile
} from "./user-avatar-upload";

describe("user avatar upload helpers", () => {
  test("accept list matches allowed mime types", () => {
    expect(AVATAR_INPUT_ACCEPT).toBe(AVATAR_ALLOWED_MIME_TYPES.join(","));
  });

  test("allows supported avatar file within size limit", () => {
    const file = new File(["avatar"], "profile.png", { type: "image/png" });

    expect(validateAvatarFile(file)).toBeNull();
  });

  test("rejects unsupported avatar mime type", () => {
    const file = new File(["avatar"], "profile.bmp", { type: "image/bmp" });

    expect(validateAvatarFile(file)).toBe("仅支持 PNG、JPG、WEBP、GIF、HEIC、HEIF、SVG 格式头像");
  });

  test("rejects avatar file larger than backend limit", () => {
    const oversizedFile = {
      type: "image/png",
      size: AVATAR_MAX_SIZE_BYTES + 1
    };

    expect(validateAvatarFile(oversizedFile)).toBe("头像大小不能超过 5MB");
  });
});
