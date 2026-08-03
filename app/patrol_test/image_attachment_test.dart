import 'dart:async';
import 'dart:io';

import 'package:app/core/routing/app_router.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/permission_service.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:app/features/chat/chat_detail_page_v2.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const role = String.fromEnvironment('DUAL_ROLE');
const account = String.fromEnvironment('DUAL_ACCOUNT');
const peerAccount = String.fromEnvironment('DUAL_PEER_ACCOUNT');
const password = String.fromEnvironment('DUAL_PASSWORD');
const marker = String.fromEnvironment('DUAL_MARKER');

class _PatrolImagePicker extends ImagePickerPlatform {
  _PatrolImagePicker(this.fixturePath);

  final String fixturePath;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => <XFile>[XFile(fixturePath, mimeType: 'image/png')];
}

class _GrantedPermissionGateway implements PermissionGateway {
  @override
  Future<bool> openSettings() async => true;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async =>
      AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      AppPermissionStatus.granted;
}

final _grantedPermissionService = PermissionService(
  gateway: _GrantedPermissionGateway(),
);

Future<void> _installImagePickerFixture() async {
  final bytes = await rootBundle.load('assets/images/login/login_bg.png');
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/patrol-image-$marker.png');
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  ImagePickerPlatform.instance = _PatrolImagePicker(file.path);
}

Widget _buildTestApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const LoginPage(),
    ),
  );
}

Future<void> _openPeerChat(PatrolIntegrationTester $) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('user_agreed_to_terms', true);
  await $.pumpWidget(_buildTestApp());
  await $.pump(const Duration(milliseconds: 800));
  await $(TextField).at(0).enterText(account);
  await $(TextField).at(1).enterText(password);
  await $('登录账号').tap();
  await $('联系人').waitUntilVisible();
  await $('联系人').tap();
  await $(peerAccount).waitUntilVisible();
  await $(peerAccount).tap();
  await $('发送消息').waitUntilVisible();
  await $('发送消息').tap();
  await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
  if (role == 'a') {
    final current = $.tester.widget<ChatDetailPageV2>(
      find.byType(ChatDetailPageV2),
    );
    final context = $.tester.element(find.byType(ChatDetailPageV2));
    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailPageV2(
            roomId: current.roomId,
            chatName: current.chatName,
            chatType: current.chatType,
            initialMessageId: current.initialMessageId,
            permissionService: _grantedPermissionService,
          ),
        ),
      ),
    );
    await $.pump(const Duration(milliseconds: 800));
    await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
  }
}

Message? _findAttachmentMessage(
  String roomId, {
  required String senderUsername,
  required String attachmentName,
}) {
  for (final message in MessageService.instance.getMessages(roomId).reversed) {
    if (message.senderUsername == senderUsername &&
        message.parts.any(
          (part) =>
              part.type == MessagePartType.image &&
              part.attachment?.name == attachmentName,
        )) {
      return message;
    }
  }
  return null;
}

Future<Message> _waitForDownloadedImage(
  PatrolIntegrationTester $,
  String roomId,
  String senderUsername,
  String attachmentName,
) async {
  for (var attempt = 0; attempt < 600; attempt += 1) {
    final roomMessages = MessageService.instance.getMessages(roomId);
    final message = _findAttachmentMessage(
      roomId,
      senderUsername: senderUsername,
      attachmentName: attachmentName,
    );
    final attachment = message?.parts
        .where((part) => part.type == MessagePartType.image)
        .firstOrNull
        ?.attachment;
    final localPath = attachment?.localPath;
    if (message != null &&
        attachment != null &&
        attachment.key.startsWith('messages/') &&
        localPath != null &&
        localPath.isNotEmpty &&
        await File(localPath).exists()) {
      return message;
    }
    if (attempt == 10 || (attempt > 0 && attempt % 100 == 0)) {
      final imageState = roomMessages
          .expand(
            (item) => item.parts
                .where((part) => part.type == MessagePartType.image)
                .map(
                  (part) =>
                      '${item.senderUsername}:'
                      '${part.attachment?.name}:'
                      '${part.attachment?.key}:'
                      '${part.attachment?.localPath}',
                ),
          )
          .join(' | ');
      $.log(
        'DUAL_IMAGE_WAIT role=$role marker=$marker attempt=$attempt '
        'room=$roomId images=$imageState',
      );
    }
    await $.pump(const Duration(milliseconds: 500));
  }
  fail('图片附件未在限时内完成下载');
}

void main() {
  patrolTest(
    '双 iOS Simulator 图片附件上传与下载',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 300),
      printLogs: true,
    ),
    ($) async {
      expect(role, anyOf('a', 'b'));
      expect(account, isNotEmpty);
      expect(peerAccount, isNotEmpty);
      expect(password, isNotEmpty);
      expect(marker, isNotEmpty);
      $.log(
        'DUAL_IDENTITY role=$role account=$account marker=$marker '
        'prefix=dual-$role- peer=$peerAccount',
      );

      final readyMessage = 'image-attachment-ready-$marker';
      await _openPeerChat($);
      if (role == 'a') {
        await _installImagePickerFixture();
      }
      final roomId = $.tester
          .widget<ChatDetailPageV2>(find.byType(ChatDetailPageV2))
          .roomId;
      final attachmentName = 'patrol-image-$marker.png';

      if (role == 'b') {
        $.log('DUAL_READY role=b account=$account marker=$marker');
        await $(readyMessage).waitUntilVisible();
        final message = await _waitForDownloadedImage(
          $,
          roomId,
          peerAccount,
          attachmentName,
        );
        expect(
          message.status,
          anyOf(
            MessageStatus.sent,
            MessageStatus.delivered,
            MessageStatus.read,
          ),
        );
        $.log('DUAL_IMAGE_ATTACHMENT_COMPLETE role=b marker=$marker');
        return;
      }

      await $(const ValueKey('chat-input-text-field')).enterText(readyMessage);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(readyMessage).waitUntilVisible();
      await $(const ValueKey('chat-input-more-button')).tap();
      await $('相册').tap();
      final message = await _waitForDownloadedImage(
        $,
        roomId,
        account,
        attachmentName,
      );
      expect(message.isSelf, isTrue);
      expect(
        message.status,
        anyOf(MessageStatus.sent, MessageStatus.delivered, MessageStatus.read),
      );
      $.log('DUAL_IMAGE_ATTACHMENT_COMPLETE role=a marker=$marker');
    },
  );
}
