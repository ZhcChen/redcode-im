/**
 * 通知 API - 调用 Rust 层的 Tauri Commands
 */

import { invoke } from '@tauri-apps/api/core';

/**
 * 通知 API
 */
export const NotificationApi = {
  /**
   * HTML5 音频（作为系统播放失败时的兜底）
   * 使用极短的内联 wav，避免额外静态资源
   */
  async playFallbackSound() {
    const dataUrl =
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAACABAAZGF0YQAAAAAA';
    try {
      const audio = new Audio(dataUrl);
      audio.volume = 0.8;
      await audio.play();
    } catch (error) {
      console.warn('fallback sound play failed', error);
    }
  },

  /**
   * 播放系统提示音
   */
  async playNotificationSound(): Promise<void> {
    try {
      await invoke('play_notification_sound');
    } catch (error) {
      // Tauri 命令失败则使用前端兜底
      await this.playFallbackSound();
    }
  },

  /**
   * 请求用户注意（任务栏闪烁/跳动）
   */
  async requestAttention(): Promise<void> {
    try {
      await invoke('request_attention');
    } catch (error) {
      // 使用前端 API 兜底（Tauri 2 window API）
      try {
        const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
        const win = getCurrentWebviewWindow();
        await (win as any).requestUserAttention?.('critical');
      } catch (fallbackError) {
        console.warn('requestAttention fallback failed', fallbackError);
      }
    }
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
