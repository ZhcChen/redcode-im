import { mock } from "bun:test";

export type MockIpcHandler = (_event: unknown, payload: unknown) => Promise<unknown>;
export type MockIpcListener = (_event: unknown, payload: unknown) => void;

export const electronMockState: {
  openPathCalls: string[];
  openDialogCalls: Array<[unknown, unknown]>;
  saveDialogCalls: Array<[unknown, unknown]>;
  registeredHandler: MockIpcHandler | undefined;
  cancelListener: MockIpcListener | undefined;
  sentEvents: Array<[string, unknown]>;
  invokeArgs: [string, unknown] | undefined;
  sentMessages: Array<[string, unknown]>;
  exposedAPI: unknown;
  resolveInvoke: ((value: unknown) => void) | undefined;
  notificationSupported: boolean;
  notifications: Array<{
    options: {
      title: string;
      body: string;
      silent: boolean;
    };
    shown: boolean;
  }>;
} = {
  openPathCalls: [],
  openDialogCalls: [],
  saveDialogCalls: [],
  registeredHandler: undefined,
  cancelListener: undefined,
  sentEvents: [],
  invokeArgs: undefined,
  sentMessages: [],
  exposedAPI: undefined,
  resolveInvoke: undefined,
  notificationSupported: true,
  notifications: [],
};

export const resetElectronMockState = () => {
  electronMockState.openPathCalls = [];
  electronMockState.openDialogCalls = [];
  electronMockState.saveDialogCalls = [];
  electronMockState.registeredHandler = undefined;
  electronMockState.cancelListener = undefined;
  electronMockState.sentEvents = [];
  electronMockState.invokeArgs = undefined;
  electronMockState.sentMessages = [];
  electronMockState.resolveInvoke = undefined;
  electronMockState.notificationSupported = true;
  electronMockState.notifications = [];
};

mock.module("electron", () => ({
  shell: {
    openPath: async (targetPath: string) => {
      electronMockState.openPathCalls.push(targetPath);
      return "";
    },
  },
  dialog: {
    showOpenDialog: async (browserWindow: unknown, options: unknown) => {
      electronMockState.openDialogCalls.push([browserWindow, options]);
      return {
        canceled: false,
        filePaths: ["/tmp/mock-open.txt"],
      };
    },
    showSaveDialog: async (browserWindow: unknown, options: unknown) => {
      electronMockState.saveDialogCalls.push([browserWindow, options]);
      return {
        canceled: false,
        filePath: "/tmp/mock-save.txt",
      };
    },
  },
  Notification: class MockNotification {
    static isSupported() {
      return electronMockState.notificationSupported;
    }

    private readonly index: number;

    constructor(options: {
      title: string;
      body?: string;
      silent?: boolean;
    }) {
      electronMockState.notifications.push({
        options: {
          title: options.title,
          body: options.body ?? "",
          silent: options.silent ?? false,
        },
        shown: false,
      });
      this.index = electronMockState.notifications.length - 1;
    }

    show() {
      electronMockState.notifications[this.index]!.shown = true;
    }
  },
  BrowserWindow: {
    getAllWindows: () => [
      {
        webContents: {
          send: (channel: string, payload: unknown) => {
            electronMockState.sentEvents.push([channel, payload]);
          },
        },
      },
    ],
  },
  ipcMain: {
    handle: (_channel: string, handler: MockIpcHandler) => {
      electronMockState.registeredHandler = handler;
    },
    on: (_channel: string, listener: MockIpcListener) => {
      electronMockState.cancelListener = listener;
    },
    off: (_channel: string, listener: MockIpcListener) => {
      if (electronMockState.cancelListener === listener) {
        electronMockState.cancelListener = undefined;
      }
    },
    removeHandler: () => {
      electronMockState.registeredHandler = undefined;
    },
  },
  contextBridge: {
    exposeInMainWorld: (_key: string, api: unknown) => {
      electronMockState.exposedAPI = api;
    },
  },
  ipcRenderer: {
    invoke: (channel: string, payload: unknown) => {
      electronMockState.invokeArgs = [channel, payload];
      return new Promise((resolve) => {
        electronMockState.resolveInvoke = resolve;
      });
    },
    send: (channel: string, payload: unknown) => {
      electronMockState.sentMessages.push([channel, payload]);
    },
    on: () => {},
    off: () => {},
  },
}));
