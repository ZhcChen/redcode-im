import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { LogicalSize } from '@tauri-apps/api/dpi'
import { currentMonitor } from '@tauri-apps/api/window'
import { invoke } from '@tauri-apps/api/core'

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

  // 获取当前显示器信息
  let monitor: any
  let monitorAvailable = false
  try {
    monitor = await currentMonitor()
    monitorAvailable = true
  } catch (error) {
    console.warn('[setWindowSizeSafe] Failed to get monitor info:', error)
    monitor = null
  }

  // 设置默认值，如果无法获取显示器信息，假设为常见的屏幕尺寸
  const scaleFactor = monitor?.scaleFactor ?? 1
  // 如果获取不到屏幕信息，默认为常见的 1920x1080
  const screenW = monitor?.size?.width ?? 1920
  const screenH = monitor?.size?.height ?? 1080

  // 计算逻辑屏幕尺寸
  const screenWLogical = Math.round(screenW / scaleFactor)
  const screenHLogical = Math.round(screenH / scaleFactor)

  console.log(`[setWindowSizeSafe] Environment:`)
  console.log(`  - Screen: ${screenWLogical}x${screenHLogical}px (logical), ${screenW}x${screenH}px (physical)`)
  console.log(`  - DPI scale: ${scaleFactor}`)
  console.log(`  - Target: ${targetWidth}x${targetHeight}px`)

  // 预留顶部任务栏/标题栏空间，避免贴边被遮挡（Windows 小屏常见）
  // 在高 DPI 下，边距也需要缩放
  const verticalMarginLogical = 96
  const horizontalMarginLogical = 40  // 添加左右边距
  const verticalMarginPhysical = verticalMarginLogical * scaleFactor
  const horizontalMarginPhysical = horizontalMarginLogical * scaleFactor

  // 期望的物理尺寸
  const desiredWPhysical = targetWidth * scaleFactor
  const desiredHPhysical = targetHeight * scaleFactor

  // 计算最大允许的物理尺寸（考虑屏幕边距）
  // 移除 Math.max 的最小值限制，让窗口可以使用更多屏幕空间
  const maxWPhysical = screenW - horizontalMarginPhysical
  const maxHPhysical = screenH - verticalMarginPhysical

  // 计算最终的物理尺寸（不超过屏幕限制）
  const finalWPhysical = Math.min(desiredWPhysical, maxWPhysical)
  const finalHPhysical = Math.min(desiredHPhysical, maxHPhysical)

  // 转换为逻辑尺寸，保证最小尺寸
  const finalWLogical = Math.max(400, finalWPhysical / scaleFactor)
  const finalHLogical = Math.max(300, finalHPhysical / scaleFactor)

  console.log(`[setWindowSizeSafe] Calculated size: ${finalWLogical}x${finalHLogical}px`)
  if (desiredWPhysical > maxWPhysical || desiredHPhysical > maxHPhysical) {
    console.log(`  - Size limited by screen (wanted ${targetWidth}x${targetHeight}px)`)
  }

  // 如果目标尺寸合理（不是过大），尝试直接设置
  const isReasonableSize = targetWidth <= 1920 && targetHeight <= 1080

  // 标记当前为程序设定尺寸，避免 onResized 将其视作用户操作
  suppressResizeFlag = true

  if (isReasonableSize && desiredWPhysical <= maxWPhysical) {
    // 尝试直接设置目标尺寸
    try {
      console.log('[setWindowSizeSafe] Attempting direct size:', targetWidth, targetHeight)
      await win.setSize(new LogicalSize(targetWidth, targetHeight))
      await win.center()
      console.log('[setWindowSizeSafe] Direct size set successfully')
    } catch (error) {
      console.warn('[setWindowSizeSafe] Direct size failed, using calculated:', error)
      // 如果直接设置失败，使用计算后的安全尺寸
      await win.setSize(new LogicalSize(finalWLogical, finalHLogical))
      await win.center()
    }
  } else {
    // 使用计算后的安全尺寸
    console.log('[setWindowSizeSafe] Using calculated safe size')
    await win.setSize(new LogicalSize(finalWLogical, finalHLogical))
    await win.center()
  }

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

