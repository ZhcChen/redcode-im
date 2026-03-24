import { describe, expect, test } from "bun:test";
import {
  buildAttachmentPartInput,
  buildDirectUploadHeaders,
  inferAttachmentPartType
} from "./chat-attachment-upload";

describe("chat attachment upload helpers", () => {
  test("infers attachment part type from mime and filename", () => {
    expect(inferAttachmentPartType({ type: "image/png", name: "demo.png" })).toBe("image");
    expect(inferAttachmentPartType({ type: "video/mp4", name: "demo.mp4" })).toBe("video");
    expect(inferAttachmentPartType({ type: "audio/mpeg", name: "demo.mp3" })).toBe("audio");
    expect(inferAttachmentPartType({ type: "", name: "demo.pdf" })).toBe("file");
  });

  test("drops forbidden upload headers and keeps content type fallback", () => {
    const file = new File(["demo"], "demo.pdf", { type: "application/pdf" });

    expect(
      buildDirectUploadHeaders(
        {
          Host: "upload.example.com",
          "Content-Length": "4",
          Authorization: "sign token"
        },
        file
      )
    ).toEqual({
      Authorization: "sign token",
      "Content-Type": "application/pdf"
    });
  });

  test("builds attachment message part payload from file metadata", () => {
    const file = new File(["demo"], "demo.png", { type: "image/png" });

    expect(
      buildAttachmentPartInput(
        {
          partType: "image",
          mime: "image/png",
          width: 320,
          height: 240,
          durationMs: null,
          thumbnailKey: null
        },
        "messages/room-2/images_demo.png",
        file
      )
    ).toEqual({
      type: "image",
      key: "messages/room-2/images_demo.png",
      name: "demo.png",
      mime: "image/png",
      size: 4,
      width: 320,
      height: 240
    });
  });
});
