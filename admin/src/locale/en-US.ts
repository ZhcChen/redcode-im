import localeMessageBox from '@/components/message-box/locale/en-US';
import localeLogin from '@/views/login/locale/en-US';

import localeWorkplace from '@/views/dashboard/workplace/locale/en-US';
/** simple */
import localeMonitor from '@/views/dashboard/monitor/locale/en-US';

import localeUserManagement from '@/views/user-management/list/locale/en-US';
import localeCaptchaSettings from '@/views/settings/captcha/locale/en-US';
import localeFeedback from '@/views/feedback/list/locale/en-US';
import localeStorageProvider from '@/views/settings/storage-provider/locale/en-US';
import localeCosTest from '@/views/settings/cos-test/locale/en-US';
import localeFileUploadAudit from '@/views/operations/file-upload-audit/locale/en-US';
import localeSystemLog from '@/views/dashboard/system-log/locale/en-US';
import localePushLog from '@/views/operations/push-log/locale/en-US';
import localeApiMetrics from '@/views/operations/api-metrics/locale/en-US';
import localeDataCleanup from '@/views/settings/data-cleanup/locale/en-US';
/** simple end */
import localeSettings from './en-US/settings';

export default {
  'menu.dashboard': 'Dashboard',
  'menu.userManagement': 'User Management',
  'menu.userManagement.list': 'User List',
  'menu.userManagement.feedback': 'User Feedback',
  'menu.userManagement.reports': 'Reports',
  'menu.userManagement.chatHistory': 'User Chat History',
  'menu.chatHistory.room': 'Room Chat History',
  'menu.chatHistory.user': 'User Chat History',
  'menu.operations': 'Operations',
  'menu.operations.systemLog': 'System Logs',
  'menu.operations.pushLog': 'Push Logs',
  'menu.operations.storageProvider': 'Object Storage Provider',
  'menu.operations.cosTest': 'COS Test',
  'menu.operations.ipinfoToken': 'IP Geolocation Token',
  'menu.operations.dataCleanup': 'Data Cleanup',
  'menu.operations.apiMetrics': 'API Metrics',
  'menu.operations.fileUploadAudit': 'File Upload Audit',
  'menu.settings.storageProvider': 'Object Storage Provider',
  'menu.settings.cosTest': 'COS Test',
  'menu.settings.ipinfoToken': 'IP Geolocation Token',
  'menu.settings.dataCleanup': 'Data Cleanup',
  'menu.settings': 'System Settings',
  'menu.settings.captcha': 'Captcha Settings',
  'menu.settings.privacyPolicy': 'Privacy Agreement',
  'menu.settings.userAgreement': 'User Agreement',
  'menu.settings.general': 'General Settings',
  'menu.settings.push': 'Push Notifications',
  'menu.settings.emojiPack': 'Emoji Pack Settings',
  'menu.settings.userProfile': 'Profile Settings',
  'menu.version': 'Version Management',
  'menu.version.frontend': 'App Client',
  'menu.version.desktop': 'Desktop Client',
  'menu.version.hotUpdate': 'Hot Updates',
  'menu.version.hotUpdateEvents': 'Hot Update Events',
  'menu.list': 'List',
  'menu.result': 'Result',
  'menu.exception': 'Exception',
  'menu.form': 'Form',
  'menu.profile': 'Profile',
  'menu.visualization': 'Data Visualization',
  'menu.user': 'User Center',
  'navbar.docs': 'Docs',
  'navbar.action.locale': 'Switch to English',
  'app.brand': 'IM Admin Console',
  ...localeSettings,
  ...localeMessageBox,
  ...localeLogin,
  ...localeWorkplace,
  /** simple */
  ...localeMonitor,
  ...localeUserManagement,
  ...localeCaptchaSettings,
  ...localeFeedback,
  ...localeStorageProvider,
  ...localeCosTest,
  ...localeFileUploadAudit,
  ...localeSystemLog,
  ...localePushLog,
  ...localeApiMetrics,
  ...localeDataCleanup,
  /** simple end */
};