// 使用 Rust 端设置窗口尺寸（推荐方法）
export async function setWindowSizeViaRust(width: number, height: number): Promise<boolean> {
  console.log('[setWindowSizeViaRust] ========== START ==========')
  console.log('[setWindowSizeViaRust] Parameters:', { width, height })
  console.log('[setWindowSizeViaRust] Called at:', new Date().toISOString())

  try {
    suppressResizeFlag = true
    console.log('[setWindowSizeViaRust] suppressResizeFlag set to true')

    // 调用 Rust 端的函数
    console.log('[setWindowSizeViaRust] About to invoke "set_window_size_and_center"...')
    console.log('[setWindowSizeViaRust] invoke parameters:', JSON.stringify({ width, height }))

    await invoke('set_window_size_and_center', { width, height })

    console.log('[setWindowSizeViaRust] invoke() completed successfully!')

    // 验证实际尺寸
    console.log('[setWindowSizeViaRust] Starting size verification...')
    const win = getCurrentWebviewWindow()
    const actualPhysicalSize = await win.innerSize()
    console.log('[setWindowSizeViaRust] Physical size:', actualPhysicalSize)

    const monitor = await currentMonitor().catch((err) => {
      console.log('[setWindowSizeViaRust] currentMonitor() error:', err)
      return null as any
    })
    const scaleFactor = monitor?.scaleFactor ?? 1
    console.log('[setWindowSizeViaRust] Scale factor:', scaleFactor)

    const actualLogicalWidth = Math.round(actualPhysicalSize.width / scaleFactor)
    const actualLogicalHeight = Math.round(actualPhysicalSize.height / scaleFactor)

    console.log('[setWindowSizeViaRust] Verification Results:')
    console.log('  - Target logical:', width, 'x', height, 'px')
    console.log('  - Actual logical:', actualLogicalWidth, 'x', actualLogicalHeight, 'px')
    console.log('  - Physical size:', actualPhysicalSize.width, 'x', actualPhysicalSize.height, 'px')
    console.log('  - Success:', actualLogicalWidth === width && actualLogicalHeight === height)

    setTimeout(() => {
      suppressResizeFlag = false
      console.log('[setWindowSizeViaRust] suppressResizeFlag reset to false (after 200ms)')
    }, 200)

    console.log('[setWindowSizeViaRust] ========== END (SUCCESS) ==========')
    return true
  } catch (error: any) {
    console.error('[setWindowSizeViaRust] ========== ERROR ==========')
    console.error('[setWindowSizeViaRust] Error occurred:', error)
    console.error('[setWindowSizeViaRust] Error message:', error?.message)
    console.error('[setWindowSizeViaRust] Error stack:', error?.stack)
    console.error('[setWindowSizeViaRust] Error type:', typeof error)
    console.error('[setWindowSizeViaRust] Error details:', JSON.stringify(error))
    suppressResizeFlag = false
    console.log('[setWindowSizeViaRust] suppressResizeFlag reset to false (due to error)')
    console.log('[setWindowSizeViaRust] ========== END (FAILED) ==========')
    return false
  }
}

// 直接设置窗口尺寸，不做任何限制（用于测试）
export async function setWindowSizeDirect(width: number, height: number) {
  const win = getCurrentWebviewWindow()
  console.log('[setWindowSizeDirect] Target size:', width, 'x', height, '(logical pixels)')

  try {
    suppressResizeFlag = true
    await win.setSize(new LogicalSize(width, height))
    await win.center()

    // 验证实际设置的尺寸
    const actualPhysicalSize = await win.innerSize()
    const monitor = await currentMonitor().catch(() => null as any)
    const scaleFactor = monitor?.scaleFactor ?? 1

    // 转换为逻辑像素以便理解
    const actualLogicalWidth = actualPhysicalSize.width / scaleFactor
    const actualLogicalHeight = actualPhysicalSize.height / scaleFactor

    console.log('[setWindowSizeDirect] Size set successfully!')
    console.log('  - Logical size:', Math.round(actualLogicalWidth), 'x', Math.round(actualLogicalHeight), 'px')
    console.log('  - Physical size:', actualPhysicalSize.width, 'x', actualPhysicalSize.height, 'px')
    console.log('  - DPI scale factor:', scaleFactor)

    setTimeout(() => {
      suppressResizeFlag = false
    }, 200)

    return true
  } catch (error) {
    console.error('[setWindowSizeDirect] Failed to set size:', error)
    return false
  }
}
