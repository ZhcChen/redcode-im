import path from "path";

const ROOT_DIR = path.resolve(import.meta.dir, "../../../");
const BACKEND_DIR = path.join(ROOT_DIR, "backend");
const TESTS_DIR = path.join(ROOT_DIR, "tests");

export type CommandCategory = "service" | "database" | "test" | "build" | "quality";
export type CommandType = "oneshot" | "daemon";

export interface Command {
  name: string;
  description: string;
  category: CommandCategory;
  type: CommandType;
  cmd: string[];
  cwd: string;
  env?: Record<string, string>;
}

export const commands = {
  // ========== 服务管理 ==========
  "docker:up": {
    name: "启动 Docker 服务",
    description: "启动 PostgreSQL + Redis 开发环境",
    category: "service",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "up", "-d", "postgres", "redis-session", "redis-cache"],
    cwd: BACKEND_DIR,
  },
  "docker:down": {
    name: "停止 Docker 服务",
    description: "停止所有 Docker 容器",
    category: "service",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "down", "--remove-orphans"],
    cwd: BACKEND_DIR,
  },
  "docker:restart": {
    name: "重启 Docker 服务",
    description: "重启 PostgreSQL + Redis",
    category: "service",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "restart"],
    cwd: BACKEND_DIR,
  },
  "docker:logs": {
    name: "查看 Docker 日志",
    description: "查看容器日志（最近 100 行）",
    category: "service",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "logs", "--tail=100", "-f"],
    cwd: BACKEND_DIR,
  },
  "backend:run": {
    name: "启动后端服务",
    description: "cargo run 启动 Rust 后端",
    category: "service",
    type: "daemon",
    cmd: ["cargo", "run"],
    cwd: BACKEND_DIR,
    env: { RUST_LOG: "info" },
  },
  "backend:watch": {
    name: "后端热重载",
    description: "cargo watch 监听文件变化自动重启",
    category: "service",
    type: "daemon",
    cmd: ["cargo", "watch", "-x", "run"],
    cwd: BACKEND_DIR,
    env: { RUST_LOG: "info" },
  },
  "redis-commander": {
    name: "Redis 可视化",
    description: "启动 Redis Commander (8081)",
    category: "service",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "--profile", "tools", "up", "-d", "redis-commander"],
    cwd: BACKEND_DIR,
  },

  // ========== 数据库操作 ==========
  "db:migrate": {
    name: "数据库迁移",
    description: "启动后端自动执行迁移",
    category: "database",
    type: "oneshot",
    cmd: ["cargo", "run", "--", "--migrate-only"],
    cwd: BACKEND_DIR,
  },
  "db:verify": {
    name: "验证迁移",
    description: "验证 base.sql 完整性",
    category: "database",
    type: "oneshot",
    cmd: ["bash", "scripts/verify-base-sql.sh"],
    cwd: BACKEND_DIR,
  },
  "db:clear": {
    name: "清空数据",
    description: "清空业务数据（保留表结构）",
    category: "database",
    type: "oneshot",
    cmd: ["bash", "scripts/clear-database.sh"],
    cwd: BACKEND_DIR,
  },
  "db:reset": {
    name: "重建数据库",
    description: "删除所有数据并重建",
    category: "database",
    type: "oneshot",
    cmd: ["docker-compose", "-f", "docker/docker-compose.dev.yml", "down", "-v"],
    cwd: BACKEND_DIR,
  },

  // ========== 测试 ==========
  "test:unit": {
    name: "单元测试",
    description: "cargo test --lib",
    category: "test",
    type: "oneshot",
    cmd: ["cargo", "test", "--lib"],
    cwd: BACKEND_DIR,
  },
  "test:integration": {
    name: "集成测试",
    description: "cargo test --tests",
    category: "test",
    type: "oneshot",
    cmd: ["cargo", "test", "--tests", "--", "--test-threads=1"],
    cwd: BACKEND_DIR,
  },
  "test:all": {
    name: "一键回归",
    description: "完整测试套件（Docker）",
    category: "test",
    type: "oneshot",
    cmd: ["bash", "run.sh"],
    cwd: TESTS_DIR,
  },
  "test:go": {
    name: "Go API 测试",
    description: "Go 黑盒测试",
    category: "test",
    type: "oneshot",
    cmd: ["go", "test", "./...", "-v"],
    cwd: path.join(TESTS_DIR, "go"),
    env: { API_BASE_URL: "http://localhost:8010" },
  },
  "test:coverage": {
    name: "覆盖率报告",
    description: "生成 HTML 覆盖率报告",
    category: "test",
    type: "oneshot",
    cmd: ["bash", "coverage.sh"],
    cwd: TESTS_DIR,
  },
  "test:flow": {
    name: "API 流程测试",
    description: "准备测试数据",
    category: "test",
    type: "oneshot",
    cmd: ["bash", "test_flow.sh"],
    cwd: BACKEND_DIR,
  },

  // ========== 构建 ==========
  "build:debug": {
    name: "Debug 构建",
    description: "cargo build",
    category: "build",
    type: "oneshot",
    cmd: ["cargo", "build"],
    cwd: BACKEND_DIR,
  },
  "build:release": {
    name: "Release 构建",
    description: "cargo build --release",
    category: "build",
    type: "oneshot",
    cmd: ["cargo", "build", "--release"],
    cwd: BACKEND_DIR,
  },
  "build:linux": {
    name: "Linux 交叉编译",
    description: "使用 Zig 编译 Linux 版本",
    category: "build",
    type: "oneshot",
    cmd: ["bash", "scripts/build-linux-zig.sh"],
    cwd: BACKEND_DIR,
  },
  "deploy": {
    name: "生产部署",
    description: "构建并上传到服务器",
    category: "build",
    type: "oneshot",
    cmd: ["bash", "deploy.sh"],
    cwd: BACKEND_DIR,
  },

  // ========== 代码质量 ==========
  "check": {
    name: "编译检查",
    description: "cargo check",
    category: "quality",
    type: "oneshot",
    cmd: ["cargo", "check"],
    cwd: BACKEND_DIR,
  },
  "clippy": {
    name: "Clippy 检查",
    description: "代码质量检查",
    category: "quality",
    type: "oneshot",
    cmd: ["cargo", "clippy"],
    cwd: BACKEND_DIR,
  },
  "fmt": {
    name: "代码格式化",
    description: "cargo fmt",
    category: "quality",
    type: "oneshot",
    cmd: ["cargo", "fmt"],
    cwd: BACKEND_DIR,
  },
  "fmt:check": {
    name: "格式检查",
    description: "cargo fmt --check",
    category: "quality",
    type: "oneshot",
    cmd: ["cargo", "fmt", "--", "--check"],
    cwd: BACKEND_DIR,
  },
  "coverage:update": {
    name: "更新 API 覆盖率",
    description: "扫描测试代码，更新 API 覆盖率报告",
    category: "test",
    type: "oneshot",
    cmd: ["go", "run", "./cmd/route_coverage"],
    cwd: path.join(TESTS_DIR, "go"),
  },
  "coverage:json": {
    name: "更新代码覆盖率",
    description: "生成测试覆盖率 JSON 数据（Rust 行覆盖率 + 测试统计）",
    category: "test",
    type: "oneshot",
    cmd: ["bash", "update-coverage-json.sh"],
    cwd: TESTS_DIR,
  },
} as const satisfies Record<string, Command>;

export type CommandId = keyof typeof commands;
