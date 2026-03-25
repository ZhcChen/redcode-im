import { createWriteStream } from "node:fs";
import { access, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname } from "node:path";
import { isAbsolute, join, normalize } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { pathToFileURL } from "node:url";
import { shell } from "electron";
import type {
  DesktopFileCacheFromURLOptions,
  DesktopFileCachePathOptions,
  DesktopFileCachePathResult,
  DesktopFileSaveFromURLOptions,
  DesktopFileSaveFromURLResult
} from "../preload/types.js";

export interface DesktopFileService {
  saveFromURL(options: DesktopFileSaveFromURLOptions): Promise<DesktopFileSaveFromURLResult>;
  getCachedPath(options: DesktopFileCachePathOptions): Promise<DesktopFileCachePathResult | null>;
  cacheFromURL(options: DesktopFileCacheFromURLOptions): Promise<DesktopFileCachePathResult>;
  openPath(targetPath: string): Promise<void>;
}

export interface CreateFileServiceOptions {
  cacheRootDir?: string;
}

export const createFileService = (
  options: CreateFileServiceOptions = {},
): DesktopFileService => {
  const cacheRootDir = options.cacheRootDir?.trim() || join(tmpdir(), "desktop-el-attachment-cache");

  return {
    async saveFromURL(options) {
      const filePath = options.filePath.trim();
      await downloadToPath(options.url, filePath);
      return { filePath };
    },

    async getCachedPath(options) {
      const filePath = resolveCacheFilePath(cacheRootDir, options.relativePath);
      if (!(await fileExists(filePath))) {
        return null;
      }
      return {
        filePath,
        fileUrl: pathToFileURL(filePath).toString(),
      };
    },

    async cacheFromURL(options) {
      const filePath = resolveCacheFilePath(cacheRootDir, options.relativePath);
      if (!(await fileExists(filePath))) {
        await downloadToPath(options.url, filePath);
      }
      return {
        filePath,
        fileUrl: pathToFileURL(filePath).toString(),
      };
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
  };
};

const downloadToPath = async (urlInput: string, filePathInput: string): Promise<void> => {
  const url = urlInput.trim();
  const filePath = filePathInput.trim();
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
};

const resolveCacheFilePath = (cacheRootDir: string, relativePath: string): string => {
  const normalizedRelativePath = normalize(relativePath.trim()).replace(/^([/\\])+/, "");
  if (!normalizedRelativePath) {
    throw new Error("relative path is required");
  }
  if (isAbsolute(normalizedRelativePath) || normalizedRelativePath.startsWith("..")) {
    throw new Error("relative path must stay within cache root");
  }
  return join(cacheRootDir, normalizedRelativePath);
};

const fileExists = async (targetPath: string): Promise<boolean> => {
  try {
    await access(targetPath);
    return true;
  } catch {
    return false;
  }
};

export const __internal = {
  resolveCacheFilePath,
};
