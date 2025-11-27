/**
 * WebSocket 相关类型定义
 */

// WebSocket 业务信息类型
export const BUSINESS_CODE = {
  ping: "WSHeartBeat", // 心跳
  FriendBindChange: "FriendBindChange",
  DeleteFriend: "FriendDeleteNotify",
  launchGroup: "LaunchGroup", // 发起群聊
  chatting: "Chatting", // 聊天信息
  deleteGroup: 'DeleteGroup', // 解散群组
  AI: "AI", // AI
  FriendCircle: 'FriendCircle', // 朋友圈动态
  Calling: 'Calling'
} as const;

// 消息类型
export const MSG_TYPE = {
  SYSTEM_MSG: 0, // 系统信息
  USER_MSG: 1, // 用户信息
} as const;

// 系统消息类型
export const SYS_MSG_TYPE = {
  updateGroupName: 'updateGroupName', // 修改群名称
  updateGroupAvatar: 'updateGroupAvatar', // 修改群头像
  updateGroupNotice: 'updateGroupNotice', // 修改群公告
  quitGroup: 'quitGroup', // 主动退出群组
  joinGroupMember: 'joinGroupMember', // 添加、邀请群成员
  deleteGroupMember: 'deleteGroupMember', // 删除群成员
  revertMessage: "revertMessage", // 撤回信息
} as const;

// 内容类型
export const CONTENT_TYPE = {
  TEXT_CONTENT_TYPE: 1, // 文本信息
  IMG_CONTENT_TYPE: 2, // 图片信息
  VIDEO_CONTENT_TYPE: 3, // 视频信息
  AUDIO_CONTENT_TYPE: 4, // 语音信息
  FILE_CONTENT_TYPE: 5, // 文件
  OTHER_CONTENT_TYPE: 6, // 位置类型
  RED_BAG_CONTENT_TYPE: 7, // 红包信息
  FRIEND_INFO_CONTENT_TYPE: 8, // 名片信息
  LOCATION_CONTENT_TYPE: 9, // 位置信息
  CHAT_RECORD_CONTENT_TYPE: 10, // 合并聊天记录信息
  IMG_TEXT_COM_CONTENT_TYPE: 11, // 图文信息
  VIDEO_TEXT_COM_CONTENT_TYPE: 12, // 视频图文
  TRANSFER_CONTENT_TYPE: 13, // 转账信息
} as const;

// WebSocket 连接参数
export interface WebSocketParams {
  userId: string;
  token: string;
  chatGroupId?: string;
}

// WebSocket 消息结构
export interface WebSocketMessage {
  code: string;
  message: any;
}

// 聊天消息对象
export interface ChatMessage {
  id: string;
  userId: string;
  chatGroupId: string;
  messageType: number;
  content: any;
  createTime: string;
  meFlag?: boolean;
}

// WebSocket 连接状态
export interface WebSocketState {
  socket: WebSocket | null;
  isOnline: boolean;
  reconnectCount: number;
  heartbeatTimer: number | null;
  reconnectTimer: number | null;
}

// Tauri 事件负载类型（与 Rust 端 TauriEventPayload 对应）
export type TauriEventPayload =
  | { type: 'Authed'; payload: { user_id: string; conn_id: string } }
  | { type: 'Joined'; payload: { room_id: string } }
  | { type: 'Left'; payload: { room_id: string } }
  | { type: 'Message'; payload: any }
  | { type: 'MessageRead'; payload: any }
  | { type: 'MessageUpdate'; payload: any }
  | { type: 'PinUpdate'; payload: any }
  | { type: 'FriendRequestUpdate'; payload: { pending_count: number } }
  | { type: 'RoomCreated'; payload: any }
  | { type: 'RoomUpdated'; payload: any }
  | { type: 'UserBanned'; payload: { user_id: string; reason: string } }
  | { type: 'GroupDissolved'; payload: { room_id: string } }
  | { type: 'GroupOwnerTransferred'; payload: { room_id: string; old_owner_id: string; new_owner_id: string } }
  | { type: 'Error'; payload: { message: string } }
  | { type: 'Pong'; payload: null };

// 带用户标识的事件包装（与 Rust 端 UserEventWrapper 对应）
export interface UserEventWrapper {
  /** 事件所属的用户ID */
  user_id: string;
  /** 事件类型 */
  type: string;
  /** 事件负载 */
  payload?: any;
}
