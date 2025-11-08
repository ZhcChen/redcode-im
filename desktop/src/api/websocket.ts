/**
 * WebSocket API - 调用 Rust 层的 Tauri Commands
 */

import { invoke } from '@tauri-apps/api/core';

export interface WebSocketParams {
  userId: string;
  token: string;
}

export type ConnectionStatus = 'disconnected' | 'connecting' | 'authenticated';

/**
 * WebSocket Tauri 命令 API
 */
export const WebSocketApi = {
  /**
   * 连接 WebSocket
   */
  async connect(params: WebSocketParams, wsUrl: string): Promise<void> {
    await invoke('ws_connect', {
      params: {
        user_id: params.userId,
        token: params.token,
      },
      wsUrl,
    });
  },

  /**
   * 断开 WebSocket 连接
   */
  async disconnect(): Promise<void> {
    await invoke('ws_disconnect');
  },

  /**
   * 加入房间
   */
  async joinRoom(roomId: string): Promise<void> {
    await invoke('ws_join_room', { roomId });
  },

  /**
   * 离开房间
   */
  async leaveRoom(roomId: string): Promise<void> {
    await invoke('ws_leave_room', { roomId });
  },

  /**
   * 批量加入房间
   */
  async joinRooms(roomIds: string[]): Promise<void> {
    await invoke('ws_join_rooms', { roomIds });
  },

  /**
   * 获取连接状态
   */
  async getStatus(): Promise<ConnectionStatus> {
    return await invoke<ConnectionStatus>('ws_get_status');
  },

  /**
   * 获取已订阅的房间列表
   */
  async getSubscribedRooms(): Promise<string[]> {
    return await invoke<string[]>('ws_get_subscribed_rooms');
  },
};
