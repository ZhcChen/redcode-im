export default {
  'settingsGeneral.title': '通用设置',
  'settingsGeneral.tab.appName': '应用名称',
  'settingsGeneral.tab.ipGeolocation': 'IP地理位置解析',
  'settingsGeneral.tab.userAccountLimit': '用户账号限制',
  'settingsGeneral.tab.uploadPolicy': '上传策略',
  'settingsGeneral.tab.apiTest': 'API测试',
  'settingsGeneral.action.save': '保存设置',
  'settingsGeneral.action.reset': '重置',
  'settingsGeneral.appName.label': '应用名称',
  'settingsGeneral.appName.placeholder': '请输入应用名称',
  'settingsGeneral.appName.help':
    '应用名称将在桌面端和移动端应用启动时显示，修改后需要重启应用才能生效。',
  'settingsGeneral.appName.validation.required': '请输入应用名称',
  'settingsGeneral.appName.validation.maxLength':
    '应用名称不能超过50个字符',
  'settingsGeneral.appName.fetch.error': '获取应用名称失败',
  'settingsGeneral.appName.save.success': '应用名称保存成功',
  'settingsGeneral.appName.save.error': '保存失败，请重试',
  'settingsGeneral.ipGeolocation.label': '功能开关',
  'settingsGeneral.ipGeolocation.help':
    '控制是否启用用户IP地址地理位置解析功能，用于管理员数据统计。关闭后不会记录用户的地理位置信息。',
  'settingsGeneral.ipGeolocation.fetch.error':
    '获取IP地理位置解析开关状态失败',
  'settingsGeneral.ipGeolocation.save.success':
    'IP地理位置解析开关保存成功',
  'settingsGeneral.ipGeolocation.save.error': '保存失败，请重试',
  'settingsGeneral.accountLimit.phone.label': '启用手机号校验',
  'settingsGeneral.accountLimit.phone.help':
    '启用后，注册用户账号（用户名）必须符合手机号格式',
  'settingsGeneral.accountLimit.email.label': '启用邮箱校验',
  'settingsGeneral.accountLimit.email.help':
    '启用后，注册用户账号（用户名）必须符合邮箱格式',
  'settingsGeneral.accountLimit.length.label': '启用长度校验',
  'settingsGeneral.accountLimit.length.help':
    '启用后，注册用户账号（用户名）必须符合长度限制',
  'settingsGeneral.accountLimit.minLength.label': '最小长度',
  'settingsGeneral.accountLimit.minLength.placeholder': '最小长度',
  'settingsGeneral.accountLimit.maxLength.label': '最大长度',
  'settingsGeneral.accountLimit.maxLength.placeholder': '最大长度',
  'settingsGeneral.accountLimit.alphanumeric.label':
    '启用字母数字混合校验',
  'settingsGeneral.accountLimit.alphanumeric.help':
    '启用后，注册用户账号（用户名）必须同时包含字母和数字',
  'settingsGeneral.accountLimit.validation.minRequired': '至少需要启用一种校验规则',
  'settingsGeneral.accountLimit.validation.minLengthRequired': '请输入最小长度',
  'settingsGeneral.accountLimit.validation.maxLengthRequired': '请输入最大长度',
  'settingsGeneral.accountLimit.validation.lengthRange': '长度范围：3-50',
  'settingsGeneral.accountLimit.validation.minGreaterThanMax':
    '最小长度不能大于最大长度',
  'settingsGeneral.accountLimit.fetch.error': '获取用户账号限制设置失败',
  'settingsGeneral.accountLimit.save.success': '用户账号限制设置保存成功',
  'settingsGeneral.accountLimit.save.error': '保存失败，请重试',
  'settingsGeneral.uploadPolicy.info':
    '用于下发给客户端（Flutter/Desktop）统一附件大小、数量、MIME 白名单等限制；当客户端未能拉取策略时会回退到本地默认值。',
  'settingsGeneral.uploadPolicy.version.label': '策略版本',
  'settingsGeneral.uploadPolicy.version.placeholder': '例如 2025-12-31 或 v1',
  'settingsGeneral.uploadPolicy.version.help':
    '可用于排查“客户端未刷新策略”的问题，建议每次变更时递增版本。',
  'settingsGeneral.uploadPolicy.messageLimit.label': '消息级限制',
  'settingsGeneral.uploadPolicy.messageLimit.attachments':
    '单条消息最多附件数',
  'settingsGeneral.uploadPolicy.messageLimit.totalSize':
    '单条消息附件总大小（MB）',
  'settingsGeneral.uploadPolicy.fileMaxSize.label': '单文件大小上限（MB）',
  'settingsGeneral.uploadPolicy.audioOnly.label': '语音消息规则（audio_only）',
  'settingsGeneral.uploadPolicy.audioOnly.enabled': '启用',
  'settingsGeneral.uploadPolicy.audioOnly.forceSingle':
    '强制单附件',
  'settingsGeneral.uploadPolicy.audioOnly.allowText': '允许携带文本',
  'settingsGeneral.uploadPolicy.audioOnly.help':
    '当前版本后端固定强制“语音不可混合其他内容”，暂不支持修改此规则。',
  'settingsGeneral.uploadPolicy.mime.image': 'MIME 白名单（image，每行一个）',
  'settingsGeneral.uploadPolicy.mime.video': 'MIME 白名单（video，每行一个）',
  'settingsGeneral.uploadPolicy.mime.audio': 'MIME 白名单（audio，每行一个）',
  'settingsGeneral.uploadPolicy.mime.file': 'MIME 白名单（file，每行一个）',
  'settingsGeneral.uploadPolicy.mime.imagePlaceholder': '例如 image/png',
  'settingsGeneral.uploadPolicy.mime.videoPlaceholder': '例如 video/mp4',
  'settingsGeneral.uploadPolicy.mime.audioPlaceholder': '例如 audio/mp4',
  'settingsGeneral.uploadPolicy.mime.filePlaceholder':
    '例如 application/pdf',
  'settingsGeneral.uploadPolicy.mime.fileHelp':
    '当前汇总白名单数量：{count}（后台会自动去重、转小写，并过滤危险类型）。',
  'settingsGeneral.uploadPolicy.updatedAt': '最后更新',
  'settingsGeneral.uploadPolicy.updatedBy': '更新人：{user}',
  'settingsGeneral.uploadPolicy.validation.versionRequired': '请输入策略版本',
  'settingsGeneral.uploadPolicy.fetch.error': '获取上传策略失败',
  'settingsGeneral.uploadPolicy.save.success': '上传策略保存成功',
  'settingsGeneral.uploadPolicy.save.error': '保存失败，请重试',
  'settingsGeneral.empty': '暂无',
};
