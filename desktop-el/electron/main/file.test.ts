import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { createServer, type Server } from "node:http";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const { createFileService } = await import("./file.js");

describe("createFileService", () => {
  let server: Server | undefined;
  let baseURL = "";
  let tempDir = "";

  beforeEach(async () => {
    resetElectronMockState();
    tempDir = await mkdtemp(join(tmpdir(), "desktop-el-file-test-"));
    server = createServer((_, response) => {
      response.writeHead(200, {
        "Content-Type": "text/plain; charset=utf-8"
      });
      response.end("desktop-el attachment");
    });

    await new Promise<void>((resolve) => {
      server!.listen(0, "127.0.0.1", () => {
        const address = server!.address();
        if (!address || typeof address === "string") {
          throw new Error("server address unavailable");
        }
        baseURL = `http://127.0.0.1:${address.port}`;
        resolve();
      });
    });
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      if (!server) {
        resolve();
        return;
      }
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    server = undefined;
    if (tempDir) {
      await rm(tempDir, { recursive: true, force: true });
      tempDir = "";
    }
  });

  test("downloads a remote file into the requested local path", async () => {
    const service = createFileService();
    const targetPath = join(tempDir, "downloads", "demo.txt");

    const result = await service.saveFromURL({
      url: `${baseURL}/attachment.txt`,
      filePath: targetPath
    });

    expect(result).toEqual({ filePath: targetPath });
    expect(await readFile(targetPath, "utf8")).toBe("desktop-el attachment");
  });

  test("opens the saved local path through electron shell", async () => {
    const service = createFileService();

    await service.openPath("/tmp/demo.txt");

    expect(electronMockState.openPathCalls).toEqual(["/tmp/demo.txt"]);
  });

  test("returns null for cache miss and caches remote file into cache directory", async () => {
    const cacheRootDir = join(tempDir, "cache-root");
    const service = createFileService({ cacheRootDir }) as typeof createFileService extends (
      ...args: any[]
    ) => infer T
      ? T & {
          getCachedPath?: (options: { relativePath: string }) => Promise<{
            filePath: string;
            fileUrl: string;
          } | null>;
          cacheFromURL?: (options: {
            url: string;
            relativePath: string;
          }) => Promise<{
            filePath: string;
            fileUrl: string;
          }>;
        }
      : never;

    expect(typeof service.getCachedPath).toBe("function");
    expect(typeof service.cacheFromURL).toBe("function");
    if (!service.getCachedPath || !service.cacheFromURL) {
      return;
    }

    const relativePath = "rooms/room-1/messages/demo.txt";
    const expectedPath = join(cacheRootDir, relativePath);
    const expectedUrl = pathToFileURL(expectedPath).toString();

    await expect(
      service.getCachedPath({ relativePath }),
    ).resolves.toBeNull();

    await expect(
      service.cacheFromURL({
        url: `${baseURL}/cached-demo.txt`,
        relativePath,
      }),
    ).resolves.toEqual({
      filePath: expectedPath,
      fileUrl: expectedUrl,
    });

    await expect(readFile(expectedPath, "utf8")).resolves.toBe(
      "desktop-el attachment",
    );

    await expect(
      service.getCachedPath({ relativePath }),
    ).resolves.toEqual({
      filePath: expectedPath,
      fileUrl: expectedUrl,
    });
  });
});
