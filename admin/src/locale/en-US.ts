import localeMessageBox from '@/components/message-box/locale/en-US';
import localeLogin from '@/views/login/locale/en-US';

import localeWorkplace from '@/views/dashboard/workplace/locale/en-US';
/** simple */
import localeMonitor from '@/views/dashboard/monitor/locale/en-US';

import localeUserManagement from '@/views/user-management/list/locale/en-US';
import localeCaptchaSettings from '@/views/settings/captcha/locale/en-US';
import localePrivacyPolicy from '@/views/settings/privacy-policy/locale/en-US';
import localeUserAgreement from '@/views/settings/user-agreement/locale/en-US';
import localeGeneralSettings from '@/views/settings/general/locale/en-US';
import localeApiTest from '@/views/settings/api-test/locale/en-US';
import localePushSettings from '@/views/settings/push/locale/en-US';
import localeChatHistory from '@/views/chat-history/locale/en-US';
import localeFeedback from '@/views/feedback/list/locale/en-US';
import localeIpinfoToken from '@/views/settings/ipinfo-token/locale/en-US';
import localeReport from '@/views/report/list/locale/en-US';
import localeStorageProvider from '@/views/settings/storage-provider/locale/en-US';
import localeCosTest from '@/views/settings/cos-test/locale/en-US';
import localeFileUploadAudit from '@/views/operations/file-upload-audit/locale/en-US';
import localeSystemLog from '@/views/dashboard/system-log/locale/en-US';
import localePushLog from '@/views/operations/push-log/locale/en-US';
import localeApiMetrics from '@/views/operations/api-metrics/locale/en-US';
import localeDataCleanup from '@/views/settings/data-cleanup/locale/en-US';
/** simple end */
import { enUSCommonMessages } from './common';
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
  'menu.settings.privacyPolicy': 'Privacy Policy',
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
  ...enUSCommonMessages,
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
  /** simple end */
};
