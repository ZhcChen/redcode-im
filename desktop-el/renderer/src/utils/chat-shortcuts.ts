export interface ChatShortcutEventLike {
  key: string;
  ctrlKey: boolean;
  metaKey: boolean;
  shiftKey: boolean;
  altKey: boolean;
  defaultPrevented: boolean;
}

const hasPrimaryModifier = (event: ChatShortcutEventLike) =>
  (event.ctrlKey || event.metaKey) && !event.altKey;

export const isOpenSearchShortcut = (event: ChatShortcutEventLike) =>
  !event.defaultPrevented &&
  hasPrimaryModifier(event) &&
  !event.shiftKey &&
  event.key.toLowerCase() === "f";

export const isSubmitEditShortcut = (event: ChatShortcutEventLike) =>
  !event.defaultPrevented &&
  hasPrimaryModifier(event) &&
  event.key === "Enter";
