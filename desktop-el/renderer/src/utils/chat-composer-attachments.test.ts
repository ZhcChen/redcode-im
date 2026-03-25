import { describe, expect, test } from "bun:test";
import {
  buildPendingAttachmentNotice,
  buildPendingComposerAttachments,
  hasFileTransfer,
} from "./chat-composer-attachments";

describe("chat composer attachment helpers", () => {
  test("detects file transfer entries from drag payload", () => {
    expect(hasFileTransfer({ types: ["Files", "text/plain"] })).toBe(true);
    expect(hasFileTransfer({ types: ["text/plain"] })).toBe(false);
    expect(hasFileTransfer(null)).toBe(false);
  });

  test("builds pending composer attachments with stable ids", () => {
    const files = [
      { name: "设计稿.png", size: 1024 },
      { name: "录音.m4a", size: 2048 },
    ];

    expect(buildPendingComposerAttachments(files, 1700000000000)).toEqual([
      {
        id: "1700000000000-0-设计稿.png-1024",
        file: files[0],
      },
      {
        id: "1700000000000-1-录音.m4a-2048",
        file: files[1],
      },
    ]);
  });

  test("builds pick and drop notices for attachments", () => {
    expect(
      buildPendingAttachmentNotice([{ name: "需求文档.pdf" }], "pick"),
    ).toBe("已添加附件 需求文档.pdf，可直接发送，也可继续输入文本混发。");
    expect(
      buildPendingAttachmentNotice(
        [{ name: "a.png" }, { name: "b.png" }],
        "drop",
      ),
    ).toBe("已通过拖拽添加 2 个附件，可直接发送，也可继续输入文本混发。");
  });
});
