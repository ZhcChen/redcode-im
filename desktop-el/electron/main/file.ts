import { createWriteStream } from "node:fs";
import { mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { shell } from "electron";
import type {
  DesktopFileSaveFromURLOptions,
  DesktopFileSaveFromURLResult
} from "../preload/types.js";

export interface DesktopFileService {
  saveFromURL(options: DesktopFileSaveFromURLOptions): Promise<DesktopFileSaveFromURLResult>;
  openPath(targetPath: string): Promise<void>;
}

export const createFileService = (): DesktopFileService => ({
  async saveFromURL(options) {
    const url = options.url.trim();
    const filePath = options.filePath.trim();
    if (!url) {
      throw new Error("download url is required");
    }
    if (!filePath) {
      throw new Error("file path is required");
    }

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`download failed with status ${response.status}`);
    }
    if (!response.body) {
      throw new Error("download response body is empty");
    }

    await mkdir(dirname(filePath), { recursive: true });
    const readable = Readable.fromWeb(response.body as globalThis.ReadableStream<Uint8Array>);
    const writable = createWriteStream(filePath);
    await pipeline(readable, writable);

    return { filePath };
  },

  async openPath(targetPath) {
    const filePath = targetPath.trim();
    if (!filePath) {
      throw new Error("file path is required");
    }

    const errorMessage = await shell.openPath(filePath);
    if (errorMessage) {
      throw new Error(errorMessage);
    }
  }
});
