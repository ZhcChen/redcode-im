/**
 * WebSocket API - 调用 Rust 层的 Tauri Commands（多账号版本）
 */

import { invoke } from '@tauri-apps/api/core';

export interface WebSocketParams {
  userId: string;
  token: string;
}

export type ConnectionStatus = 'disconnected' | 'connecting' | 'authenticated';

/**
 * WebSocket Tauri 命令 API（支持多账号）
 */
export const WebSocketApi = {
  /**
   * 连接 WebSocket（为指定账号建立连接）
   * @param params 连接参数，包含 userId 和 token
   * @param wsUrl WebSocket 服务器地址
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
   * @param userId 可选，指定要断开的账号；不传则断开当前活跃账号
   */
  async disconnect(userId?: string): Promise<void> {
    await invoke('ws_disconnect', { userId });
  },

  /**
   * 断开所有 WebSocket 连接
   */
  async disconnectAll(): Promise<void> {
    await invoke('ws_disconnect_all');
  },

  /**
   * 设置当前活跃账号
   * @param userId 要设为活跃的账号 ID
   */
  async setCurrentUser(userId: string): Promise<void> {
    await invoke('ws_set_current_user', { userId });
  },

  /**
   * 获取当前活跃账号 ID
   */
  async getCurrentUser(): Promise<string | null> {
    return await invoke<string | null>('ws_get_current_user');
  },

  /**
   * 加入房间
   * @param roomId 房间 ID
   * @param userId 可选，指定账号；不传则使用当前活跃账号
   */
  async joinRoom(roomId: string, userId?: string): Promise<void> {
    await invoke('ws_join_room', { roomId, userId });
  },

  /**
   * 离开房间
   * @param roomId 房间 ID
   * @param userId 可选，指定账号；不传则使用当前活跃账号
   */
  async leaveRoom(roomId: string, userId?: string): Promise<void> {
    await invoke('ws_leave_room', { roomId, userId });
  },

  /**
   * 批量加入房间
   * @param roomIds 房间 ID 列表
   * @param userId 可选，指定账号；不传则使用当前活跃账号
   */
  async joinRooms(roomIds: string[], userId?: string): Promise<void> {
    await invoke('ws_join_rooms', { roomIds, userId });
  },

  /**
   * 获取连接状态
   * @param userId 可选，指定账号；不传则获取当前活跃账号状态
   */
  async getStatus(userId?: string): Promise<ConnectionStatus> {
    return await invoke<ConnectionStatus>('ws_get_status', { userId });
  },

  /**
   * 获取所有账号的连接状态
   * @returns 以 userId 为键、状态为值的对象
   */
  async getAllStatus(): Promise<Record<string, ConnectionStatus>> {
    return await invoke<Record<string, ConnectionStatus>>('ws_get_all_status');
  },

  /**
   * 获取已订阅的房间列表
   * @param userId 可选，指定账号；不传则获取当前活跃账号的房间
   */
  async getSubscribedRooms(userId?: string): Promise<string[]> {
    return await invoke<string[]>('ws_get_subscribed_rooms', { userId });
  },

  /**
   * 获取当前连接的账号数量
   */
  async getConnectedCount(): Promise<number> {
    return await invoke<number>('ws_get_connected_count');
  },
};
