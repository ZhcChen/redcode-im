import { Notification } from "electron";
import type { DesktopNotificationPayload } from "../preload/types.js";

export interface DesktopNotificationService {
  isSupported(): Promise<boolean>;
  show(payload: DesktopNotificationPayload): Promise<void>;
}

export const createNotificationService = (): DesktopNotificationService => ({
  async isSupported() {
    return Notification.isSupported();
  },
  async show(payload) {
    if (!Notification.isSupported()) {
      return;
    }
    const notification = new Notification({
      title: payload.title,
      body: payload.body ?? "",
      silent: payload.silent ?? false
    });
    notification.show();
  }
});
