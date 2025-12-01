import localeMessageBox from '@/components/message-box/locale/en-US';
import localeLogin from '@/views/login/locale/en-US';

import localeWorkplace from '@/views/dashboard/workplace/locale/en-US';
/** simple */
import localeMonitor from '@/views/dashboard/monitor/locale/en-US';

import localeUserManagement from '@/views/user-management/list/locale/en-US';
import localeCaptchaSettings from '@/views/settings/captcha/locale/en-US';
import localeFeedback from '@/views/feedback/list/locale/en-US';
/** simple end */
import localeSettings from './en-US/settings';

export default {
  'menu.dashboard': 'Dashboard',
  'menu.server.dashboard': 'Dashboard-Server',
  'menu.server.workplace': 'Workplace-Server',
  'menu.server.monitor': 'Monitor-Server',
  'menu.userManagement': 'User Management',
  'menu.userManagement.list': 'User List',
  'menu.userManagement.feedback': 'User Feedback',
  'menu.userManagement.chatHistory': 'User Chat History',
  'menu.chatHistory.room': 'Room Chat History',
  'menu.chatHistory.user': 'User Chat History',
  'menu.settings': 'System Settings',
  'menu.settings.captcha': 'Captcha Settings',
  'menu.settings.privacyPolicy': 'Privacy Agreement',
  'menu.settings.userAgreement': 'User Agreement',
  'menu.settings.storageProvider': 'Storage Provider',
  'menu.settings.cosTest': 'COS Test',
  'menu.settings.general': 'General Settings',
  'menu.settings.emojiPack': 'Emoji Pack Settings',
  'menu.settings.ipinfoToken': 'IP Geolocation Token',
  'menu.settings.userProfile': 'Profile Settings',
  'menu.settings.dataCleanup': 'Data Cleanup',
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
  ...localeSettings,
  ...localeMessageBox,
  ...localeLogin,
  ...localeWorkplace,
  /** simple */
  ...localeMonitor,
  ...localeUserManagement,
  ...localeCaptchaSettings,
  ...localeFeedback,
  /** simple end */
};
