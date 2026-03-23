import { app, BrowserWindow } from "electron";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const createMainWindow = async () => {
  const preloadFromDist = join(__dirname, "../preload/index.js");
  const preloadFromSource = join(process.cwd(), "electron/preload/index.ts");
  const preloadPath = existsSync(preloadFromDist) ? preloadFromDist : preloadFromSource;

  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1024,
    minHeight: 640,
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const devServerURL = process.env.VITE_DEV_SERVER_URL;
  if (devServerURL) {
    await win.loadURL(devServerURL);
    win.webContents.openDevTools({ mode: "detach" });
    return;
  }

  await win.loadFile(join(process.cwd(), "dist/renderer/index.html"));
};

app.whenReady().then(() => {
  void createMainWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      void createMainWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
