import { afterEach, beforeEach, describe, expect, mock, test } from "bun:test";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";

class FakeChildProcess extends EventEmitter {
  readonly stdin = new PassThrough();
  readonly stdout = new PassThrough();
  readonly stderr = new PassThrough();
  readonly pid = 4242;
  readonly stdinChunks: string[] = [];
  killed = false;

  constructor() {
    super();
    this.stdin.on("data", (chunk) => {
      this.stdinChunks.push(chunk.toString());
    });
  }

  kill(): boolean {
    this.killed = true;
    this.emit("exit", 0, null);
    return true;
  }
}

let fakeProcess: FakeChildProcess | undefined;
const spawnCalls: Array<{ command: string; args: string[]; cwd?: string }> = [];

mock.module("node:child_process", () => ({
  spawn: (command: string, args: string[], options: { cwd?: string }) => {
    fakeProcess = new FakeChildProcess();
    spawnCalls.push({ command, args, cwd: options.cwd });
    return fakeProcess;
  }
}));

const { GoCoreBridge } = await import("./go-core.js");

describe("GoCoreBridge", () => {
  beforeEach(() => {
    fakeProcess = undefined;
    spawnCalls.length = 0;
  });

  afterEach(async () => {
    await fakeProcess?.stdin.end();
    await fakeProcess?.stdout.end();
    await fakeProcess?.stderr.end();
  });

  test("starts process, waits for core.ready, and resolves request responses", async () => {
    const bridge = new GoCoreBridge({
      cwd: "/tmp/desktop-el",
      command: "go",
      args: ["run", "./cmd/desktop-el-core"]
    });

    const startPromise = bridge.start();

    expect(spawnCalls).toEqual([
      {
        command: "go",
        args: ["run", "./cmd/desktop-el-core"],
        cwd: "/tmp/desktop-el"
      }
    ]);

    fakeProcess?.stdout.write("{\"type\":\"event\",\"event\":\"core.ready\",\"data\":{\"pid\":4242}}\n");
    await startPromise;

    const sendPromise = bridge.send({
      type: "request",
      id: "req-1",
      method: "core.ping"
    });

    await Promise.resolve();

    const written = fakeProcess?.stdinChunks.join("") ?? "";
    expect(written).toContain("\"id\":\"req-1\"");
    expect(written).toContain("\"method\":\"core.ping\"");

    fakeProcess?.stdout.write("{\"type\":\"response\",\"id\":\"req-1\",\"result\":{\"ok\":true}}\n");

    await expect(sendPromise).resolves.toEqual({
      type: "response",
      id: "req-1",
      result: { ok: true }
    });

    await bridge.stop();
    expect(fakeProcess?.killed).toBeTrue();
  });
});
