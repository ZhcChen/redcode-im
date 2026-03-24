import { describe, expect, test } from "bun:test";
import type { DirectUploadSignatureInfo } from "@/api/chat";
import { uploadAttachmentAndBuildPart } from "./chat-attachment-send";

describe("uploadAttachmentAndBuildPart", () => {
  test("uploads direct attachment, commits it, and returns message part", async () => {
    const file = new File(["demo-file"], "design.png", { type: "image/png" });
    const progressUpdates: number[] = [];
    const calls: string[] = [];

    const part = await uploadAttachmentAndBuildPart(
      {
        roomId: "room-direct",
        file,
        onProgress: (progress) => progressUpdates.push(progress)
      },
      {
        determineAttachmentMeta: async () => ({
          partType: "image",
          mime: "image/png",
          width: 1280,
          height: 720,
          durationMs: null,
          thumbnailKey: null
        }),
        computeFileHash: async () => ({
          hashValue: "hash-direct",
          hashAlg: 2
        }),
        requestAttachmentSignature: async (params) => {
          expect(params).toEqual({
            roomId: "room-direct",
            partType: "image",
            fileName: "design.png",
            contentType: "image/png",
            fileSize: file.size,
            hashValue: "hash-direct",
            hashAlg: 2
          });
          calls.push("request-direct-signature");
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              key: "attachments/direct/design.png",
              signature: {
                url: "https://upload.example.com/direct",
                method: "PUT",
                headers: {
                  Authorization: "signed-direct"
                },
                key: "attachments/direct/design.png"
              }
            }
          };
        },
        initiateAttachmentMultipartUpload: async () => {
          throw new Error("multipart should not run for direct upload");
        },
        uploadWithSignature: async (signature, uploadFile, onProgress) => {
          expect(signature.url).toBe("https://upload.example.com/direct");
          expect(uploadFile).toBe(file);
          calls.push("upload-direct");
          onProgress?.(0.25);
          onProgress?.(1);
        },
        uploadMultipartWithSession: async () => {
          throw new Error("multipart uploader should not run for direct upload");
        },
        commitAttachmentUpload: async (params) => {
          expect(params).toEqual({
            roomId: "room-direct",
            key: "attachments/direct/design.png",
            fileSize: file.size,
            hashValue: "hash-direct",
            hashAlg: 2
          });
          calls.push("commit-attachment");
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        }
      }
    );

    expect(part).toEqual({
      type: "image",
      key: "attachments/direct/design.png",
      name: "design.png",
      mime: "image/png",
      size: file.size,
      width: 1280,
      height: 720
    });
    expect(progressUpdates).toEqual([0.25, 1]);
    expect(calls).toEqual(["request-direct-signature", "upload-direct", "commit-attachment"]);
  });

  test("uploads multipart attachment and commits uploaded file", async () => {
    const file = new File(["multipart-demo"], "archive.zip", { type: "application/zip" });
    const partSignatures: number[] = [];
    const multipartPartCommits: Array<{ partNumber: number; etag: string }> = [];
    const progressUpdates: number[] = [];
    let completedParts: Array<{ partNumber: number; etag: string }> | null = null;
    let abortCalled = false;
    let commitCalled = false;

    const signature: DirectUploadSignatureInfo = {
      url: "https://upload.example.com/part-1",
      method: "PUT",
      headers: {
        Authorization: "multipart-signature"
      },
      key: "attachments/multipart/archive.zip"
    };

    const part = await uploadAttachmentAndBuildPart(
      {
        roomId: "room-multipart",
        file,
        multipartThresholdBytes: 1,
        onProgress: (progress) => progressUpdates.push(progress)
      },
      {
        determineAttachmentMeta: async () => ({
          partType: "file",
          mime: "application/zip",
          width: null,
          height: null,
          durationMs: null,
          thumbnailKey: null
        }),
        computeFileHash: async () => ({
          hashValue: "hash-multipart",
          hashAlg: 2
        }),
        requestAttachmentSignature: async () => {
          throw new Error("direct signature should not run for multipart upload");
        },
        initiateAttachmentMultipartUpload: async (params) => {
          expect(params).toEqual({
            roomId: "room-multipart",
            partType: "file",
            fileName: "archive.zip",
            contentType: "application/zip",
            fileSize: file.size,
            hashValue: "hash-multipart",
            hashAlg: 2
          });
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              key: "attachments/multipart/archive.zip",
              sessionId: "session-1",
              partSize: 4,
              totalParts: 2
            }
          };
        },
        generateMultipartPartSignature: async ({ sessionId, partNumber }) => {
          expect(sessionId).toBe("session-1");
          partSignatures.push(partNumber);
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              signature: {
                ...signature,
                url: `https://upload.example.com/part-${partNumber}`
              }
            }
          };
        },
        commitMultipartPart: async ({ sessionId, partNumber, etag }) => {
          expect(sessionId).toBe("session-1");
          multipartPartCommits.push({ partNumber, etag });
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        },
        completeMultipartUpload: async ({ sessionId, parts }) => {
          expect(sessionId).toBe("session-1");
          completedParts = parts;
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        },
        abortMultipartUpload: async () => {
          abortCalled = true;
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        },
        uploadWithSignature: async () => {
          throw new Error("direct uploader should not run for multipart upload");
        },
        uploadMultipartWithSession: async ({ file: uploadFile, partSize, totalParts, callbacks, onProgress }) => {
          expect(uploadFile).toBe(file);
          expect(partSize).toBe(4);
          expect(totalParts).toBe(2);
          const firstSignature = await callbacks.generatePartSignature(1);
          const secondSignature = await callbacks.generatePartSignature(2);
          expect(firstSignature.url).toBe("https://upload.example.com/part-1");
          expect(secondSignature.url).toBe("https://upload.example.com/part-2");
          await callbacks.commitPart(1, "etag-1");
          await callbacks.commitPart(2, "etag-2");
          await callbacks.completeUpload([
            { partNumber: 1, etag: "etag-1" },
            { partNumber: 2, etag: "etag-2" }
          ]);
          onProgress?.(0.5);
          onProgress?.(1);
        },
        commitAttachmentUpload: async (params) => {
          commitCalled = true;
          expect(params).toEqual({
            roomId: "room-multipart",
            key: "attachments/multipart/archive.zip",
            fileSize: file.size,
            hashValue: "hash-multipart",
            hashAlg: 2
          });
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        }
      }
    );

    expect(part).toEqual({
      type: "file",
      key: "attachments/multipart/archive.zip",
      name: "archive.zip",
      mime: "application/zip",
      size: file.size
    });
    expect(partSignatures).toEqual([1, 2]);
    expect(multipartPartCommits).toEqual([
      { partNumber: 1, etag: "etag-1" },
      { partNumber: 2, etag: "etag-2" }
    ]);
    expect(completedParts).toEqual([
      { partNumber: 1, etag: "etag-1" },
      { partNumber: 2, etag: "etag-2" }
    ]);
    expect(progressUpdates).toEqual([0.5, 1]);
    expect(commitCalled).toBe(true);
    expect(abortCalled).toBe(false);
  });

  test("reuses deduplicated attachment key without upload or commit", async () => {
    const file = new File(["reuse"], "spec.pdf", { type: "application/pdf" });
    let uploadCalled = false;
    let commitCalled = false;

    const part = await uploadAttachmentAndBuildPart(
      {
        roomId: "room-reuse",
        file
      },
      {
        determineAttachmentMeta: async () => ({
          partType: "file",
          mime: "application/pdf",
          width: null,
          height: null,
          durationMs: null,
          thumbnailKey: null
        }),
        computeFileHash: async () => ({
          hashValue: "hash-reused",
          hashAlg: 2
        }),
        requestAttachmentSignature: async () => ({
          code: 0,
          success: true,
          message: "",
          data: {
            key: "attachments/reused/spec.pdf",
            signature: null
          }
        }),
        initiateAttachmentMultipartUpload: async () => {
          throw new Error("multipart should not run for reused attachment");
        },
        uploadWithSignature: async () => {
          uploadCalled = true;
        },
        uploadMultipartWithSession: async () => {
          uploadCalled = true;
        },
        commitAttachmentUpload: async () => {
          commitCalled = true;
          return {
            code: 0,
            success: true,
            message: "",
            data: {
              success: true,
              message: ""
            }
          };
        }
      }
    );

    expect(part).toEqual({
      type: "file",
      key: "attachments/reused/spec.pdf",
      name: "spec.pdf",
      mime: "application/pdf",
      size: file.size
    });
    expect(uploadCalled).toBe(false);
    expect(commitCalled).toBe(false);
  });
});
