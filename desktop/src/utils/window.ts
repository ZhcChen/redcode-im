import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { LogicalSize } from '@tauri-apps/api/dpi'
import { currentMonitor } from '@tauri-apps/api/window'

// 记录用户是否主动调整过窗口，避免后续逻辑反复覆盖
let userResized = false
let suppressResizeFlag = false
let resizeListenerInstalled = false

export const markUserResized = () => {
  userResized = true
}

export const resetUserResizedFlag = () => {
  userResized = false
}

// 在设定窗口尺寸前，依据当前显示器可用空间做裁剪，避免在高 DPI / 小屏上超出屏幕
export async function setWindowSizeSafe(targetWidth: number, targetHeight: number) {
  const win = getCurrentWebviewWindow()
  // 获取当前显示器信息，若失败则退回空对象
  const monitor = await currentMonitor().catch(() => null as any)

  const scaleFactor = monitor?.scaleFactor ?? 1
  const screenW = monitor?.size?.width ?? targetWidth * scaleFactor
  const screenH = monitor?.size?.height ?? targetHeight * scaleFactor

  // 预留顶部任务栏/标题栏空间，避免贴边被遮挡（Windows 小屏常见）
  const verticalMargin = 96
  const horizontalMargin = 0

  const desiredWPhysical = targetWidth * scaleFactor
  const desiredHPhysical = targetHeight * scaleFactor

  const maxWPhysical = Math.max(400 * scaleFactor, screenW - horizontalMargin)
  const maxHPhysical = Math.max(300 * scaleFactor, screenH - verticalMargin)

  const finalWLogical = Math.max(400, Math.min(desiredWPhysical, maxWPhysical) / scaleFactor)
  const finalHLogical = Math.max(300, Math.min(desiredHPhysical, maxHPhysical) / scaleFactor)

  // 标记当前为程序设定尺寸，避免 onResized 将其视作用户操作
  suppressResizeFlag = true
  await win.setSize(new LogicalSize(finalWLogical, finalHLogical))
  await win.center()
  // 轻微延迟后恢复监听
  setTimeout(() => {
    suppressResizeFlag = false
  }, 200)
}

// 监听用户主动调整窗口尺寸，需在入口处调用一次
export async function installUserResizeListener() {
  if (resizeListenerInstalled) return
  resizeListenerInstalled = true
  const win = getCurrentWebviewWindow()
  await win.onResized(() => {
    if (suppressResizeFlag) return
    userResized = true
  })
}

export const hasUserResized = () => userResized
