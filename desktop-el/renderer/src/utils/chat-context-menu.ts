export interface ContextMenuPoint {
  x: number;
  y: number;
}

export interface ContextMenuRect {
  menuWidth: number;
  menuHeight: number;
  viewportWidth: number;
  viewportHeight: number;
  padding?: number;
}

export interface ChatContextMenuLabels {
  pinLabel: string;
  muteLabel: string;
  deleteLabel: string;
}

export const clampContextMenuPosition = (
  point: ContextMenuPoint,
  rect: ContextMenuRect,
): ContextMenuPoint => {
  const padding = rect.padding ?? 8;
  return {
    x: Math.min(
      Math.max(padding, point.x),
      Math.max(padding, rect.viewportWidth - rect.menuWidth - padding),
    ),
    y: Math.min(
      Math.max(padding, point.y),
      Math.max(padding, rect.viewportHeight - rect.menuHeight - padding),
    ),
  };
};

export const getChatContextMenuLabels = (state: {
  isPinned: boolean;
  isMuted: boolean;
}): ChatContextMenuLabels => ({
  pinLabel: state.isPinned ? "取消置顶" : "置顶",
  muteLabel: state.isMuted ? "允许消息通知" : "消息免打扰",
  deleteLabel: "删除对话",
});
