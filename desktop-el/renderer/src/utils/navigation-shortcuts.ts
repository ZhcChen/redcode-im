export interface KeyboardNavigationEventLike {
  key: string;
  code?: string;
  altKey: boolean;
  ctrlKey: boolean;
  metaKey: boolean;
  defaultPrevented: boolean;
}

let isDisabled = false;
let keydownHandler: ((event: KeyboardEvent) => void) | null = null;
let mousedownHandler: ((event: MouseEvent) => void) | null = null;
let mouseupHandler: ((event: MouseEvent) => void) | null = null;
let pointerdownHandler: ((event: PointerEvent) => void) | null = null;
let auxclickHandler: ((event: MouseEvent) => void) | null = null;
let popstateHandler: ((event: PopStateEvent) => void) | null = null;
let historyOverrideCleanup: (() => void) | null = null;

const MAC_PLATFORM_REGEXP = /mac/i;

const stopEvent = (event: Event) => {
  event.preventDefault();
  event.stopImmediatePropagation();
};

const shouldBlockMouseNavigation = (button: number) => button === 3 || button === 4;

const pushDummyHistoryEntry = () => {
  if (typeof window === "undefined") {
    return;
  }
  try {
    window.history.pushState(
      { __desktopElNavLocked: true, ts: Date.now() },
      "",
      window.location.href,
    );
  } catch {
    // Ignore browsers that reject pushState for the current URL.
  }
};

export const shouldBlockKeyboardNavigation = (
  event: KeyboardNavigationEventLike,
  isMac: boolean,
) => {
  if (event.defaultPrevented) {
    return false;
  }

  const key = event.key;
  const code = event.code ?? "";

  if (!isMac && event.altKey && (key === "ArrowLeft" || key === "ArrowRight")) {
    return true;
  }
  if (!isMac && event.altKey && key === "Backspace") {
    return true;
  }
  if (
    (event.metaKey || event.ctrlKey) &&
    (key === "[" ||
      key === "]" ||
      code === "BracketLeft" ||
      code === "BracketRight")
  ) {
    return true;
  }
  if (isMac && event.metaKey && (key === "ArrowLeft" || key === "ArrowRight")) {
    return true;
  }
  if (
    key === "BrowserBack" ||
    key === "BrowserForward" ||
    key === "HistoryBack" ||
    key === "HistoryForward"
  ) {
    return true;
  }
  if (code === "BrowserBack" || code === "BrowserForward") {
    return true;
  }

  return false;
};

const detectIsMac = () => {
  if (typeof navigator === "undefined") {
    return false;
  }
  return MAC_PLATFORM_REGEXP.test(navigator.platform || navigator.userAgent);
};

export const disableNavigationShortcuts = () => {
  if (
    isDisabled ||
    typeof window === "undefined" ||
    typeof document === "undefined"
  ) {
    return;
  }

  const isMac = detectIsMac();

  keydownHandler = (event) => {
    if (shouldBlockKeyboardNavigation(event, isMac)) {
      stopEvent(event);
    }
  };
  document.addEventListener("keydown", keydownHandler, true);
  window.addEventListener("keydown", keydownHandler, true);

  const mouseBlocker = (event: MouseEvent | PointerEvent) => {
    if (shouldBlockMouseNavigation(event.button)) {
      stopEvent(event);
    }
  };
  mousedownHandler = (event) => mouseBlocker(event);
  mouseupHandler = (event) => mouseBlocker(event);
  pointerdownHandler = (event) => mouseBlocker(event);
  auxclickHandler = (event) => mouseBlocker(event);
  document.addEventListener("mousedown", mousedownHandler, true);
  document.addEventListener("mouseup", mouseupHandler, true);
  document.addEventListener("pointerdown", pointerdownHandler, true);
  document.addEventListener("auxclick", auxclickHandler, true);

  popstateHandler = (event) => {
    event.preventDefault();
    pushDummyHistoryEntry();
  };
  window.addEventListener("popstate", popstateHandler);

  const { history } = window;
  const originalBack = history.back.bind(history);
  const originalForward = history.forward.bind(history);
  const originalGo = history.go.bind(history);

  history.back = (() => {}) as History["back"];
  history.forward = (() => {}) as History["forward"];
  history.go = (() => {}) as History["go"];

  historyOverrideCleanup = () => {
    history.back = originalBack as History["back"];
    history.forward = originalForward as History["forward"];
    history.go = originalGo as History["go"];
  };

  pushDummyHistoryEntry();
  isDisabled = true;
};

export const enableNavigationShortcuts = () => {
  if (
    !isDisabled ||
    typeof window === "undefined" ||
    typeof document === "undefined"
  ) {
    return;
  }

  if (keydownHandler) {
    document.removeEventListener("keydown", keydownHandler, true);
    window.removeEventListener("keydown", keydownHandler, true);
    keydownHandler = null;
  }
  if (mousedownHandler) {
    document.removeEventListener("mousedown", mousedownHandler, true);
    mousedownHandler = null;
  }
  if (mouseupHandler) {
    document.removeEventListener("mouseup", mouseupHandler, true);
    mouseupHandler = null;
  }
  if (pointerdownHandler) {
    document.removeEventListener("pointerdown", pointerdownHandler, true);
    pointerdownHandler = null;
  }
  if (auxclickHandler) {
    document.removeEventListener("auxclick", auxclickHandler, true);
    auxclickHandler = null;
  }
  if (popstateHandler) {
    window.removeEventListener("popstate", popstateHandler);
    popstateHandler = null;
  }
  if (historyOverrideCleanup) {
    historyOverrideCleanup();
    historyOverrideCleanup = null;
  }

  isDisabled = false;
};
