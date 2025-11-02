import { createApp } from 'vue'
import Toast from '@/components/Toast.vue'

interface ToastOptions {
  message: string
  type?: 'info' | 'success' | 'warning' | 'error'
  duration?: number
}

type ToastAppInstance = ReturnType<typeof createApp> | null

class ToastManager {
  private toastInstance: ToastAppInstance = null
  private container: HTMLElement | null = null

  show(options: ToastOptions) {
    // 如果已有 toast 在显示，先关闭它
    this.close()

    // 创建容器元素
    this.container = document.createElement('div')
    document.body.appendChild(this.container)

    // 创建 Vue 应用实例
    const self = this
    this.toastInstance = createApp(Toast, {
      ...options,
      visible: true,
      onClose: () => self.close()
    })

    // 挂载到容器
    this.toastInstance.mount(this.container)
  }

  close() {
    if (this.toastInstance && this.container) {
      this.toastInstance.unmount()
      if (this.container.parentNode) {
        this.container.parentNode.removeChild(this.container)
      }
      this.toastInstance = null
      this.container = null
    }
  }

  // 便捷方法
  info(message: string, duration?: number) {
    this.show({ message, type: 'info', duration })
  }

  success(message: string, duration?: number) {
    this.show({ message, type: 'success', duration })
  }

  warning(message: string, duration?: number) {
    this.show({ message, type: 'warning', duration })
  }

  error(message: string, duration?: number) {
    this.show({ message, type: 'error', duration })
  }
}

// 创建全局实例
export const toast = new ToastManager()

// 导出类型
export type { ToastOptions }
export default toast
