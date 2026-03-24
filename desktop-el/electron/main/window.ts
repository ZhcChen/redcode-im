import { BrowserWindow } from "electron";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface MainWindowControllerOptions {
  devServerURL?: string;
}

export interface DesktopWindowService {
  show(): Promise<void>;
  hide(): Promise<void>;
  focus(): Promise<void>;
  setTitle(title: string): Promise<void>;
}

export class MainWindowController implements DesktopWindowService {
  private window?: BrowserWindow;
  private allowClose = false;

  constructor(private readonly options: MainWindowControllerOptions = {}) {}

  async create(): Promise<BrowserWindow> {
    if (this.window && !this.window.isDestroyed()) {
      return this.window;
    }

    const preloadFromDist = join(__dirname, "../preload/index.cjs");
    const preloadFromSource = join(process.cwd(), "electron/preload/index.cts");
    const preloadPath = existsSync(preloadFromDist) ? preloadFromDist : preloadFromSource;

    const win = new BrowserWindow({
      width: 1280,
      height: 800,
      minWidth: 1024,
      minHeight: 640,
      show: false,
      webPreferences: {
        preload: preloadPath,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false
      }
    });

    win.on("close", (event) => {
      if (this.allowClose) {
        return;
      }
      event.preventDefault();
      win.hide();
    });

    win.on("closed", () => {
      this.window = undefined;
    });

    if (this.options.devServerURL) {
      win.webContents.on("console-message", (_event, _level, message) => {
        console.log(`[desktop-el-renderer] ${message}`);
      });
    }

    win.once("ready-to-show", () => {
      win.show();
      win.focus();
    });

    if (this.options.devServerURL) {
      await win.loadURL(this.options.devServerURL);
      win.webContents.openDevTools({ mode: "detach" });
    } else {
      await win.loadFile(join(process.cwd(), "dist/renderer/index.html"));
    }

    if (!win.isVisible()) {
      win.show();
      win.focus();
    }

    this.window = win;
    return win;
  }

  getWindow(): BrowserWindow | undefined {
    if (!this.window || this.window.isDestroyed()) {
      return undefined;
    }
    return this.window;
  }

  setAllowClose(value: boolean): void {
    this.allowClose = value;
  }

  async close(): Promise<void> {
    const win = this.getWindow();
    if (!win) {
      return;
    }
    this.allowClose = true;
    win.close();
  }

  async show(): Promise<void> {
    const win = await this.create();
    if (win.isMinimized()) {
      win.restore();
    }
    win.show();
  }

  async hide(): Promise<void> {
    this.getWindow()?.hide();
  }

  async focus(): Promise<void> {
    const win = await this.create();
    win.focus();
  }

  async setTitle(title: string): Promise<void> {
    const win = await this.create();
    win.setTitle(title);
  }
}
