/**
 * WebSocket 管理工具
 */
import { apiConfig } from '@/api/config';
import { 
  BUSINESS_CODE, 
  WebSocketParams, 
  WebSocketMessage, 
  WebSocketState 
} from '@/types/websocket';
import { toast } from '@/utils/toast';
import { store } from '@/store'; // 直接导入store实例

class WebSocketManager {
  private static instance: WebSocketManager;
  private state: WebSocketState = {
    socket: null,
    isOnline: false,
    reconnectCount: 5,
    heartbeatTimer: null,
    reconnectTimer: null
  };

  private initParams: WebSocketParams | null = null;
  private readonly TIO_SERVER = apiConfig.TIO_SERVER;
  private readonly PING_INTERVAL = 3000; // 心跳间隔 3秒 - 与 bear-chat-uniapp 保持一致
  private readonly RECONNECT_INTERVAL = 5000; // 重连间隔 5秒
  private readonly MAX_RECONNECT_COUNT = 10; // 最大重连次数
  private connectionPromise: Promise<void> | null = null;

  // 单例模式，确保只有一个WebSocket管理器实例
  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  /**
   * 安全的初始化 WebSocket 连接
   */
  public async initWebSocketSafely(params: WebSocketParams): Promise<void> {
    const callStack = new Error().stack;
    console.log('🔄 [DEBUG] initWebSocketSafely 被调用', {
      params,
      currentState: {
        isOnline: this.state.isOnline,
        hasSocket: !!this.state.socket,
        hasInitParams: !!this.initParams,
        hasConnectionPromise: !!this.connectionPromise
      },
      callStack: callStack?.split('\n').slice(1, 4) // 显示调用栈前3行
    });

    // 参数验证
    if (!params?.userId || !params?.token) {
      console.log('❌ WebSocket 连接参数无效');
      this.handleAuthError();
      return;
    }

    // 检查是否已经有相同参数的活跃连接
    if (this.state.isOnline && this.state.socket && this.initParams) {
      const isSameConnection = this.initParams.userId === params.userId &&
                              this.initParams.token === params.token;
      if (isSameConnection) {
        console.log('✅ WebSocket 已存在相同参数的活跃连接，跳过初始化');
        return;
      }
    }

    // 如果已有连接在进行中，等待完成后再检查
    if (this.connectionPromise) {
      console.log('⏳ 等待现有连接完成...');
      try {
        await this.connectionPromise;
        // 连接完成后，再次检查是否需要新连接
        if (this.state.isOnline && this.initParams?.userId === params.userId && this.initParams?.token === params.token) {
          console.log('✅ 现有连接已满足需求，跳过重复初始化');
          return;
        }
      } catch (error) {
        console.log('⚠️ 现有连接失败，继续创建新连接');
      }
    }

    // 先彻底关闭任何现有连接，防止连接混乱
    this.closeWebSocket();

    // 保存初始化参数
    this.initParams = params;
    this.state.isOnline = false;
    this.state.socket = null;

    // 创建连接Promise
    this.connectionPromise = this.createConnection();
    try {
      await this.connectionPromise;
    } finally {
      this.connectionPromise = null;
    }
  }

  /**
   * 创建 WebSocket 连接（返回 Promise）
   */
  private createConnection(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.initParams) {
        reject(new Error('初始化参数为空'));
        return;
      }

      // 构建连接 URL
      const urlParams = this.buildUrlParams(this.initParams);
      const wsUrl = `${this.TIO_SERVER}${urlParams}`;
      
      console.log('WebSocket 连接地址:', wsUrl);

