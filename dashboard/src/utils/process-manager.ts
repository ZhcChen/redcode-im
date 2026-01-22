import type { Subprocess } from "bun";

export class ProcessManager {
  private processes: Map<string, Subprocess> = new Map();

  register(id: string, proc: Subprocess) {
    this.processes.set(id, proc);
  }

  unregister(id: string) {
    this.processes.delete(id);
  }

  kill(id: string): boolean {
    const proc = this.processes.get(id);
    if (proc) {
      proc.kill();
      this.processes.delete(id);
      return true;
    }
    return false;
  }

  list(): string[] {
    return Array.from(this.processes.keys());
  }

  isRunning(id: string): boolean {
    return this.processes.has(id);
  }
}
