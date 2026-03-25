import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
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
});
