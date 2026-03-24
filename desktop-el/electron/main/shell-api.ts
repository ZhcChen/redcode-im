import { ipcMain } from "electron";
import { SHELL_INVOKE_CHANNEL, type ShellInvokePayload } from "../preload/types.js";
import type { DesktopAppService } from "./app.js";
import type { DesktopDialogService } from "./dialog.js";
import type { DesktopFileService } from "./file.js";
import type { DesktopNotificationService } from "./notification.js";
import type { DesktopWindowService } from "./window.js";

export interface ShellServices {
  app: DesktopAppService;
  window: DesktopWindowService;
  dialog: DesktopDialogService;
  notification: DesktopNotificationService;
  file: DesktopFileService;
}

export const registerShellIpc = (services: ShellServices): (() => void) => {
  ipcMain.handle(SHELL_INVOKE_CHANNEL, async (_event, payload: unknown) => {
    if (!isShellInvokePayload(payload)) {
      throw new Error("invalid shell invoke payload");
    }

    switch (payload.namespace) {
      case "app":
        return callServiceMethod(services.app, payload.method, payload.params);
      case "window":
        return callServiceMethod(services.window, payload.method, payload.params);
      case "dialog":
        return callServiceMethod(services.dialog, payload.method, payload.params);
      case "notification":
        return callServiceMethod(services.notification, payload.method, payload.params);
      case "file":
        return callServiceMethod(services.file, payload.method, payload.params);
      default:
        throw new Error(`unsupported shell namespace: ${String(payload.namespace)}`);
    }
  });

  return () => {
    ipcMain.removeHandler(SHELL_INVOKE_CHANNEL);
  };
};

const isShellInvokePayload = (value: unknown): value is ShellInvokePayload => {
  if (!value || typeof value !== "object") {
    return false;
  }
  const payload = value as ShellInvokePayload;
  return (
    ["app", "window", "dialog", "notification", "file"].includes(payload.namespace) &&
    typeof payload.method === "string" &&
    payload.method.length > 0
  );
};

const callServiceMethod = async (
  service: object,
  method: string,
  params?: Record<string, unknown>
): Promise<unknown> => {
  const target = (service as Record<string, unknown>)[method];
  if (typeof target !== "function") {
    throw new Error(`unsupported shell method: ${method}`);
  }

  if (!params || Object.keys(params).length === 0) {
    return target.call(service);
  }

  const values = Object.values(params);
  if (values.length === 1) {
    return target.call(service, values[0]);
  }

  return target.call(service, ...values);
};
