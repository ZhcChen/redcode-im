import { app } from "electron";
import { join } from "node:path";
import {
  acquireSingleInstanceLock,
  createAppService,
  onActivate,
  onBeforeQuit,
  onSecondInstance,
  onWindowAllClosed,
  waitUntilReady
} from "./app.js";
import { createDialogService } from "./dialog.js";
import { createFileService } from "./file.js";
import { GoCoreBridge } from "./go-core.js";
import { createNotificationService } from "./notification.js";
import { registerRpcIpc, RpcDispatcher } from "./rpc.js";
import { registerShellIpc } from "./shell-api.js";
import { AppTrayController } from "./tray.js";
import { MainWindowController } from "./window.js";

const GO_CORE_READY_TIMEOUT_MS = 5000;
const GO_CORE_RESTART_DELAY_MS = 1000;

export interface DesktopLifecycle {
  start(): Promise<void>;
  stop(): Promise<void>;
}

export const createDesktopLifecycle = (): DesktopLifecycle => {
  const windowController = new MainWindowController({
    devServerURL: process.env.VITE_DEV_SERVER_URL
  });
  const goCore = new GoCoreBridge();
  const rpcDispatcher = new RpcDispatcher(goCore);
  const appService = createAppService();
  const dialogService = createDialogService(windowController);
  const fileService = createFileService({
    cacheRootDir: join(app.getPath("userData"), "attachment-cache")
  });
  const notificationService = createNotificationService();
  const trayController = new AppTrayController({
    onShow: () => {
      void showMainWindow();
    },
    onQuit: () => {
      app.quit();
    }
  });

  let started = false;
  let stopping = false;
  let restartTimer: NodeJS.Timeout | undefined;
  let cleanupRpc: (() => void) | undefined;
  let cleanupShell: (() => void) | undefined;

  const cleanupResources = () => {
    clearTimeout(restartTimer);
    restartTimer = undefined;
    cleanupShell?.();
    cleanupRpc?.();
    cleanupShell = undefined;
    cleanupRpc = undefined;
    trayController.destroy();
    windowController.setAllowClose(true);
  };

  const showMainWindow = async () => {
    await windowController.create();
    await windowController.show();
    await windowController.focus();
  };

  const scheduleRestart = () => {
    if (stopping || restartTimer) {
      return;
    }
    restartTimer = setTimeout(() => {
      restartTimer = undefined;
      void startGoCore();
    }, GO_CORE_RESTART_DELAY_MS);
  };

  const startGoCore = async () => {
    try {
      await withTimeout(goCore.start(), GO_CORE_READY_TIMEOUT_MS, "go core ready timeout");
      console.log("[desktop-el] go core ready");
    } catch (error) {
      console.error("[desktop-el] failed to start go core", error);
      scheduleRestart();
      throw error;
    }
  };

  goCore.onExit((code, signal) => {
    if (stopping) {
      return;
    }
    console.error(`[desktop-el] go core exited unexpectedly (code=${code ?? "null"}, signal=${signal ?? "null"})`);
    scheduleRestart();
  });

  onSecondInstance(() => {
    void showMainWindow();
  });

  onActivate(() => {
    void showMainWindow();
  });

  onBeforeQuit(() => {
    stopping = true;
    cleanupResources();
    void goCore.stop();
  });

  onWindowAllClosed(() => {
    if (process.platform !== "darwin") {
      app.quit();
    }
  });

  return {
    async start() {
      if (started) {
        return;
      }
      started = true;

      if (!acquireSingleInstanceLock()) {
        started = false;
        app.quit();
        return;
      }

      try {
        await waitUntilReady();
        await startGoCore();
      } catch (error) {
        started = false;
        throw error;
      }

      cleanupRpc = registerRpcIpc(rpcDispatcher);
      cleanupShell = registerShellIpc({
        app: appService,
        window: windowController,
        dialog: dialogService,
        notification: notificationService,
        file: fileService
      });

      trayController.create();
      await windowController.create();
      await windowController.show();
    },

    async stop() {
      if (stopping) {
        return;
      }
      stopping = true;
      cleanupResources();
      await windowController.close();
      await goCore.stop();
    }
  };
};

const withTimeout = async <T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> => {
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(() => {
          reject(new Error(message));
        }, timeoutMs);
      })
    ]);
  } finally {
    clearTimeout(timer);
  }
};
