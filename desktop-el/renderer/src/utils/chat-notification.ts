import type { ChatWebSocketPush } from "@/api/chat";
import type { HomeView } from "@/store/session";

type ChatMessagePush = Extract<ChatWebSocketPush, { type: "message" }>;

export interface ChatNotificationPayload {
  title: string;
  body: string;
}

export interface ChatNotificationPlan {
  shouldNotify: boolean;
  payload: ChatNotificationPayload | null;
}

interface GetChatNotificationPlanParams {
  push: ChatWebSocketPush | null;
  currentUserId: string;
  activeView: HomeView;
  isWindowFocused: boolean;
}

const MESSAGE_TYPE_PREVIEW: Record<string, string> = {
  text: "[消息]",
  image: "[图片]",
  audio: "[语音]",
  video: "[视频]",
  file: "[文件]",
  mixed: "[多媒体消息]",
  system: "[系统消息]",
};

const isMessagePush = (push: ChatWebSocketPush | null): push is ChatMessagePush =>
  push?.type === "message";

const buildPreview = (push: ChatMessagePush): string => {
  const content = push.content.trim().replace(/\s+/g, " ");
  if (content) {
    return content;
  }

  return MESSAGE_TYPE_PREVIEW[push.message_type] ?? "[消息]";
};

const buildTitle = (push: ChatMessagePush): string =>
  push.sender_nickname?.trim() || push.sender_username.trim() || "新消息";

export const getChatNotificationPlan = (
  params: GetChatNotificationPlanParams,
): ChatNotificationPlan => {
  const { push, currentUserId, activeView, isWindowFocused } = params;
  if (!isMessagePush(push)) {
    return {
      shouldNotify: false,
      payload: null,
    };
  }

  if (push.sender_id === currentUserId || push.message_type === "system") {
    return {
      shouldNotify: false,
      payload: null,
    };
  }

  if (activeView === "chat" && isWindowFocused) {
    return {
      shouldNotify: false,
      payload: null,
    };
  }

  return {
    shouldNotify: true,
    payload: {
      title: buildTitle(push),
      body: buildPreview(push),
    },
  };
};
