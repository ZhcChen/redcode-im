import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { resolve } from "node:path";

export default defineConfig({
  root: "renderer",
  plugins: [vue()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "renderer/src")
    }
  },
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: true
  },
  build: {
    outDir: "../dist/renderer",
    emptyOutDir: true
  }
});
