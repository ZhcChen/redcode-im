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

  console.log(`[setWindowSizeSafe] Monitor info:`, {
    scaleFactor,
    screenW,
    screenH,
    targetWidth,
    targetHeight
  })

  // 预留顶部任务栏/标题栏空间，避免贴边被遮挡（Windows 小屏常见）
  // 在高 DPI 下，边距也需要缩放
  const verticalMarginLogical = 96
  const horizontalMarginLogical = 0
  const verticalMarginPhysical = verticalMarginLogical * scaleFactor
  const horizontalMarginPhysical = horizontalMarginLogical * scaleFactor

  // 期望的物理尺寸
  const desiredWPhysical = targetWidth * scaleFactor
  const desiredHPhysical = targetHeight * scaleFactor

  // 计算最大允许的物理尺寸（考虑屏幕边距）
  const maxWPhysical = Math.max(400 * scaleFactor, screenW - horizontalMarginPhysical)
  const maxHPhysical = Math.max(300 * scaleFactor, screenH - verticalMarginPhysical)

  // 计算最终的逻辑尺寸（先限制物理尺寸，然后转换为逻辑尺寸）
  const finalWPhysical = Math.min(desiredWPhysical, maxWPhysical)
  const finalHPhysical = Math.min(desiredHPhysical, maxHPhysical)

  const finalWLogical = Math.max(400, finalWPhysical / scaleFactor)
  const finalHLogical = Math.max(300, finalHPhysical / scaleFactor)

  console.log(`[setWindowSizeSafe] Final calculated size:`, {
    finalWLogical,
    finalHLogical,
    finalWPhysical,
    finalHPhysical,
    desiredWPhysical,
    desiredHPhysical,
    maxWPhysical,
    maxHPhysical
  })

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
