import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/core/routing/app_router.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:app/features/chat/chat_detail_page_v2.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const role = String.fromEnvironment('DUAL_ROLE');
const account = String.fromEnvironment('DUAL_ACCOUNT');
const peerAccount = String.fromEnvironment('DUAL_PEER_ACCOUNT');
const password = String.fromEnvironment('DUAL_PASSWORD');
const marker = String.fromEnvironment('DUAL_MARKER');

const _silentM4aBase64 =
    'AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAAARW1kYXTeAgBMYXZjNjIuMjguMTAyAAIwQA4BGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAADJ21vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAASwAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAJRdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAASwAAAAAAAAAAAAAAABAQAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAEsAAABAAAAQAAAAAByW1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAH0AAACmAVcQAAAAAAC1oZGxyAAAAAAAAAABzb3VuAAAAAAAAAAAAAAAAU291bmRIYW5kbGVyAAAAAXRtaW5mAAAAEHNtaGQAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAThzdGJsAAAAanN0c2QAAAAAAAAAAQAAAFptcDRhAAAAAAAAAAEAAAAAAAAAAAABABAAAAAAH0AAAAAAADZlc2RzAAAAAAOAgIAlAAEABICAgBdAFQAAAAAAPoAAAAFvBYCAgAUViFblAAaAgIABAgAAACBzdHRzAAAAAAAAAAIAAAAKAAAEAAAAAAEAAAGAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAALAAAAAQAAAEBzdHN6AAAAAAAAAAAAAAALAAAAFQAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAUc3RjbwAAAAAAAAABAAAALAAAABpzZ3BkAQAAAHJvbGwAAAACAAAAAf//AAAAHHNiZ3AAAAAAcm9sbAAAAAEAAAALAAAAAQAAAGJ1ZHRhAAAAWm1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAG1kaXJhcHBsAAAAAAAAAAAAAAAALWlsc3QAAAAlqXRvbwAAAB1kYXRhAAAAAQAAAABMYXZmNjIuMTIuMTAy';

class _PatrolFileSelector extends FileSelectorPlatform {
  _PatrolFileSelector(this.file);

  final XFile file;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => <XFile>[file];
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

Future<ChatProvider> _openPeerChat(PatrolIntegrationTester $) async {
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

  final current = $.tester.widget<ChatDetailPageV2>(
    find.byType(ChatDetailPageV2),
  );
  final provider = ChatProvider();
  final context = $.tester.element(find.byType(ChatDetailPageV2));
  unawaited(
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPageV2(
          roomId: current.roomId,
          chatName: current.chatName,
          chatType: current.chatType,
          initialMessageId: current.initialMessageId,
          chatProvider: provider,
        ),
      ),
    ),
  );
  await $.pump(const Duration(milliseconds: 800));
  await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
  for (
    var attempt = 0;
    attempt < 100 && provider.currentRoomId == null;
    attempt++
  ) {
    await $.pump(const Duration(milliseconds: 100));
  }
  expect(provider.currentRoomId, current.roomId);
  return provider;
}

Message? _findAttachmentMessage(
  String roomId, {
  required String senderUsername,
  required MessagePartType type,
  required String attachmentName,
}) {
  for (final message in MessageService.instance.getMessages(roomId).reversed) {
    if (message.senderUsername == senderUsername &&
        message.parts.any(
          (part) =>
              part.type == type && part.attachment?.name == attachmentName,
        )) {
      return message;
    }
  }
  return null;
}

Future<Message> _waitForAttachment(
  PatrolIntegrationTester $,
  String roomId, {
  required String senderUsername,
  required MessagePartType type,
  required String attachmentName,
}) async {
  for (var attempt = 0; attempt < 600; attempt++) {
    final message = _findAttachmentMessage(
      roomId,
      senderUsername: senderUsername,
      type: type,
      attachmentName: attachmentName,
    );
    final attachment = message?.parts
        .where((part) => part.type == type)
        .firstOrNull
        ?.attachment;
    if (message != null &&
        attachment != null &&
        attachment.key.startsWith('messages/')) {
      return message;
    }
    if (attempt == 10 || (attempt > 0 && attempt % 100 == 0)) {
      $.log(
        'DUAL_RICH_WAIT role=$role marker=$marker attempt=$attempt '
        'type=${type.name} name=$attachmentName',
      );
    }
    await $.pump(const Duration(milliseconds: 500));
  }
  fail('${type.name} 附件未在限时内到达');
}

