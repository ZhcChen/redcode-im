import localeMessageBox from '@/components/message-box/locale/zh-CN';
import localeLogin from '@/views/login/locale/zh-CN';

import localeWorkplace from '@/views/dashboard/workplace/locale/zh-CN';
/** simple */
import localeMonitor from '@/views/dashboard/monitor/locale/zh-CN';

import localeUserManagement from '@/views/user-management/list/locale/zh-CN';
import localeCaptchaSettings from '@/views/settings/captcha/locale/zh-CN';
import localeChatHistory from '@/views/chat-history/locale/zh-CN';
/** simple end */
import localeSettings from './zh-CN/settings';

export default {
  'menu.dashboard': '仪表盘',
  'menu.server.dashboard': '仪表盘-服务端',
  'menu.server.workplace': '工作台-服务端',
  'menu.server.monitor': '实时监控-服务端',
  'menu.userManagement': '用户管理',
  'menu.userManagement.list': '用户列表',
  'menu.chatHistory': '聊天记录',
  'menu.chatHistory.list': '聊天记录列表',
  'menu.chatHistory.room': '房间聊天记录',
  'menu.chatHistory.user': '用户聊天记录',
  'menu.settings': '系统设置',
  'menu.settings.captcha': '验证码设置',
  'menu.settings.privacyPolicy': '隐私协议',
  'menu.settings.userAgreement': '用户协议',
  'menu.settings.storageProvider': '文件上传提供商',
  'menu.settings.cosTest': 'COS 测试',
  'menu.settings.general': '通用设置',
  'menu.version': '版本管理',
  'menu.version.frontend': 'App客户端',
  'menu.version.desktop': '桌面客户端',
  'menu.version.hotUpdate': '热更新管理',
  'menu.version.hotUpdateEvents': '热更新上报',
  'menu.list': '列表页',
  'menu.result': '结果页',
  'menu.exception': '异常页',
  'menu.form': '表单页',
  'menu.profile': '详情页',
  'menu.visualization': '数据可视化',
  'menu.user': '个人中心',
  'navbar.docs': '文档中心',
  'navbar.action.locale': '切换为中文',
  ...localeSettings,
  ...localeMessageBox,
  ...localeLogin,
  ...localeWorkplace,
  /** simple */
  ...localeMonitor,
  ...localeUserManagement,
  ...localeCaptchaSettings,
  ...localeChatHistory,
  /** simple end */
};
