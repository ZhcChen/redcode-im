/**
 * 内存监控工具
 * 用于监控应用内存使用情况，帮助发现内存泄漏
 */

interface MemoryInfo {
  used: number;
  total: number;
  limit: number;
  timestamp: number;
}

class MemoryMonitor {
  private static instance: MemoryMonitor;
  private monitoringInterval: number | null = null;
  private memoryHistory: MemoryInfo[] = [];
  private readonly MAX_HISTORY_SIZE = 100;
  private readonly MONITORING_INTERVAL = 10000; // 10秒检查一次
  private isMonitoring = false;

  public static getInstance(): MemoryMonitor {
    if (!MemoryMonitor.instance) {
      MemoryMonitor.instance = new MemoryMonitor();
    }
    return MemoryMonitor.instance;
  }

  /**
   * 开始内存监控
   */
  public startMonitoring(): void {
    if (this.isMonitoring) {
      return;
    }

    if (!this.isMemoryAPIAvailable()) {
      return;
    }

    this.isMonitoring = true;

    this.monitoringInterval = window.setInterval(() => {
      this.checkMemoryUsage();
    }, this.MONITORING_INTERVAL);

    // 立即检查一次
    this.checkMemoryUsage();
  }

  /**
   * 停止内存监控
   */
  public stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;
    
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }

  }

  /**
   * 检查内存使用情况
   */
  private checkMemoryUsage(): void {
    if (!this.isMemoryAPIAvailable()) {
      return;
    }

    const memory = (performance as any).memory;
    const memoryInfo: MemoryInfo = {
      used: Math.round(memory.usedJSHeapSize / 1024 / 1024), // MB
      total: Math.round(memory.totalJSHeapSize / 1024 / 1024), // MB
      limit: Math.round(memory.jsHeapSizeLimit / 1024 / 1024), // MB
      timestamp: Date.now()
    };

    // 添加到历史记录
    this.memoryHistory.push(memoryInfo);
    if (this.memoryHistory.length > this.MAX_HISTORY_SIZE) {
      this.memoryHistory.shift();
    }

    // 检查内存使用率
    const usagePercentage = (memoryInfo.used / memoryInfo.limit) * 100;
    
    // 输出内存使用情况

    // 内存使用率警告
    if (usagePercentage > 80) {
    }

    // 检查内存泄漏趋势
    this.checkMemoryLeakTrend();
  }

  /**
   * 检查内存泄漏趋势
   */
  private checkMemoryLeakTrend(): void {
    if (this.memoryHistory.length < 10) {
      return; // 数据不足，无法判断趋势
    }

    const recent = this.memoryHistory.slice(-10);
    const older = this.memoryHistory.slice(-20, -10);

    if (older.length === 0) {
      return;
    }

    const recentAvg = recent.reduce((sum, info) => sum + info.used, 0) / recent.length;
    const olderAvg = older.reduce((sum, info) => sum + info.used, 0) / older.length;

    const growthRate = ((recentAvg - olderAvg) / olderAvg) * 100;

    if (growthRate > 20) {
    }
  }

  /**
   * 检查内存API是否可用
   */
  private isMemoryAPIAvailable(): boolean {
    return !!(performance as any).memory;
  }

  /**
   * 获取当前内存使用情况
   */
  public getCurrentMemoryInfo(): MemoryInfo | null {
    if (!this.isMemoryAPIAvailable()) {
      return null;
    }

    const memory = (performance as any).memory;
    return {
      used: Math.round(memory.usedJSHeapSize / 1024 / 1024),
      total: Math.round(memory.totalJSHeapSize / 1024 / 1024),
      limit: Math.round(memory.jsHeapSizeLimit / 1024 / 1024),
      timestamp: Date.now()
    };
  }

  /**
   * 获取内存使用历史
   */
  public getMemoryHistory(): MemoryInfo[] {
    return [...this.memoryHistory];
  }

  /**
   * 清理内存历史记录
   */
  public clearHistory(): void {
    this.memoryHistory = [];
  }

  /**
   * 获取内存统计信息
   */
  public getMemoryStats(): {
    current: MemoryInfo | null;
    historyCount: number;
    isMonitoring: boolean;
    averageUsage: number;
    peakUsage: number;
  } {
    const current = this.getCurrentMemoryInfo();
    const historyCount = this.memoryHistory.length;
    
    let averageUsage = 0;
    let peakUsage = 0;
    
    if (this.memoryHistory.length > 0) {
      averageUsage = this.memoryHistory.reduce((sum, info) => sum + info.used, 0) / this.memoryHistory.length;
      peakUsage = Math.max(...this.memoryHistory.map(info => info.used));
    }

    return {
      current,
      historyCount,
      isMonitoring: this.isMonitoring,
      averageUsage: Math.round(averageUsage),
      peakUsage
    };
  }

  /**
   * 强制垃圾回收（如果可用）
   */
  public forceGarbageCollection(): void {
    if (window.gc) {
      window.gc();
    } else {
    }
  }
}

// 导出单例实例
export const memoryMonitor = MemoryMonitor.getInstance();
export default memoryMonitor;
