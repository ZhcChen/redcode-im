import { app } from "electron";

export interface DesktopAppService {
  getVersion(): Promise<string>;
  quit(): Promise<void>;
}

export const acquireSingleInstanceLock = (): boolean => app.requestSingleInstanceLock();

export const onSecondInstance = (listener: () => void): void => {
  app.on("second-instance", () => {
    listener();
  });
};

export const onActivate = (listener: () => void): void => {
  app.on("activate", () => {
    listener();
  });
};

export const onWindowAllClosed = (listener: () => void): void => {
  app.on("window-all-closed", listener);
};

export const onBeforeQuit = (listener: () => void): void => {
  app.on("before-quit", listener);
};

export const waitUntilReady = (): Promise<void> => app.whenReady();

export const createAppService = (): DesktopAppService => ({
  async getVersion() {
    return app.getVersion();
  },
  async quit() {
    app.quit();
  }
});
