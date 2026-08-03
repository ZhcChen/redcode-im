import 'package:flutter/material.dart';

import '../services/permission_service.dart';

extension AppPermissionPresentation on AppPermission {
  String get label => switch (this) {
    AppPermission.photos => '相册',
    AppPermission.camera => '相机',
    AppPermission.microphone => '麦克风',
    AppPermission.notification => '通知',
  };

  String get settingsDescription => switch (this) {
    AppPermission.photos => '请在系统设置中允许访问照片，以便选择并发送图片。',
    AppPermission.camera => '请在系统设置中允许使用相机，以便拍摄并发送照片。',
    AppPermission.microphone => '请在系统设置中允许使用麦克风，以便录制语音消息。',
    AppPermission.notification => '请在系统设置中允许通知，以便及时接收新消息提醒。',
  };
}

Future<bool> ensureAppPermission(
  BuildContext context,
  AppPermission permission, {
  PermissionService? service,
}) async {
  final permissionService = service ?? PermissionService.instance;
  final access = await permissionService.ensure(permission);
  if (!context.mounted) return false;

  switch (access) {
    case PermissionAccess.granted:
      return true;
    case PermissionAccess.denied:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未授予${permission.label}权限，可再次操作重新授权')),
      );
      return false;
    case PermissionAccess.settingsRequired:
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('需要${permission.label}权限'),
          content: Text(permission.settingsDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('前往设置'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        final opened = await permissionService.openSettings();
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法打开系统设置，请手动前往设置授权')));
        }
      }
      return false;
    case PermissionAccess.unavailable:
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('当前设备无法使用${permission.label}权限')));
      return false;
  }
}
