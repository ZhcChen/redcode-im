import { Hono } from "hono";
import { serveStatic } from "hono/bun";
import { apiRoutes } from "./api/routes";
import { renderDashboard } from "./views/dashboard";

const app = new Hono();

// API 路由
app.route("/api", apiRoutes);

// 静态文件
app.use("/public/*", serveStatic({ root: "./" }));

// 主页面
app.get("/", (c) => {
  return c.html(renderDashboard());
});

const port = process.env.PORT || 20000;
console.log(`Dashboard running at http://localhost:${port}`);

export default {
  port,
  fetch: app.fetch,
};
