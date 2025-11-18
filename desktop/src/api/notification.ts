/**
 * 通知 API - 调用 Rust 层的 Tauri Commands
 */

import { invoke } from '@tauri-apps/api/core';

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

  /**
   * 显示新消息通知（播放声音 + 任务栏闪烁）
   */
  async showNewMessageNotification(): Promise<void> {
    try {
      // 并行执行声音和闪烁
      await Promise.all([
        this.playNotificationSound(),
        this.requestAttention(),
      ]);
    } catch (error) {
      console.warn('通知播放失败:', error);
      // 不抛出错误，避免影响主要功能
    }
  },
};
