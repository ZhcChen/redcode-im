/**
 * API 统一导出文件
 * 提供所有 API 接口的统一访问入口
 */

// 导出配置
export * from './config';

// 导出 HTTP 客户端
export * from './http';

// 导出系统相关 API
export * from './system';

// 导出用户相关 API
export { UserApi } from './user';
export type { UserInfo } from './user';

// 导出好友相关 API
export { FriendApi } from './friend';
export type { FriendInfo, FriendApply } from './friend';

// 导出账户相关 API
export { 
  AccountApi, 
  TransactionType,
  TransactionStatus,
  getTransactionTypeName,
  getTransactionStatusName
} from './account';
export type { 
  AccountRecord, 
  AddAccountRecordParams, 
  UpdateAccountRecordParams, 
  GetAccountRecordListParams
} from './account';

// 导出群聊相关 API
export * from './group';

// 导出消息相关 API
export * from './message';

// 导出朋友圈相关 API
export * from './friendCircle';

// 导出 AI 聊天相关 API
export * from './chatgpt';

// 导出音乐相关 API
export * from './music';

// 导出文件相关 API
export * from './file';

// 统一的 API 对象，方便使用
import { SystemApi } from './system';
import { UserApi } from './user';
import { FriendApi } from './friend';
import { AccountApi } from './account';
import { GroupApi } from './group';
import { MessageApi } from './message';
import { FriendCircleApi, FriendCircleCommentApi } from './friendCircle';
import { ChatGptApi } from './chatgpt';
import { MusicApi } from './music';
import { FileApi } from './file';

/**
 * 统一的 API 接口对象
 * 使用方式：
 * import { api } from '@/api';
 * api.system.login({ username: 'test', password: '123456' });
 */
export const api = {
  // 系统相关接口
  system: SystemApi,
  
  // 用户相关接口
  user: UserApi,
  
  // 好友相关接口
  friend: FriendApi,
  
  // 账户相关接口
  account: AccountApi,
  
  // 群聊相关接口
  group: GroupApi,
  
  // 消息相关接口
  message: MessageApi,
  
  // 朋友圈相关接口
  friendCircle: {
    // 朋友圈管理
    ...FriendCircleApi,
    // 朋友圈评论
    comment: FriendCircleCommentApi
  },
  
  // AI 聊天相关接口
  chatgpt: ChatGptApi,
  
  // 音乐相关接口
  music: MusicApi,
  
  // 文件相关接口
  file: FileApi
};

// 默认导出
export default api;

/**
 * API 使用示例：
 * 
 * // 方式1：直接导入具体的 API 类
 * import { SystemApi, UserApi } from '@/api';
 * const loginResult = await SystemApi.login({ username: 'test', password: '123456' });
 * const userInfo = await UserApi.getUserAccountInfo();
 * 
 * // 方式2：使用统一的 api 对象
 * import { api } from '@/api';
 * const loginResult = await api.system.login({ username: 'test', password: '123456' });
 * const userInfo = await api.user.getUserAccountInfo();
 * 
 * // 方式3：默认导入
 * import api from '@/api';
 * const loginResult = await api.system.login({ username: 'test', password: '123456' });
 * const userInfo = await api.user.getUserAccountInfo();
 * 
 * // 群聊相关 API 使用示例
 * const groupList = await api.group.getMyChatGroupList();
 * const members = await api.group.member.getChatGroupMembers({ groupId: 'xxx' });
 * const redPacketResult = await api.group.redPacket.sendRedBag({ receiverId: 'xxx', amount: 100 });
 * 
 * // 朋友圈相关 API 使用示例
 * const circleList = await api.friendCircle.getCircleDataList();
 * const commentResult = await api.friendCircle.comment.handleComment({ circleId: 'xxx', content: '评论内容' });
 */
