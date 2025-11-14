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
let mouseupHandler: ((event: MouseEvent) => void) | null = null;
let pointerdownHandler: ((event: PointerEvent) => void) | null = null;
let auxclickHandler: ((event: MouseEvent) => void) | null = null;
let wheelHandler: ((event: WheelEvent) => void) | null = null;
let touchendHandler: ((event: TouchEvent) => void) | null = null;
let popstateHandler: ((event: PopStateEvent) => void) | null = null;
let historyOverrideCleanup: (() => void) | null = null;

const MAC_PLATFORM_REGEXP = /mac/i;

const isMac = typeof navigator !== 'undefined'
  ? MAC_PLATFORM_REGEXP.test(navigator.platform || navigator.userAgent)
  : false;

const STOP_EVENT = (event: Event, reason: string) => {
  event.preventDefault();
  event.stopImmediatePropagation();
  return false;
};

const pushDummyHistoryEntry = () => {
  try {
    window.history.pushState({ __navLocked: true, ts: Date.now() }, '', window.location.href);
  } catch (error) {
  }
};

const shouldBlockKeyboardNavigation = (event: KeyboardEvent) => {
  if (event.defaultPrevented) {
    return false;
  }

  const key = event.key;
  const code = event.code;

  // Windows/Linux 使用 Alt+←/→
  if (!isMac && event.altKey && (key === 'ArrowLeft' || key === 'ArrowRight')) {
    return true;
  }

  // Windows 专用 Alt+Backspace
  if (!isMac && event.altKey && key === 'Backspace') {
    return true;
  }

  // macOS / 部分键盘的 Cmd/Ctrl + [ ]
  if ((event.metaKey || event.ctrlKey) && (key === '[' || key === ']' || code === 'BracketLeft' || code === 'BracketRight')) {
    return true;
  }

  // macOS Safari 风格 Cmd + ←/→
  if (isMac && event.metaKey && (key === 'ArrowLeft' || key === 'ArrowRight')) {
    return true;
  }

  // 专用浏览器导航键（部分键盘）
  if (key === 'BrowserBack' || key === 'BrowserForward' || key === 'HistoryBack' || key === 'HistoryForward') {
    return true;
  }

  if (code === 'BrowserBack' || code === 'BrowserForward') {
    return true;
  }

  return false;
};

const shouldBlockMouseNavigation = (button: number) => button === 3 || button === 4;

/**
 * 禁用所有前进后退相关的快捷键
 */
export function disableNavigationShortcuts() {
  if (isDisabled) {
    return;
  }


  // 1. 禁用键盘快捷键
  keydownHandler = (event) => {
    if (shouldBlockKeyboardNavigation(event)) {
      const combo = `${event.metaKey ? 'Cmd+' : ''}${event.ctrlKey ? 'Ctrl+' : ''}${event.altKey ? 'Alt+' : ''}${event.key}`;
      return STOP_EVENT(event, `键盘组合 ${combo}`);
    }
    return true;
  };
  document.addEventListener('keydown', keydownHandler, true);
  window.addEventListener('keydown', keydownHandler, true);

  // 2. 禁用鼠标前进后退按钮
  const mouseBlocker = (event: MouseEvent | PointerEvent) => {
    if (shouldBlockMouseNavigation(event.button)) {
      return STOP_EVENT(event, `鼠标按键 ${event.button}`);
    }
    return true;
  };
  mousedownHandler = (event) => mouseBlocker(event);
  mouseupHandler = (event) => mouseBlocker(event);
  pointerdownHandler = (event) => mouseBlocker(event);
  auxclickHandler = (event) => mouseBlocker(event);
  document.addEventListener('mousedown', mousedownHandler, true);
  document.addEventListener('mouseup', mouseupHandler, true);
  document.addEventListener('pointerdown', pointerdownHandler, true);
  document.addEventListener('auxclick', auxclickHandler, true);

  // 3. 禁用浏览器手势事件 (如果支持)
  if ('onwheel' in window) {
    wheelHandler = (event) => {
      // 如果是水平滚轮且按住修饰键，可能是浏览器手势
      if (event.ctrlKey && Math.abs(event.deltaX) > Math.abs(event.deltaY)) {
        event.preventDefault();
        event.stopPropagation();
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
    }
    lastTouchEnd = now;
  };
  document.addEventListener('touchend', touchendHandler, true);

  // 5. 禁用浏览器历史记录相关的快捷键
  popstateHandler = (event) => {
    // 阻止浏览器的前进后退
    event.preventDefault();
    // 重新推入当前状态，避免影响 SPA 路由
    pushDummyHistoryEntry();
  };
  window.addEventListener('popstate', popstateHandler);

  // 重写 history.back/forward/go，让系统快捷键即使逃逸也无法离开当前页
  const { history } = window;
  const originalBack = history.back.bind(history);
  const originalForward = history.forward.bind(history);
  const originalGo = history.go.bind(history);

  history.back = (() => {
  }) as History['back'];
  history.forward = (() => {
  }) as History['forward'];
  history.go = ((delta?: number) => {
  }) as History['go'];

  historyOverrideCleanup = () => {
    history.back = originalBack as History['back'];
    history.forward = originalForward as History['forward'];
    history.go = originalGo as History['go'];
  };

  // 初始化历史记录栈，确保有一个虚拟的状态可返回
  pushDummyHistoryEntry();

  isDisabled = true;
}

/**
 * 移除禁用快捷键的监听器，恢复正常功能
 */
export function enableNavigationShortcuts() {
  if (!isDisabled) {
    return;
  }


  // 移除所有事件监听器
  if (keydownHandler) {
    document.removeEventListener('keydown', keydownHandler, true);
    window.removeEventListener('keydown', keydownHandler, true);
    keydownHandler = null;
  }

  if (mousedownHandler) {
    document.removeEventListener('mousedown', mousedownHandler, true);
    mousedownHandler = null;
  }

  if (mouseupHandler) {
    document.removeEventListener('mouseup', mouseupHandler, true);
    mouseupHandler = null;
  }

  if (pointerdownHandler) {
    document.removeEventListener('pointerdown', pointerdownHandler, true);
    pointerdownHandler = null;
  }

  if (auxclickHandler) {
    document.removeEventListener('auxclick', auxclickHandler, true);
    auxclickHandler = null;
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

  if (historyOverrideCleanup) {
    historyOverrideCleanup();
    historyOverrideCleanup = null;
  }

  isDisabled = false;
}

/**
 * 获取当前禁用状态
 */
export function getNavigationShortcutsState() {
  return {
    isDisabled
  };
}