Future<List<int>> _downloadAttachment(
  String roomId,
  Message message,
  MessagePartType type,
) async {
  final part = message.parts.firstWhere((item) => item.type == type);
  final path = await MessageService.instance.ensureAttachmentCached(
    roomId: roomId,
    message: message,
    part: part,
    forceDownload: true,
  );
  expect(path, isNotNull);
  final file = File(path!);
  expect(await file.exists(), isTrue);
  return file.readAsBytes();
}

Future<(File, List<int>)> _createPdfFixture() async {
  final bytes = utf8.encode(
    '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n% patrol-$marker\n%%EOF\n',
  );
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/patrol-file-$marker.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return (file, bytes);
}

void main() {
  patrolTest(
    '双 iOS Simulator 文件与语音附件上传下载',
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

      final readyMessage = 'rich-attachment-ready-$marker';
      final fileName = 'patrol-file-$marker.pdf';
      final voiceName = 'patrol-voice-$marker.m4a';
      final voiceBytes = base64Decode(_silentM4aBase64);
      final provider = await _openPeerChat($);
      final roomId = provider.currentRoomId!;

      if (role == 'b') {
        $.log('DUAL_READY role=b account=$account marker=$marker');
        await $(readyMessage).waitUntilVisible();
        final fileMessage = await _waitForAttachment(
          $,
          roomId,
          senderUsername: peerAccount,
          type: MessagePartType.file,
          attachmentName: fileName,
        );
        final expectedPdf = utf8.encode(
          '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n% patrol-$marker\n%%EOF\n',
        );
        expect(
          await _downloadAttachment(roomId, fileMessage, MessagePartType.file),
          expectedPdf,
        );

        final voiceMessage = await _waitForAttachment(
          $,
          roomId,
          senderUsername: peerAccount,
          type: MessagePartType.audio,
          attachmentName: voiceName,
        );
        final voicePart = voiceMessage.parts.firstWhere(
          (part) => part.type == MessagePartType.audio,
        );
        expect(voicePart.attachment?.durationMs, 1200);
        expect(
          await _downloadAttachment(
            roomId,
            voiceMessage,
            MessagePartType.audio,
          ),
          voiceBytes,
        );
        final voiceBubble = find.byKey(
          ValueKey('chat-message-${voiceMessage.id}'),
        );
        final voiceDuration = find.descendant(
          of: voiceBubble,
          matching: find.text('0:01'),
        );
        await $(voiceDuration).waitUntilVisible();
        await $(voiceDuration).tap();
        await $.pump(const Duration(milliseconds: 250));
        $.log('DUAL_RICH_ATTACHMENT_COMPLETE role=b marker=$marker');
        return;
      }

      final (pdfFile, pdfBytes) = await _createPdfFixture();
      FileSelectorPlatform.instance = _PatrolFileSelector(
        XFile(pdfFile.path, mimeType: 'application/pdf'),
      );
      await $(const ValueKey('chat-input-text-field')).enterText(readyMessage);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(readyMessage).waitUntilVisible();
      await $(const ValueKey('chat-input-more-button')).tap();
      await $('文件').tap();
      final fileMessage = await _waitForAttachment(
        $,
        roomId,
        senderUsername: account,
        type: MessagePartType.file,
        attachmentName: fileName,
      );
      expect(
        await _downloadAttachment(roomId, fileMessage, MessagePartType.file),
        pdfBytes,
      );

      await provider.sendVoiceMessage(
        roomId: roomId,
        fileBytes: voiceBytes,
        duration: 1200,
        fileName: voiceName,
      );
      final voiceMessage = await _waitForAttachment(
        $,
        roomId,
        senderUsername: account,
        type: MessagePartType.audio,
        attachmentName: voiceName,
      );
      expect(
        voiceMessage.status,
        anyOf(MessageStatus.sent, MessageStatus.delivered, MessageStatus.read),
      );
      $.log('DUAL_RICH_ATTACHMENT_COMPLETE role=a marker=$marker');
    },
  );
}
