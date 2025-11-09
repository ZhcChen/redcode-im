/**
 * 禁用浏览器和鼠标的快捷键功能
 * 包括：
 * - 键盘 Alt+Left (上一页)
 * - 键盘 Alt+Right (下一页)
 * - 鼠标后退按钮 (button4)
 * - 鼠标前进按钮 (button5)
 */

let isDisabled = false;

// 保存事件监听器的引用，以便后续可以移除
let keydownHandler: ((event: KeyboardEvent) => void) | null = null;
let mousedownHandler: ((event: MouseEvent) => void) | null = null;
let wheelHandler: ((event: WheelEvent) => void) | null = null;
let touchendHandler: ((event: TouchEvent) => void) | null = null;
let popstateHandler: ((event: PopStateEvent) => void) | null = null;

/**
 * 禁用所有前进后退相关的快捷键
 */
export function disableNavigationShortcuts() {
  if (isDisabled) {
    console.log('⚠️ 快捷键已经处于禁用状态');
    return;
  }

  console.log('🔒 禁用浏览器前进后退快捷键');

  // 1. 禁用键盘快捷键
  keydownHandler = (event) => {
    // Alt + 左箭头 (上一页)
    if (event.altKey && event.key === 'ArrowLeft') {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止 Alt+Left 快捷键');
      return false;
    }

    // Alt + 右箭头 (下一页)
    if (event.altKey && event.key === 'ArrowRight') {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止 Alt+Right 快捷键');
      return false;
    }

    // Alt + 后退键 (Backspace)
    if (event.altKey && event.key === 'Backspace') {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止 Alt+Backspace 快捷键');
      return false;
    }
  };
  document.addEventListener('keydown', keydownHandler, true);

  // 2. 禁用鼠标前进后退按钮
  mousedownHandler = (event) => {
    // 鼠标后退按钮 (button4)
    if (event.button === 3) {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止鼠标后退按钮 (button4)');
      return false;
    }

    // 鼠标前进按钮 (button5)
    if (event.button === 4) {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止鼠标前进按钮 (button5)');
      return false;
    }
  };
  document.addEventListener('mousedown', mousedownHandler, true);

  // 3. 禁用浏览器手势事件 (如果支持)
  if ('onwheel' in window) {
    wheelHandler = (event) => {
      // 如果是水平滚轮且按住修饰键，可能是浏览器手势
      if (event.ctrlKey && Math.abs(event.deltaX) > Math.abs(event.deltaY)) {
        event.preventDefault();
        event.stopPropagation();
        console.log('🚫 已阻止水平滚轮手势');
        return false;
      }
    };
    document.addEventListener('wheel', wheelHandler, { passive: false });
  }

  // 4. 禁用双指缩放手势
  let lastTouchEnd = 0;
  touchendHandler = (event) => {
    const now = (new Date()).getTime();
    if (now - lastTouchEnd <= 300) {
      event.preventDefault();
      event.stopPropagation();
      console.log('🚫 已阻止双击缩放');
    }
    lastTouchEnd = now;
  };
  document.addEventListener('touchend', touchendHandler, true);

  // 5. 禁用浏览器历史记录相关的快捷键
  popstateHandler = (event) => {
    // 阻止浏览器的前进后退
    event.preventDefault();
    console.log('🚫 已阻止 popstate 事件 (浏览器前进后退)');
    // 可以选择重新推入当前状态，避免影响SPA路由
    window.history.pushState(null, '', window.location.pathname + window.location.search);
  };
  window.addEventListener('popstate', popstateHandler);

  isDisabled = true;
  console.log('✅ 所有前进后退快捷键已禁用');
}

/**
 * 移除禁用快捷键的监听器，恢复正常功能
 */
export function enableNavigationShortcuts() {
  if (!isDisabled) {
    console.log('⚠️ 快捷键已经处于启用状态');
    return;
  }

  console.log('🔓 恢复浏览器前进后退快捷键');

  // 移除所有事件监听器
  if (keydownHandler) {
    document.removeEventListener('keydown', keydownHandler, true);
    keydownHandler = null;
  }

  if (mousedownHandler) {
    document.removeEventListener('mousedown', mousedownHandler, true);
    mousedownHandler = null;
  }

  if (wheelHandler) {
    document.removeEventListener('wheel', wheelHandler, { passive: false } as any);
    wheelHandler = null;
  }

  if (touchendHandler) {
    document.removeEventListener('touchend', touchendHandler, true);
    touchendHandler = null;
  }

  if (popstateHandler) {
    window.removeEventListener('popstate', popstateHandler);
    popstateHandler = null;
  }

  isDisabled = false;
  console.log('✅ 快捷键已恢复');
}

/**
 * 获取当前禁用状态
 */
export function getNavigationShortcutsState() {
  return {
    isDisabled
  };
}