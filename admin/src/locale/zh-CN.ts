import localeMessageBox from '@/components/message-box/locale/zh-CN';
import localeLogin from '@/views/login/locale/zh-CN';

import localeWorkplace from '@/views/dashboard/workplace/locale/zh-CN';
/** simple */
import localeMonitor from '@/views/dashboard/monitor/locale/zh-CN';

import localeUserManagement from '@/views/user-management/list/locale/zh-CN';
import localeCaptchaSettings from '@/views/settings/captcha/locale/zh-CN';
import localePrivacyPolicy from '@/views/settings/privacy-policy/locale/zh-CN';
import localeUserAgreement from '@/views/settings/user-agreement/locale/zh-CN';
import localeGeneralSettings from '@/views/settings/general/locale/zh-CN';
import localeApiTest from '@/views/settings/api-test/locale/zh-CN';
import localePushSettings from '@/views/settings/push/locale/zh-CN';
import localeChatHistory from '@/views/chat-history/locale/zh-CN';
import localeFeedback from '@/views/feedback/list/locale/zh-CN';
import localeIpinfoToken from '@/views/settings/ipinfo-token/locale/zh-CN';
import localeReport from '@/views/report/list/locale/zh-CN';
import localeStorageProvider from '@/views/settings/storage-provider/locale/zh-CN';
import localeCosTest from '@/views/settings/cos-test/locale/zh-CN';
import localeFileUploadAudit from '@/views/operations/file-upload-audit/locale/zh-CN';
import localeSystemLog from '@/views/dashboard/system-log/locale/zh-CN';
import localePushLog from '@/views/operations/push-log/locale/zh-CN';
import localeApiMetrics from '@/views/operations/api-metrics/locale/zh-CN';
import localeDataCleanup from '@/views/settings/data-cleanup/locale/zh-CN';
import localeEmojiPack from '@/views/settings/emoji-pack/locale/zh-CN';
import localeUserProfile from '@/views/settings/user-profile/locale/zh-CN';
import localeVersionManagement from '@/views/version-management/locale/zh-CN';
/** simple end */
import { zhCNCommonMessages } from './common';
import localeSettings from './zh-CN/settings';

export default {
  'menu.dashboard': '仪表盘',
  'menu.userManagement': '用户管理',
  'menu.userManagement.list': '用户列表',
  'menu.userManagement.feedback': '用户反馈',
  'menu.userManagement.reports': '举报记录',
  'menu.userManagement.chatHistory': '用户聊天记录',
  'menu.chatHistory.room': '房间聊天记录',
  'menu.chatHistory.user': '用户聊天记录',
  'menu.operations': '运维管理',
  'menu.operations.systemLog': '系统日志',
  'menu.operations.pushLog': 'Push 日志',
  'menu.operations.storageProvider': '对象存储提供商',
  'menu.operations.cosTest': 'COS 测试',
  'menu.operations.ipinfoToken': 'IP地理位置Token',
  'menu.operations.dataCleanup': '数据清理',
  'menu.operations.apiMetrics': 'API 性能监控',
  'menu.operations.fileUploadAudit': '文件内容审核',
  'menu.settings.storageProvider': '对象存储提供商',
  'menu.settings.cosTest': 'COS 测试',
  'menu.settings.ipinfoToken': 'IP地理位置Token',
  'menu.settings.dataCleanup': '数据清理',
  'menu.settings': '系统设置',
  'menu.settings.captcha': '验证码设置',
  'menu.settings.privacyPolicy': '隐私协议',
  'menu.settings.userAgreement': '用户协议',
  'menu.settings.general': '通用设置',
  'menu.settings.push': 'Push 通知',
  'menu.settings.emojiPack': '贴纸设置',
  'menu.settings.userProfile': '个人设置',
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
  'app.brand': 'IM 管理后台',
  ...zhCNCommonMessages,
  ...localeSettings,
  ...localeMessageBox,
  ...localeLogin,
  ...localeWorkplace,
  /** simple */
  ...localeMonitor,
  ...localeUserManagement,
  ...localeCaptchaSettings,
  ...localePrivacyPolicy,
  ...localeUserAgreement,
  ...localeGeneralSettings,
  ...localeApiTest,
  ...localePushSettings,
  ...localeChatHistory,
  ...localeFeedback,
  ...localeIpinfoToken,
  ...localeReport,
  ...localeStorageProvider,
  ...localeCosTest,
  ...localeFileUploadAudit,
  ...localeSystemLog,
  ...localePushLog,
  ...localeApiMetrics,
  ...localeDataCleanup,
  ...localeEmojiPack,
  ...localeUserProfile,
  ...localeVersionManagement,
  /** simple end */
};
