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

// 导出群聊相关 API
export * from './group';

// 导出消息相关 API
export * from './message';

// 导出文件相关 API
export * from './file';
export * from './version';
export { SettingsApi } from './settings';
export type { DocumentContent } from './settings';

// 统一的 API 对象，方便使用
import { SystemApi } from './system';
import { UserApi } from './user';
import { FriendApi } from './friend';
import { GroupApi } from './group';
import { MessageApi } from './message';
import { FileApi } from './file';
import { VersionApi } from './version';
import { SettingsApi } from './settings';

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

  // 群聊相关接口
  group: GroupApi,

  // 消息相关接口
  message: MessageApi,

  // 文件相关接口
  file: FileApi,

  // 版本相关接口
  version: VersionApi,

  // 系统设置相关接口
  settings: SettingsApi
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
 */
