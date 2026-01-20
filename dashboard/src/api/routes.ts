import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import path from "path";
import { commands, type CommandId } from "./commands";
import { ProcessManager } from "../utils/process-manager";

const ROOT_DIR = path.resolve(import.meta.dir, "../../../");

export const apiRoutes = new Hono();

const processManager = new ProcessManager();

// 获取所有命令列表
apiRoutes.get("/commands", (c) => {
  const list = Object.entries(commands).map(([id, cmd]) => ({
    id,
    name: cmd.name,
    description: cmd.description,
    group: cmd.group,
    section: cmd.section,
    type: cmd.type,
  }));
  return c.json({ commands: list });
});

// 执行命令（SSE 流式输出）
apiRoutes.get("/run/:commandId", async (c) => {
  const commandId = c.req.param("commandId") as CommandId;
  const command = commands[commandId];

  if (!command) {
    return c.json({ error: "Command not found" }, 404);
  }

  return streamSSE(c, async (stream) => {
    const abortController = new AbortController();

    c.req.raw.signal.addEventListener("abort", () => {
      abortController.abort();
    });

    try {
      await stream.writeSSE({ data: JSON.stringify({ type: "start", command: command.name }) });

      const proc = Bun.spawn(command.cmd, {
        cwd: command.cwd,
        env: { ...process.env, ...command.env },
        stdout: "pipe",
        stderr: "pipe",
      });

      processManager.register(commandId, proc);

      const decoder = new TextDecoder();

      // 读取 stdout
      const readStream = async (
        reader: ReadableStreamDefaultReader<Uint8Array>,
        type: "stdout" | "stderr"
      ) => {
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const text = decoder.decode(value);
            await stream.writeSSE({ data: JSON.stringify({ type, text }) });
          }
        } catch {
          // stream closed
        }
      };

      await Promise.all([
        readStream(proc.stdout.getReader(), "stdout"),
        readStream(proc.stderr.getReader(), "stderr"),
      ]);

      const exitCode = await proc.exited;
      processManager.unregister(commandId);

      await stream.writeSSE({
        data: JSON.stringify({ type: "exit", code: exitCode }),
      });
    } catch (err: any) {
      await stream.writeSSE({
        data: JSON.stringify({ type: "error", message: err.message }),
      });
    }
  });
});

// 停止命令
apiRoutes.post("/stop/:commandId", async (c) => {
  const commandId = c.req.param("commandId") as CommandId;
  const killed = processManager.kill(commandId);
  return c.json({ success: killed });
});

// 获取运行中的进程
apiRoutes.get("/processes", (c) => {
  return c.json({ processes: processManager.list() });
});

// 获取服务状态
apiRoutes.get("/status", async (c) => {
  const statuses: Record<string, { running: boolean; port?: number }> = {};

  // 检查 Docker 容器状态
  const checkDocker = async (name: string) => {
    try {
      const proc = Bun.spawn(["docker", "inspect", "-f", "{{.State.Running}}", name], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const output = await new Response(proc.stdout).text();
      return output.trim() === "true";
    } catch {
      return false;
    }
  };

  // 检查端口是否监听
  const checkPort = async (port: number) => {
    try {
      const proc = Bun.spawn(["lsof", "-i", `:${port}`, "-t"], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const output = await new Response(proc.stdout).text();
      return output.trim().length > 0;
    } catch {
      return false;
    }
  };

  statuses.postgres = { running: await checkDocker("redcode-postgres") };
  statuses.redisSession = { running: await checkDocker("redcode-redis-session") };
  statuses.redisCache = { running: await checkDocker("redcode-redis-cache") };
  statuses.backend = { running: await checkPort(8010), port: 8010 };

  return c.json({ statuses });
});

// 获取测试覆盖率数据
apiRoutes.get("/coverage", async (c) => {
  const jsonPath = path.join(ROOT_DIR, "docs/reports/api-test-coverage.json");

  try {
    const file = Bun.file(jsonPath);
    if (!(await file.exists())) {
      return c.json({
        error: "Coverage data not found. Run 'Update Coverage' command first.",
        exists: false
      }, 404);
    }

    const data = await file.json();
    return c.json(data);
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// 获取代码覆盖率数据（Rust 行覆盖率 + 测试统计）
apiRoutes.get("/code-coverage", async (c) => {
  const jsonPath = path.join(ROOT_DIR, "docs/reports/test-coverage.json");

  try {
    const file = Bun.file(jsonPath);
    if (!(await file.exists())) {
      return c.json({
        error: "Code coverage data not found. Run './tests/update-coverage-json.sh' first.",
        exists: false
      }, 404);
    }

    const data = await file.json();
    return c.json(data);
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// 获取综合覆盖率数据（合并 API 覆盖率和代码覆盖率）
apiRoutes.get("/coverage/all", async (c) => {
  const apiCoveragePath = path.join(ROOT_DIR, "docs/reports/api-test-coverage.json");
  const codeCoveragePath = path.join(ROOT_DIR, "docs/reports/test-coverage.json");

  const result: Record<string, any> = {
    updatedAt: new Date().toISOString(),
  };

  // 读取 API 覆盖率
  try {
    const apiFile = Bun.file(apiCoveragePath);
    if (await apiFile.exists()) {
      result.apiCoverage = await apiFile.json();
    }
  } catch {}

  // 读取代码覆盖率
  try {
    const codeFile = Bun.file(codeCoveragePath);
    if (await codeFile.exists()) {
      result.codeCoverage = await codeFile.json();
    }
  } catch {}

  return c.json(result);
});
