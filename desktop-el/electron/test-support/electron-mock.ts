import { mock } from "bun:test";

export type MockIpcHandler = (_event: unknown, payload: unknown) => Promise<unknown>;
export type MockIpcListener = (_event: unknown, payload: unknown) => void;

export const electronMockState: {
  openPathCalls: string[];
  registeredHandler: MockIpcHandler | undefined;
  cancelListener: MockIpcListener | undefined;
  sentEvents: Array<[string, unknown]>;
  invokeArgs: [string, unknown] | undefined;
  sentMessages: Array<[string, unknown]>;
  exposedAPI: unknown;
  resolveInvoke: ((value: unknown) => void) | undefined;
} = {
  openPathCalls: [],
  registeredHandler: undefined,
  cancelListener: undefined,
  sentEvents: [],
  invokeArgs: undefined,
  sentMessages: [],
  exposedAPI: undefined,
  resolveInvoke: undefined,
};

export const resetElectronMockState = () => {
  electronMockState.openPathCalls = [];
  electronMockState.registeredHandler = undefined;
  electronMockState.cancelListener = undefined;
  electronMockState.sentEvents = [];
  electronMockState.invokeArgs = undefined;
  electronMockState.sentMessages = [];
  electronMockState.resolveInvoke = undefined;
};

mock.module("electron", () => ({
  shell: {
    openPath: async (targetPath: string) => {
      electronMockState.openPathCalls.push(targetPath);
      return "";
    },
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
