import { describe, expect, test } from "bun:test";
import { resendLocalMessage } from "./chat-message-retry";

describe("chat message retry helpers", () => {
  test("reuses sendTextMessage for text-only retry payloads", async () => {
    const calls: string[] = [];
    const response = await resendLocalMessage(
      {
        roomId: "room-2",
        currentUserId: "u-1",
        retryPayload: {
          content: "hello again",
          quotedMessageId: "msg-quoted-1",
          attachments: [],
        },
      },
      {
        sendTextMessage: async (params) => {
          calls.push("sendTextMessage");
          expect(params).toEqual({
            roomId: "room-2",
            content: "hello again",
            quotedMessageId: "msg-quoted-1",
            currentUserId: "u-1",
          });
          return {
            code: 0,
            success: true,
            message: "",
            data: null,
          };
        },
        sendMessage: async () => {
          throw new Error("sendMessage should not run for text-only retry");
        },
      },
    );

    expect(calls).toEqual(["sendTextMessage"]);
    expect(response.success).toBeTrue();
  });

  test("reuploads attachments and sends mixed parts for attachment retry payloads", async () => {
    const imageFile = new File(["image"], "cover.png", {
      type: "image/png",
    });
    const pdfFile = new File(["pdf"], "spec.pdf", {
      type: "application/pdf",
    });
    const calls: string[] = [];

    const response = await resendLocalMessage(
      {
        roomId: "room-9",
        currentUserId: "u-1",
        retryPayload: {
          content: "请重新发送",
          quotedMessageId: null,
          attachments: [imageFile, pdfFile],
        },
      },
      {
        sendTextMessage: async () => {
          throw new Error("sendTextMessage should not run for attachment retry");
        },
        uploadAttachmentsAndBuildParts: async ({ roomId, files }) => {
          calls.push("uploadAttachmentsAndBuildParts");
          expect(roomId).toBe("room-9");
          expect(files).toEqual([imageFile, pdfFile]);
          return [
            {
              type: "image",
              key: "attachments/cover.png",
              name: "cover.png",
              mime: "image/png",
              size: imageFile.size,
            },
            {
              type: "file",
              key: "attachments/spec.pdf",
              name: "spec.pdf",
              mime: "application/pdf",
              size: pdfFile.size,
            },
          ];
        },
        sendMessage: async (params) => {
          calls.push("sendMessage");
          expect(params.roomId).toBe("room-9");
          expect(params.quotedMessageId).toBeUndefined();
          expect(params.currentUserId).toBe("u-1");
          expect(params.parts).toEqual([
            {
              type: "text",
              text: "请重新发送",
            },
            {
              type: "image",
              key: "attachments/cover.png",
              name: "cover.png",
              mime: "image/png",
              size: imageFile.size,
            },
            {
              type: "file",
              key: "attachments/spec.pdf",
              name: "spec.pdf",
              mime: "application/pdf",
              size: pdfFile.size,
            },
          ]);
          return {
            code: 0,
            success: true,
            message: "",
            data: null,
          };
        },
      },
    );

    expect(calls).toEqual([
      "uploadAttachmentsAndBuildParts",
      "sendMessage",
    ]);
    expect(response.success).toBeTrue();
  });
});
