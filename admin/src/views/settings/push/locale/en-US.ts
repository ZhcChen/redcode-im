export default {
  'settingsPush.title': 'Push Notifications',
  'settingsPush.loading': 'Loading...',
  'settingsPush.tip.title': 'Notes',
  'settingsPush.tip.content':
    'When no platform credentials are configured, the system will not send system notifications (offline push). Only WebSocket real-time delivery remains available.',
  'settingsPush.section.global': 'Global Settings',
  'settingsPush.global.enabled': 'Global Offline Push Toggle (System Notifications)',
  'settingsPush.global.skipIfOnline':
    'Skip system notifications when the user is online',
  'settingsPush.action.saveGlobal': 'Save Global Settings',
  'settingsPush.action.refresh': 'Refresh',
  'settingsPush.action.viewLogs': 'View Push Logs',
  'settingsPush.section.queue': 'Queue Status (push_job_queue)',
  'settingsPush.queue.tip.title': 'Notes',
  'settingsPush.queue.tip.content':
    'The server uses the DB queue as the primary push queue. This section helps observe backlog and failures.',
  'settingsPush.queue.pending': 'Pending',
  'settingsPush.queue.retry': 'Retry',
  'settingsPush.queue.due': 'Due',
  'settingsPush.queue.failed': 'Failed',
  'settingsPush.queue.done': 'Done',
  'settingsPush.queue.nextRunAt': 'Next Run At',
  'settingsPush.queue.oldestCreatedAt': 'Oldest Created At',
  'settingsPush.action.refreshQueue': 'Refresh Queue Status',
  'settingsPush.section.providers': 'Provider Configuration',
  'settingsPush.provider.fcm.title': 'FCM (Firebase Cloud Messaging)',
  'settingsPush.provider.fcm.enabled': 'Enable FCM',
  'settingsPush.provider.fcm.currentConfig':
    'Current Configuration (non-sensitive fields only)',
  'settingsPush.provider.fcm.status': 'Status',
  'settingsPush.provider.fcm.statusEnabled': 'Enabled',
  'settingsPush.provider.fcm.statusDisabled': 'Disabled',
  'settingsPush.provider.fcm.secretConfigured': 'Credentials Configured',
  'settingsPush.provider.fcm.secretMissing': 'Credentials Missing',
  'settingsPush.provider.fcm.projectId': 'Project ID',
  'settingsPush.provider.fcm.clientEmail': 'Client Email',
  'settingsPush.provider.fcm.secretFingerprint': 'Secret Fingerprint',
  'settingsPush.provider.fcm.lastUpdated': 'Last Updated',
  'settingsPush.provider.fcm.jsonLabel':
    'Service Account JSON (plaintext input, encrypted after saving)',
  'settingsPush.provider.fcm.jsonPlaceholder':
    'Paste the Firebase service account JSON, including project_id, client_email, private_key, and more',
  'settingsPush.action.saveFcm': 'Save FCM Configuration',
  'settingsPush.action.testSend': 'Test Send',
  'settingsPush.modal.title': 'Test Send (FCM)',
  'settingsPush.modal.deviceToken.label': 'Device Token (Optional)',
  'settingsPush.modal.deviceToken.placeholder':
    'Prefer device_token. If empty, the system will try to resolve a registered device by user_id.',
  'settingsPush.modal.userId.label': 'User ID (Optional)',
  'settingsPush.modal.userId.placeholder':
    'User UUID used to find the token in push_devices',
  'settingsPush.modal.notificationTitle.label': 'Title',
  'settingsPush.modal.notificationBody.label': 'Body',
  'settingsPush.modal.defaultTitle': 'Test Notification',
  'settingsPush.modal.defaultBody': 'This is a test push notification',
  'settingsPush.validation.requireJson':
    'Service Account JSON is required when FCM is enabled',
  'settingsPush.validation.requireTarget':
    'Please enter a device token or user ID',
  'settingsPush.validation.requireTitle': 'Please enter a title',
  'settingsPush.validation.requireBody': 'Please enter the body',
  'settingsPush.fetchQueue.error':
    'Failed to load queue status, please try again later',
  'settingsPush.fetch.error':
    'Failed to load push settings, please try again later',
  'settingsPush.save.success': 'Saved successfully',
  'settingsPush.save.error': 'Failed to save, please try again later',
  'settingsPush.save.providerError':
    'Failed to save. Please check the configuration or try again later',
  'settingsPush.test.success': 'Sent successfully',
  'settingsPush.test.error': 'Failed to send, please try again later',
  'settingsPush.empty': 'N/A',
  'settingsPush.notConfigured': 'Not configured',
};
