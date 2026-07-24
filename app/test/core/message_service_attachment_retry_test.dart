import 'dart:convert';
import 'dart:io';

import 'package:app/core/constants/app_config.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/upload_policy_service.dart';
import 'package:app/core/storage/attachment_cache.dart';
import 'package:app/core/storage/chat_cache.dart';
import 'package:app/core/storage/message_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryMessageStorage extends MessageStorage {
  _InMemoryMessageStorage(this._messagesByRoom);

  final Map<String, List<Message>> _messagesByRoom;

  @override
  Future<List<Message>> loadMessages(String roomId) async =>
      List<Message>.from(_messagesByRoom[roomId] ?? const <Message>[]);

  @override
  Future<void> saveMessages(String roomId, List<Message> messages) async {
    _messagesByRoom[roomId] = List<Message>.from(messages);
  }

  @override
  Future<void> clear(String roomId) async {
    _messagesByRoom.remove(roomId);
  }

  @override
  Future<void> clearAll() async {
    _messagesByRoom.clear();
  }

  @override
  Future<String?> getLatestMessageId(String roomId) async {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.last.id;
  }
}

class _PassthroughHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

class _UploadTestBackend {
  _UploadTestBackend({required this.signatureKeys});

  final List<String> signatureKeys;
  final Uri apiBaseUri = Uri.parse(AppConfig.apiBaseUrl);
  final Map<String, List<int>> uploadedBodies = <String, List<int>>{};
  final List<String> committedKeys = <String>[];
  final List<Map<String, dynamic>> sentBodies = <Map<String, dynamic>>[];
  int signatureRequestCount = 0;

  HttpServer? _server;

  Future<void> start() async {
    _server = await HttpServer.bind(
      apiBaseUri.host,
      apiBaseUri.hasPort ? apiBaseUri.port : 80,
    );
    _server!.listen((request) async {
      final response = request.response;
      response.headers.contentType = ContentType.json;

      try {
        if (request.method == 'GET' &&
            request.uri.path == '/system/upload-policy') {
          response.write(
            jsonEncode({
              'version': 'test',
              'max_total_size_mb': 100,
              'max_attachments_per_message': 10,
              'max_size_mb_by_part_type': {
                'image': 5,
                'video': 100,
                'audio': 20,
                'file': 50,
              },
              'mime_by_part_type': {
                'image': ['image/png'],
                'video': ['video/mp4'],
                'audio': ['audio/mp4'],
                'file': ['application/pdf'],
              },
              'mime_whitelist': [
                'application/pdf',
                'audio/mp4',
                'image/png',
                'video/mp4',
              ],
              'audio_only': {
                'enabled': true,
                'force_single_attachment': true,
                'allow_text': false,
              },
            }),
          );
          return;
        }

        if (request.method == 'POST' &&
            request.uri.path ==
                '/rooms/room-1/messages/attachments/signature') {
          final key = signatureKeys[signatureRequestCount++];
          response.write(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'key': key,
              'signature': {
                'url': apiBaseUri.resolve('/uploads/$key').toString(),
                'method': 'PUT',
                'headers': <String, String>{},
              },
            }),
          );
          return;
        }

        if (request.method == 'PUT' &&
            request.uri.pathSegments.isNotEmpty &&
            request.uri.pathSegments.first == 'uploads') {
          final objectKey = request.uri.pathSegments.skip(1).join('/');
          uploadedBodies[objectKey] = await request.fold<List<int>>(<int>[], (
            buffer,
            chunk,
          ) {
            buffer.addAll(chunk);
            return buffer;
          });
          response.statusCode = HttpStatus.ok;
          response.headers.contentType = ContentType.binary;
          return;
        }

        if (request.method == 'POST' &&
            request.uri.path == '/rooms/room-1/messages/attachments/commit') {
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          final key = payload['key']?.toString() ?? '';
          if (!uploadedBodies.containsKey(key)) {
            response.statusCode = HttpStatus.badRequest;
            response.write(
              jsonEncode({
                'success': false,
                'message': 'missing uploaded object for $key',
              }),
            );
            return;
          }
          committedKeys.add(key);
          response.write(jsonEncode({'success': true, 'message': 'ok'}));
          return;
        }

        if (request.method == 'POST' &&
            request.uri.path == '/rooms/room-1/messages') {
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          sentBodies.add(payload);

          final rawParts =
              payload['parts'] as List<dynamic>? ?? const <dynamic>[];
          final parts = <Map<String, dynamic>>[];
          for (var index = 0; index < rawParts.length; index++) {
            final rawPart = rawParts[index] as Map<String, dynamic>;
            parts.add({
              'position': index,
              'part_type': rawPart['type'],
              'attachment': {
                'key': rawPart['key'],
                'name': rawPart['name'],
                'mime': rawPart['mime'],
                'size': rawPart['size'],
                'width': rawPart['width'],
                'height': rawPart['height'],
                'duration_ms': rawPart['duration_ms'],
              },
            });
          }

          final messageType = rawParts.length > 1
              ? 'mixed'
              : (rawParts.isEmpty
                    ? 'text'
                    : (rawParts.first as Map<String, dynamic>)['type']);

          response.write(
            jsonEncode({
              'message': {
                'id': 'server-msg-1',
                'room_id': 'room-1',
                'sender_id': 'user-1',
                'sender_username': 'alice',
                'sender_nickname': 'Alice',
                'sender_avatar_url': null,
                'content': payload['content'] ?? '[图片]',
                'message_type': messageType,
                'created_at': '2026-07-24T16:30:00Z',
                'status': 'sent',
                'is_deleted': false,
                'is_pinned': false,
                'parts': parts,
              },
            }),
          );
          return;
        }

        response.statusCode = HttpStatus.notFound;
        response.write(
          jsonEncode({
            'error': 'unexpected route',
            'method': request.method,
            'path': request.uri.path,
          }),
        );
      } finally {
        await response.close();
      }
    });
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }
}