      try {
        // 创建 WebSocket 连接
        console.log('🔗 [DEBUG] 正在创建新的 WebSocket 实例:', wsUrl);
        this.state.socket = new WebSocket(wsUrl);

        // 绑定事件监听器
        this.bindEventListeners(resolve, reject);

      } catch (error) {
        console.error('WebSocket 连接创建失败:', error);
        reject(error);
      }
    });
  }

  /**
   * 初始化 WebSocket 连接（保持向后兼容）
   */
  public initWebSocket(params: WebSocketParams): void {
    console.log('🔄 初始化 WebSocket 服务', params);
    
    // 参数验证
    if (!params?.userId || !params?.token) {
      console.log('❌ WebSocket 连接参数无效');
      this.handleAuthError();
      return;
    }

    // 先彻底关闭任何现有连接，防止连接混乱
    if (this.state.socket || this.state.isOnline) {
      console.log('⚠️ 检测到现有连接，先关闭旧连接');
      this.closeWebSocket();
    }

    this.initParams = params;
    this.state.isOnline = false;
    this.state.socket = null;

    // 构建连接 URL
    const urlParams = this.buildUrlParams(params);
    const wsUrl = `${this.TIO_SERVER}${urlParams}`;
    
    console.log('WebSocket 连接地址:', wsUrl);

    try {
      // 创建 WebSocket 连接
      this.state.socket = new WebSocket(wsUrl);
      
      // 绑定事件监听器
      this.bindEventListeners();
      
    } catch (error) {
      console.error('WebSocket 连接创建失败:', error);
      this.handleConnectionError();
    }
  }

  /**
   * 绑定 WebSocket 事件监听器
   */
  private bindEventListeners(resolve?: () => void, reject?: (error: any) => void): void {
    if (!this.state.socket) return;

    // 连接打开
    this.state.socket.onopen = (event) => {
      console.log('✅ WebSocket 长连接已打开');
      this.clearTimers();
      this.state.isOnline = true;
      this.state.reconnectCount = this.MAX_RECONNECT_COUNT;
      
      // 更新 Vuex 状态
      store.commit('SET_WEBSOCKET', this.state.socket);
      store.commit('SET_NETWORK_STATE', true);
      
      console.log('🔄 WebSocket连接成功，已停止重连定时器');
      
      // 开始心跳 - 立即启动，与 bear-chat-uniapp 保持一致
      this.startHeartbeat();
      
      // 如果有 resolve 回调，调用它
      if (resolve) {
        resolve();
      }
    };

    // 接收消息
    this.state.socket.onmessage = (event) => {
      this.handleMessage(event.data);
    };

    // 连接错误
    this.state.socket.onerror = (error) => {
      console.error('WebSocket 连接异常:', error);
      this.handleConnectionError();
      
      // 如果有 reject 回调，调用它
      if (reject) {
        reject(error);
      }
    };

    // 连接关闭
    this.state.socket.onclose = (event) => {
      console.log('WebSocket 连接已关闭:', event);
      this.handleConnectionClose();
      
      // 如果连接异常关闭且有 reject 回调，调用它
      if (event.code !== 1000 && reject) {
        reject(new Error(`WebSocket连接异常关闭: ${event.code} ${event.reason}`));
      }
    };
  }

  /**
   * 处理接收到的消息
   */
  private handleMessage(data: string): void {
    try {
      const messageObj: WebSocketMessage = JSON.parse(data);
      const code = messageObj.code;
      
      console.log('收到 WebSocket 消息:', code, messageObj);

      // 处理不同类型的消息
      switch (code) {
        case BUSINESS_CODE.ping:
          // 心跳响应，不需要特殊处理
          break;
        case BUSINESS_CODE.chatting:
          this.handleChatMessage(messageObj.message);
          break;
        case BUSINESS_CODE.AI:
          this.handleAIMessage(messageObj.message);
          break;
        case BUSINESS_CODE.FriendBindChange:
          this.handleFriendChange(messageObj.message);
          break;
        case BUSINESS_CODE.DeleteFriend:
          this.handleDeleteFriend(messageObj.message);
          break;
        case BUSINESS_CODE.FriendCircle:
          this.handleFriendCircle(messageObj.message);
          break;
        case BUSINESS_CODE.launchGroup:
          this.handleLaunchGroup(messageObj.message);
          break;
        case BUSINESS_CODE.deleteGroup:
          this.handleDeleteGroup(messageObj.message);
          break;
        case BUSINESS_CODE.Calling:
          this.handleCalling(messageObj.message);
          break;
        default:
          console.log('未知的消息类型:', code);
          break;
      }
    } catch (error) {
      console.error('解析 WebSocket 消息失败:', error);
    }
  }

  /**
   * 处理聊天消息
   */
  private handleChatMessage(message: any): void {
    console.log('处理聊天消息:', message);
    // 这里可以触发 Vue 事件或者调用 Vuex mutations
    window.dispatchEvent(new CustomEvent('websocket-chat-message', { detail: message }));
  }

  /**
   * 处理 AI 消息
   */
  private handleAIMessage(message: any): void {
    console.log('处理 AI 消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-ai-message', { detail: message }));
  }

  /**
   * 处理好友变化消息
   */
  private handleFriendChange(message: any): void {
    console.log('处理好友变化消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-friend-change', { detail: message }));
  }

  /**
   * 处理删除好友消息
   */
  private handleDeleteFriend(message: any): void {
    console.log('处理删除好友消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-delete-friend', { detail: message }));
  }

  /**
   * 处理朋友圈消息
   */
  private handleFriendCircle(message: any): void {
    console.log('处理朋友圈消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-friend-circle', { detail: message }));
  }

  /**
   * 处理发起群聊消息
   */
  private handleLaunchGroup(message: any): void {
    console.log('处理发起群聊消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-launch-group', { detail: message }));
  }

  /**
   * 处理解散群组消息
   */
  private handleDeleteGroup(message: any): void {
    console.log('处理解散群组消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-delete-group', { detail: message }));
  }

  /**
   * 处理通话消息
   */
  private handleCalling(message: any): void {
    console.log('处理通话消息:', message);
    window.dispatchEvent(new CustomEvent('websocket-calling', { detail: message }));
  }

  /**
   * 开始心跳检测
   */
  private startHeartbeat(): void {
    this.state.heartbeatTimer = setInterval(() => {
      if (this.state.socket && this.state.isOnline) {
        // 完全按照 bear-chat-uniapp 的心跳包格式
        const pingMessage = JSON.stringify({
          code: BUSINESS_CODE.ping
        });

        try {
          this.state.socket.send(pingMessage);
          console.log('发送心跳包:', pingMessage);
        } catch (error) {
          console.error('发送心跳包失败:', error);
          this.handleConnectionError();
        }
      }
    }, this.PING_INTERVAL);
  }

  /**
   * 发送消息
   */
  public sendMessage(
    message: any, 
    code: string = BUSINESS_CODE.chatting,
    callback?: (success: boolean) => void
  ): void {
    if (!this.state.isOnline || !this.state.socket) {
      console.error('WebSocket 未连接，无法发送消息');
      store.commit('SET_NETWORK_STATE', false);
      callback?.(false);
      return;
    }

    const data = {
      code,
      message
    };

    try {
      this.state.socket.send(JSON.stringify(data));
      console.log('WebSocket 消息发送成功:', data);
      callback?.(true);
    } catch (error) {
      console.error('WebSocket 消息发送失败:', error);
      callback?.(false);
    }
  }

  /**
   * 关闭 WebSocket 连接 - 彻底清理所有状态，防止账户切换混乱
   */
  public closeWebSocket(): void {
    console.log('🔄 开始关闭 WebSocket 连接...');

    // 立即清除所有定时器，停止心跳和重连
    this.clearTimers();

    // 立即设置离线状态
    this.state.isOnline = false;

    // 立即更新 Vuex 状态
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);

    // 清除初始化参数，防止自动重连 - 必须在关闭socket之前
    this.initParams = null;

    // 立即关闭 WebSocket 连接
    if (this.state.socket) {
      try {
        // 设置关闭码，明确表示正常关闭
        this.state.socket.close(1000, 'User logout');
        console.log('⚡ WebSocket 连接已立即关闭');
      } catch (error) {
        console.error('❌ 关闭 WebSocket 连接失败:', error);
      } finally {
        // 强制设置为null，即使关闭失败
        this.state.socket = null;
      }
    }

    // 清理连接Promise
    this.connectionPromise = null;

    // 重置重连计数
    this.state.reconnectCount = this.MAX_RECONNECT_COUNT;

    console.log('✅ WebSocket 连接已彻底关闭，所有状态已清理');
  }

  /**
   * 重新连接
   */
  private reconnect(): void {
    if (this.state.isOnline) {
      console.log('✅ WebSocket 已在线，无需重连');
      this.clearReconnectTimer();
      this.state.reconnectCount = this.MAX_RECONNECT_COUNT;
      return;
    }

    if (this.state.reconnectCount <= 0) {
      console.log('❌ 重连次数已达上限，停止重连');
      this.clearReconnectTimer();
      console.log('💡 WebSocket重连失败，请检查网络连接或重新登录');
      return;
    }

    // 检查是否还有初始化参数
    if (!this.initParams) {
      console.warn('⚠️ 重连参数缺失，停止重连');
      this.clearReconnectTimer();
      return;
    }

    const attemptNumber = this.MAX_RECONNECT_COUNT - this.state.reconnectCount + 1;
    console.log(`🔄 第 ${attemptNumber} 次重连中... (剩余尝试次数: ${this.state.reconnectCount})`);
    this.state.reconnectCount--;

    // 先关闭现有连接
    if (this.state.socket) {
      this.state.socket.close();
      this.state.socket = null;
    }

    // 等待一小段时间再重连，避免过于频繁，使用递增延迟
    const delay = Math.min(1000 * attemptNumber, 5000); // 最大延迟5秒
    setTimeout(() => {
      if (!this.state.isOnline && this.initParams) {
        this.initWebSocket(this.initParams);
      }
    }, delay);
  }

  /**
   * 处理连接错误
   */
  private handleConnectionError(): void {
    console.log('❌ WebSocket连接错误，准备重连...');
    this.state.isOnline = false;
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);
    
    // 清除心跳
    this.clearHeartbeatTimer();
    
    // 启动重连定时器
    this.startReconnectTimer();
  }

  /**
   * 处理连接关闭
   */
  private handleConnectionClose(): void {
    console.log('🔌 WebSocket连接已关闭，准备重连...');
    this.state.isOnline = false;
    store.commit('SET_WEBSOCKET', null);
    store.commit('SET_NETWORK_STATE', false);

    // 清除心跳
    this.clearHeartbeatTimer();

    // 只有在有初始化参数且不是主动关闭时才启动重连
    if (this.initParams && this.state.socket) {
      this.startReconnectTimer();
    } else {
      console.log('⚠️ WebSocket 主动关闭或无初始化参数，不启动重连');
    }
  }

  /**
   * 启动重连定时器
   */
  private startReconnectTimer(): void {
    // 避免重复启动定时器
    if (this.state.reconnectTimer) {
      console.log('⚠️ 重连定时器已存在，跳过启动');
      return;
    }

    console.log(`🔄 启动自动重连定时器，每${this.RECONNECT_INTERVAL}ms尝试一次`);
    this.state.reconnectTimer = setInterval(() => {
      this.reconnect();
    }, this.RECONNECT_INTERVAL);
  }

  /**
   * 处理认证错误
   */
  private handleAuthError(): void {
    this.clearTimers();
    toast.error('认证失败，请重新登录');
    
    // 清除用户状态，跳转到登录页面
    store.dispatch('logout');
  }

  /**
   * 清除所有定时器
   */
  private clearTimers(): void {
    this.clearHeartbeatTimer();
    this.clearReconnectTimer();
  }

  /**
   * 清除心跳定时器
   */
  private clearHeartbeatTimer(): void {
    if (this.state.heartbeatTimer !== null) {
      clearInterval(this.state.heartbeatTimer);
      this.state.heartbeatTimer = null;
    }
  }

  /**
   * 清除重连定时器
   */
  private clearReconnectTimer(): void {
    if (this.state.reconnectTimer !== null) {
      clearInterval(this.state.reconnectTimer);
      this.state.reconnectTimer = null;
    }
  }

  /**
   * 构建 URL 参数
   */
  private buildUrlParams(params: WebSocketParams): string {
    const paramEntries = Object.entries(params);
    const paramStrings = paramEntries.map(([key, value]) => `${key}=${value}`);
    return paramStrings.join('&');
  }

  /**
   * 获取连接状态
   */
  public getConnectionState(): boolean {
    return this.state.isOnline;
  }
}

// 导出单例
export const webSocketManager = new WebSocketManager();
