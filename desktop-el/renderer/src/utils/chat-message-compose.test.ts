import { describe, expect, test } from "bun:test";
import type { ChatMessagePartInput } from "@/api/chat";
import { buildOutgoingChatMessageParts, uploadAttachmentsAndBuildParts } from "./chat-message-compose";

describe("chat message compose helpers", () => {
  test("builds outgoing parts with trimmed text first and attachments after it", () => {
    const attachments: ChatMessagePartInput[] = [
      {
        type: "image",
        key: "attachments/demo-1.png",
        name: "demo-1.png",
        mime: "image/png",
        size: 128
      },
      {
        type: "file",
        key: "attachments/spec.pdf",
        name: "spec.pdf",
        mime: "application/pdf",
        size: 256
      }
    ];

    expect(
      buildOutgoingChatMessageParts({
        text: "  hello desktop-el  ",
        attachments
      })
    ).toEqual([
      { type: "text", text: "hello desktop-el" },
      attachments[0],
      attachments[1]
    ]);

    expect(
      buildOutgoingChatMessageParts({
        text: "   ",
        attachments
      })
    ).toEqual(attachments);
  });

  test("uploads multiple attachments sequentially and reports aggregate progress", async () => {
    const files = [
      new File(["img"], "first.png", { type: "image/png" }),
      new File(["pdf-payload"], "second.pdf", { type: "application/pdf" })
    ];
    const perFileEvents: Array<{ index: number; progress: number }> = [];
    const overallProgressEvents: number[] = [];
    const uploadedFileNames: string[] = [];

    const parts = await uploadAttachmentsAndBuildParts(
      {
        roomId: "room-2",
        files,
        onFileProgress: (index, progress) => {
          perFileEvents.push({ index, progress });
        },
        onOverallProgress: (progress) => {
          overallProgressEvents.push(progress);
        }
      },
      {
        uploadAttachmentAndBuildPart: async ({ roomId, file, onProgress }) => {
          expect(roomId).toBe("room-2");
          uploadedFileNames.push(file.name);
          onProgress?.(0.25);
          onProgress?.(1);
          return file.name === "first.png"
            ? {
                type: "image",
                key: "attachments/first.png",
                name: file.name,
                mime: file.type,
                size: file.size
              }
            : {
                type: "file",
                key: "attachments/second.pdf",
                name: file.name,
                mime: file.type,
                size: file.size
              };
        }
      }
    );

    expect(parts).toEqual([
      {
        type: "image",
        key: "attachments/first.png",
        name: "first.png",
        mime: "image/png",
        size: files[0].size
      },
      {
        type: "file",
        key: "attachments/second.pdf",
        name: "second.pdf",
        mime: "application/pdf",
        size: files[1].size
      }
    ]);
    expect(uploadedFileNames).toEqual(["first.png", "second.pdf"]);
    expect(perFileEvents).toEqual([
      { index: 0, progress: 0.25 },
      { index: 0, progress: 1 },
      { index: 1, progress: 0.25 },
      { index: 1, progress: 1 }
    ]);
    expect(overallProgressEvents).toEqual([0.125, 0.5, 0.625, 1]);
  });
});
