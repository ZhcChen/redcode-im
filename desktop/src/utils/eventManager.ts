/**
 * 统一的事件监听器管理器
 * 用于管理所有事件监听器，防止内存泄漏
 */

class EventManager {
  private static instance: EventManager;
  private listeners: Map<string, (() => void)[]> = new Map();
  private windowListeners: Map<string, (() => void)[]> = new Map();
  private documentListeners: Map<string, (() => void)[]> = new Map();

  public static getInstance(): EventManager {
    if (!EventManager.instance) {
      EventManager.instance = new EventManager();
    }
    return EventManager.instance;
  }

  /**
   * 添加窗口事件监听器
   */
  public addWindowListener(event: string, handler: EventListener): () => void {
    window.addEventListener(event, handler);
    
    const cleanup = () => {
      window.removeEventListener(event, handler);
    };
    
    if (!this.windowListeners.has(event)) {
      this.windowListeners.set(event, []);
    }
    this.windowListeners.get(event)!.push(cleanup);
    
    return cleanup;
  }

  /**
   * 添加文档事件监听器
   */
  public addDocumentListener(event: string, handler: EventListener): () => void {
    document.addEventListener(event, handler);
    
    const cleanup = () => {
      document.removeEventListener(event, handler);
    };
    
    if (!this.documentListeners.has(event)) {
      this.documentListeners.set(event, []);
    }
    this.documentListeners.get(event)!.push(cleanup);
    
    return cleanup;
  }

  /**
   * 添加通用事件监听器
   */
  public addListener(target: EventTarget, event: string, handler: EventListener): () => void {
    target.addEventListener(event, handler);
    
    const cleanup = () => {
      target.removeEventListener(event, handler);
    };
    
    const key = `${target.constructor.name}-${event}`;
    if (!this.listeners.has(key)) {
      this.listeners.set(key, []);
    }
    this.listeners.get(key)!.push(cleanup);
    
    return cleanup;
  }

  /**
   * 清理所有窗口事件监听器
   */
  public clearWindowListeners(): void {
    console.log('🧹 清理所有窗口事件监听器，当前数量:', this.windowListeners.size);
    this.windowListeners.forEach(cleanups => {
      cleanups.forEach(cleanup => {
        try {
          cleanup();
        } catch (error) {
          console.warn('清理窗口事件监听器失败:', error);
        }
      });
    });
    this.windowListeners.clear();
  }

  /**
   * 清理所有文档事件监听器
   */
  public clearDocumentListeners(): void {
    console.log('🧹 清理所有文档事件监听器，当前数量:', this.documentListeners.size);
    this.documentListeners.forEach(cleanups => {
      cleanups.forEach(cleanup => {
        try {
          cleanup();
        } catch (error) {
          console.warn('清理文档事件监听器失败:', error);
        }
      });
    });
    this.documentListeners.clear();
  }

  /**
   * 清理所有事件监听器
   */
  public clearAllListeners(): void {
    console.log('🧹 清理所有事件监听器');
    
    // 清理窗口监听器
    this.clearWindowListeners();
    
    // 清理文档监听器
    this.clearDocumentListeners();
    
    // 清理通用监听器
    console.log('🧹 清理所有通用事件监听器，当前数量:', this.listeners.size);
    this.listeners.forEach(cleanups => {
      cleanups.forEach(cleanup => {
        try {
          cleanup();
        } catch (error) {
          console.warn('清理通用事件监听器失败:', error);
        }
      });
    });
    this.listeners.clear();
  }

  /**
   * 获取当前监听器统计信息
   */
  public getStats(): { window: number; document: number; general: number; total: number } {
    const windowCount = Array.from(this.windowListeners.values()).reduce((sum, arr) => sum + arr.length, 0);
    const documentCount = Array.from(this.documentListeners.values()).reduce((sum, arr) => sum + arr.length, 0);
    const generalCount = Array.from(this.listeners.values()).reduce((sum, arr) => sum + arr.length, 0);
    
    return {
      window: windowCount,
      document: documentCount,
      general: generalCount,
      total: windowCount + documentCount + generalCount
    };
  }
}

// 导出单例实例
export const eventManager = EventManager.getInstance();
export default eventManager;