Message _buildPendingAttachmentMessage({
  required String id,
  required List<MessagePart> parts,
}) {
  return Message(
    id: id,
    roomId: 'room-1',
    senderId: 'user-1',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: '[图片]',
    type: parts.length > 1 ? MessageType.mixed : MessageType.image,
    status: MessageStatus.sending,
    timestamp: DateTime(2026, 7, 24, 16, 20),
    isSelf: true,
    parts: parts,
  );
}

MessagePart _imagePart({
  required int position,
  required String key,
  required String localPath,
  required double? uploadProgress,
}) {
  return MessagePart(
    position: position,
    type: MessagePartType.image,
    attachment: MessageAttachment(
      key: key,
      name: 'image-$position.png',
      mime: 'image/png',
      size: 3,
      localPath: localPath,
      uploadProgress: uploadProgress,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp(
      'message-service-attachment-retry-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getTemporaryDirectory':
              return tempDir.path;
            default:
              return tempDir.path;
          }
        });
    await UploadPolicyService.instance.clearCache();
    await AttachmentCache.instance.clearAll();
    await const TokenStorage().saveSession(
      AuthSession(
        token: 'token-1',
        user: AuthUser(id: 'user-1', username: 'alice', nickname: 'Alice'),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'upload_policy_cache_json',
      jsonEncode({
        'version': 'test',
        'max_total_size_mb': 100,
        'max_attachments_per_message': 10,
        'max_size_mb_by_part_type': {
          'image': 5,
          'video': 100,
          'audio': 20,
          'file': 50,
        },
        'mime_by_part_type': {
          'image': ['image/png'],
          'video': ['video/mp4'],
          'audio': ['audio/mp4'],
          'file': ['application/pdf'],
        },
        'mime_whitelist': [
          'application/pdf',
          'audio/mp4',
          'image/png',
          'video/mp4',
        ],
        'audio_only': {
          'enabled': true,
          'force_single_attachment': true,
          'allow_text': false,
        },
      }),
    );
    await prefs.setInt(
      'upload_policy_cache_fetched_at_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  });

  tearDown(() async {
    await UploadPolicyService.instance.clearCache();
    await AttachmentCache.instance.clearAll();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'resendMessage reuploads pending attachment before sending message payload',
    () async {
      final localFile = File('${tempDir.path}/pending-image.png');
      final localBytes = <int>[1, 2, 3];
      await localFile.writeAsBytes(localBytes, flush: true);

      final backend = _UploadTestBackend(
        signatureKeys: <String>['messages/retry-uploaded-image.png'],
      );
      await backend.start();
      addTearDown(backend.close);

      final messageStorage = _InMemoryMessageStorage({
        'room-1': <Message>[
          _buildPendingAttachmentMessage(
            id: 'pending-1',
            parts: <MessagePart>[
              _imagePart(
                position: 0,
                key: 'messages/stale-image.png',
                localPath: localFile.path,
                uploadProgress: 0.25,
              ),
            ],
          ),
        ],
      });

      MessageService? service;
      addTearDown(() => service?.dispose());

      await HttpOverrides.runWithHttpOverrides(() async {
        final createdService = MessageService(
          messageStorage: messageStorage,
          chatCache: const ChatCache(),
        );
        service = createdService;
        await createdService.loadCachedMessages('room-1');
        await createdService.resendMessage('pending-1');
      }, _PassthroughHttpOverrides());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        backend.uploadedBodies['messages/retry-uploaded-image.png'],
        localBytes,
      );
      expect(backend.committedKeys, <String>[
        'messages/retry-uploaded-image.png',
      ]);
      expect(backend.sentBodies, hasLength(1));
      expect(
        (backend.sentBodies.single['parts'] as List<dynamic>).single['key'],
        'messages/retry-uploaded-image.png',
      );

      final sent = service!.getMessages('room-1').single;
      expect(sent.status, MessageStatus.sent);
      expect(
        sent.parts.single.attachment?.key,
        'messages/retry-uploaded-image.png',
      );
    },
  );

  test(
    'resendMessage reuses completed attachment key and only reuploads pending ones',
    () async {
      final existingFile = File('${tempDir.path}/existing-image.png');
      final pendingFile = File('${tempDir.path}/pending-image-2.png');
      await existingFile.writeAsBytes(<int>[4, 5, 6], flush: true);
      await pendingFile.writeAsBytes(<int>[7, 8, 9], flush: true);

      final backend = _UploadTestBackend(
        signatureKeys: <String>['messages/retry-second-image.png'],
      );
      await backend.start();
      addTearDown(backend.close);

      final messageStorage = _InMemoryMessageStorage({
        'room-1': <Message>[
          _buildPendingAttachmentMessage(
            id: 'pending-2',
            parts: <MessagePart>[
              _imagePart(
                position: 0,
                key: 'messages/already-uploaded-image.png',
                localPath: existingFile.path,
                uploadProgress: null,
              ),
              _imagePart(
                position: 1,
                key: 'messages/stale-second-image.png',
                localPath: pendingFile.path,
                uploadProgress: 0.4,
              ),
            ],
          ),
        ],
      });

      MessageService? service;
      addTearDown(() => service?.dispose());

      await HttpOverrides.runWithHttpOverrides(() async {
        final createdService = MessageService(
          messageStorage: messageStorage,
          chatCache: const ChatCache(),
        );
        service = createdService;
        await createdService.loadCachedMessages('room-1');
        await createdService.resendMessage('pending-2');
      }, _PassthroughHttpOverrides());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(backend.signatureRequestCount, 1);
      expect(backend.uploadedBodies.length, 1);
      expect(
        backend.uploadedBodies.keys,
        contains('messages/retry-second-image.png'),
      );
      expect(backend.committedKeys, <String>[
        'messages/retry-second-image.png',
      ]);

      final parts = backend.sentBodies.single['parts'] as List<dynamic>;
      expect(parts, hasLength(2));
      expect(parts[0]['key'], 'messages/already-uploaded-image.png');
      expect(parts[1]['key'], 'messages/retry-second-image.png');

      final sent = service!.getMessages('room-1').single;
      expect(sent.status, MessageStatus.sent);
      expect(
        sent.parts[0].attachment?.key,
        'messages/already-uploaded-image.png',
      );
      expect(sent.parts[1].attachment?.key, 'messages/retry-second-image.png');
    },
  );
}
