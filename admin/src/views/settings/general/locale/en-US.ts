export default {
  'settingsGeneral.title': 'General Settings',
  'settingsGeneral.tab.appName': 'App Name',
  'settingsGeneral.tab.ipGeolocation': 'IP Geolocation',
  'settingsGeneral.tab.userAccountLimit': 'User Account Limits',
  'settingsGeneral.tab.uploadPolicy': 'Upload Policy',
  'settingsGeneral.tab.apiTest': 'API Test',
  'settingsGeneral.action.save': 'Save Settings',
  'settingsGeneral.action.reset': 'Reset',
  'settingsGeneral.appName.label': 'App Name',
  'settingsGeneral.appName.placeholder': 'Enter app name',
  'settingsGeneral.appName.help':
    'The app name is shown when the desktop and mobile apps start. A restart is required after changing it.',
  'settingsGeneral.appName.validation.required': 'Please enter the app name',
  'settingsGeneral.appName.validation.maxLength':
    'App name cannot exceed 50 characters',
  'settingsGeneral.appName.fetch.error': 'Failed to load app name',
  'settingsGeneral.appName.save.success': 'App name saved successfully',
  'settingsGeneral.appName.save.error': 'Failed to save, please try again',
  'settingsGeneral.ipGeolocation.label': 'Feature Toggle',
  'settingsGeneral.ipGeolocation.help':
    'Controls whether user IP geolocation parsing is enabled for admin analytics. When disabled, user geolocation data is not recorded.',
  'settingsGeneral.ipGeolocation.fetch.error':
    'Failed to load IP geolocation setting',
  'settingsGeneral.ipGeolocation.save.success':
    'IP geolocation setting saved successfully',
  'settingsGeneral.ipGeolocation.save.error': 'Failed to save, please try again',
  'settingsGeneral.accountLimit.phone.label':
    'Enable Phone Number Validation',
  'settingsGeneral.accountLimit.phone.help':
    'When enabled, registered user accounts (usernames) must match a phone number format.',
  'settingsGeneral.accountLimit.email.label': 'Enable Email Validation',
  'settingsGeneral.accountLimit.email.help':
    'When enabled, registered user accounts (usernames) must match an email format.',
  'settingsGeneral.accountLimit.length.label': 'Enable Length Validation',
  'settingsGeneral.accountLimit.length.help':
    'When enabled, registered user accounts (usernames) must satisfy the length limit.',
  'settingsGeneral.accountLimit.minLength.label': 'Minimum Length',
  'settingsGeneral.accountLimit.minLength.placeholder': 'Minimum length',
  'settingsGeneral.accountLimit.maxLength.label': 'Maximum Length',
  'settingsGeneral.accountLimit.maxLength.placeholder': 'Maximum length',
  'settingsGeneral.accountLimit.alphanumeric.label':
    'Enable Alphanumeric Validation',
  'settingsGeneral.accountLimit.alphanumeric.help':
    'When enabled, registered user accounts (usernames) must contain both letters and numbers.',
  'settingsGeneral.accountLimit.validation.minRequired':
    'At least one validation rule must be enabled',
  'settingsGeneral.accountLimit.validation.minLengthRequired':
    'Please enter the minimum length',
  'settingsGeneral.accountLimit.validation.maxLengthRequired':
    'Please enter the maximum length',
  'settingsGeneral.accountLimit.validation.lengthRange':
    'Length range: 3-50',
  'settingsGeneral.accountLimit.validation.minGreaterThanMax':
    'Minimum length cannot be greater than maximum length',
  'settingsGeneral.accountLimit.fetch.error':
    'Failed to load user account limit settings',
  'settingsGeneral.accountLimit.save.success':
    'User account limit settings saved successfully',
  'settingsGeneral.accountLimit.save.error': 'Failed to save, please try again',
  'settingsGeneral.uploadPolicy.info':
    'Used to distribute unified attachment size, quantity, and MIME whitelist limits to clients (Flutter/Desktop). If clients fail to fetch the policy, they will fall back to local defaults.',
  'settingsGeneral.uploadPolicy.version.label': 'Policy Version',
  'settingsGeneral.uploadPolicy.version.placeholder':
    'For example: 2025-12-31 or v1',
  'settingsGeneral.uploadPolicy.version.help':
    'Useful for debugging when clients do not refresh policies. Increment the version on each change.',
  'settingsGeneral.uploadPolicy.messageLimit.label': 'Message Limits',
  'settingsGeneral.uploadPolicy.messageLimit.attachments':
    'Max attachments per message',
  'settingsGeneral.uploadPolicy.messageLimit.totalSize':
    'Total attachment size per message (MB)',
  'settingsGeneral.uploadPolicy.fileMaxSize.label':
    'Single File Size Limit (MB)',
  'settingsGeneral.uploadPolicy.audioOnly.label':
    'Voice Message Rules (audio_only)',
  'settingsGeneral.uploadPolicy.audioOnly.enabled': 'Enabled',
  'settingsGeneral.uploadPolicy.audioOnly.forceSingle':
    'Force Single Attachment',
  'settingsGeneral.uploadPolicy.audioOnly.allowText': 'Allow Text',
  'settingsGeneral.uploadPolicy.audioOnly.help':
    'In the current backend version, voice messages are forced to disallow mixing with other content and this rule cannot be changed yet.',
  'settingsGeneral.uploadPolicy.mime.image':
    'MIME Whitelist (image, one per line)',
  'settingsGeneral.uploadPolicy.mime.video':
    'MIME Whitelist (video, one per line)',
  'settingsGeneral.uploadPolicy.mime.audio':
    'MIME Whitelist (audio, one per line)',
  'settingsGeneral.uploadPolicy.mime.file':
    'MIME Whitelist (file, one per line)',
  'settingsGeneral.uploadPolicy.mime.imagePlaceholder': 'For example: image/png',
  'settingsGeneral.uploadPolicy.mime.videoPlaceholder': 'For example: video/mp4',
  'settingsGeneral.uploadPolicy.mime.audioPlaceholder': 'For example: audio/mp4',
  'settingsGeneral.uploadPolicy.mime.filePlaceholder':
    'For example: application/pdf',
  'settingsGeneral.uploadPolicy.mime.fileHelp':
    'Current whitelist item count: {count}. The backend automatically de-duplicates, lowercases, and filters dangerous types.',
  'settingsGeneral.uploadPolicy.updatedAt': 'Last Updated',
  'settingsGeneral.uploadPolicy.updatedBy': 'Updated by: {user}',
  'settingsGeneral.uploadPolicy.validation.versionRequired':
    'Please enter the policy version',
  'settingsGeneral.uploadPolicy.fetch.error': 'Failed to load upload policy',
  'settingsGeneral.uploadPolicy.save.success':
    'Upload policy saved successfully',
  'settingsGeneral.uploadPolicy.save.error': 'Failed to save, please try again',
  'settingsGeneral.empty': 'N/A',
};
