/**
 * 通知 API - 调用 Rust 层的 Tauri Commands
 */

import { invoke } from '@tauri-apps/api/core';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from '@tauri-apps/plugin-notification';

export interface SystemNotificationPayload {
  title: string;
  body: string;
}

/**
 * 通知 API
 */
export const NotificationApi = {
  /**
   * 播放系统提示音
   */
  async playNotificationSound(): Promise<void> {
    await invoke('play_notification_sound');
  },

  /**
   * 请求用户注意（任务栏闪烁/跳动）
   */
  async requestAttention(): Promise<void> {
    await invoke('request_attention');
  },

  async _shouldShowSystemNotification(): Promise<boolean> {
    try {
      const win = getCurrentWebviewWindow();
      const [focused, minimized] = await Promise.all([
        win.isFocused().catch(() => true),
        win.isMinimized().catch(() => false),
      ]);
      return !focused || minimized;
    } catch (_) {
      // 无法判断窗口状态时，尽量不要漏通知
      return true;
    }
  },

  async _ensureNotificationPermission(): Promise<boolean> {
    try {
      if (await isPermissionGranted()) {
        return true;
      }
      return (await requestPermission()) === 'granted';
    } catch (_) {
      return false;
    }
  },

  async showSystemNotification(payload: SystemNotificationPayload): Promise<void> {
    try {
      if (!(await this._shouldShowSystemNotification())) {
        return;
      }

      if (!(await this._ensureNotificationPermission())) {
        return;
      }

      const title = payload.title?.trim();
      const body = payload.body?.trim();
      if (!title || !body) return;

      sendNotification({ title, body });
    } catch (error) {
      console.warn('系统通知发送失败:', error);
    }
  },

  /**
   * 显示新消息通知（播放声音 + 任务栏闪烁）
   */
  async showNewMessageNotification(
    payload?: SystemNotificationPayload,
  ): Promise<void> {
    try {
      const tasks: Promise<unknown>[] = [
        this.playNotificationSound(),
        this.requestAttention(),
      ];
      if (payload) {
        tasks.push(this.showSystemNotification(payload));
      }
      await Promise.allSettled(tasks);
    } catch (error) {
      console.warn('通知播放失败:', error);
      // 不抛出错误，避免影响主要功能
    }
  },
};
