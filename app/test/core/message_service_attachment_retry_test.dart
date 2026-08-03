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

class _PassthroughHttpOverrides extends HttpOverrides {}

class _UploadTestBackend {
  _UploadTestBackend({
    required this.signatureKeys,
    this.failedSignatureCount = 0,
    this.failedUploadCount = 0,
  });

  final List<String> signatureKeys;
  final Uri apiBaseUri = Uri.parse(AppConfig.apiBaseUrl);
  final Map<String, List<int>> uploadedBodies = <String, List<int>>{};
  final Map<String, int> uploadedContentLengths = <String, int>{};
  final Map<String, bool> uploadedChunkedFlags = <String, bool>{};
  final List<String> committedKeys = <String>[];
  final List<Map<String, dynamic>> sentBodies = <Map<String, dynamic>>[];
  int signatureRequestCount = 0;
  int failedSignatureCount;
  int failedUploadCount;

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
          if (failedSignatureCount > 0) {
            failedSignatureCount--;
            response.statusCode = HttpStatus.serviceUnavailable;
            response.write(
              jsonEncode({
                'success': false,
                'message': 'signature unavailable',
              }),
            );
            return;
          }
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
          if (failedUploadCount > 0) {
            failedUploadCount--;
            await request.drain<void>();
            response.statusCode = HttpStatus.serviceUnavailable;
            response.headers.contentType = ContentType.text;
            response.write('temporary upload failure');
            return;
          }
          uploadedContentLengths[objectKey] = request.headers.contentLength;
          uploadedChunkedFlags[objectKey] =
              request.headers.chunkedTransferEncoding;
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
      } catch (error, stackTrace) {
        response.statusCode = HttpStatus.internalServerError;
        response.write('$error\n$stackTrace');
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
  MessageStatus status = MessageStatus.sending,
}) {
  return Message(
    id: id,
    roomId: 'room-1',
    senderId: 'user-1',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: '[图片]',
    type: parts.length > 1
        ? MessageType.mixed
        : switch (parts.single.type) {
            MessagePartType.audio => MessageType.audio,
            MessagePartType.file => MessageType.file,
            _ => MessageType.image,
          },
    status: status,
    timestamp: DateTime(2026, 7, 24, 16, 20),
    isSelf: true,
    parts: parts,
  );
}

MessagePart _attachmentPart({
  required int position,
  required MessagePartType type,
  required String key,
  required String localPath,
  required double? uploadProgress,
  required String name,
  required String mime,
}) {
  return MessagePart(
    position: position,
    type: type,
    attachment: MessageAttachment(
      key: key,
      name: name,
      mime: mime,
      size: 3,
      localPath: localPath,
      uploadProgress: uploadProgress,
    ),
  );
}

MessagePart _imagePart({
  required int position,
  required String key,
  required String localPath,
  required double? uploadProgress,
}) => _attachmentPart(
  position: position,
  type: MessagePartType.image,
  key: key,
  localPath: localPath,
  uploadProgress: uploadProgress,
  name: 'image-$position.png',
  mime: 'image/png',
);

MessagePart _textPart(String text) =>
    MessagePart(position: 0, type: MessagePartType.text, text: text);

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
      expect(
        backend.uploadedContentLengths['messages/retry-uploaded-image.png'],
        localBytes.length,
      );
      expect(
        backend.uploadedChunkedFlags['messages/retry-uploaded-image.png'],
        isFalse,
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
      expect(
        backend.uploadedContentLengths['messages/retry-second-image.png'],
        3,
      );
      expect(
        backend.uploadedChunkedFlags['messages/retry-second-image.png'],
        isFalse,
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

  test('upload failure keeps attachment message visible as failed', () async {
    final localFile = File('${tempDir.path}/failed-image.png');
    await localFile.writeAsBytes(<int>[1, 2, 3], flush: true);
    final backend = _UploadTestBackend(
      signatureKeys: <String>[
        'messages/failed-image.png',
        'messages/retried-image.png',
      ],
      failedUploadCount: 1,
    );
    await backend.start();
    addTearDown(backend.close);

    MessageService? service;
    addTearDown(() => service?.dispose());

    await HttpOverrides.runWithHttpOverrides(() async {
      service = MessageService(
        messageStorage: _InMemoryMessageStorage(<String, List<Message>>{}),
        chatCache: const ChatCache(),
      );
      await expectLater(
        service!.sendRichMessage(
          roomId: 'room-1',
          attachments: <MessageAttachmentDraft>[
            MessageAttachmentDraft(
              type: MessagePartType.image,
              file: localFile,
              displayName: 'failed-image.png',
              mime: 'image/png',
            ),
          ],
        ),
        throwsA(isA<MessageSendRetryScheduled>()),
      );

      final failed = service!.getMessages('room-1').single;
      expect(failed.status, MessageStatus.failed);
      expect(failed.parts.single.attachment?.localPath, localFile.path);

      await service!.resendMessage(failed.id);
    }, _PassthroughHttpOverrides());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service!.getMessages('room-1').single.status, MessageStatus.sent);
    expect(backend.sentBodies, hasLength(1));
  });

  test(
    'signature failure keeps attachment draft available for retry',
    () async {
      final localFile = File('${tempDir.path}/unsigned.pdf');
      await localFile.writeAsBytes(<int>[7, 8, 9], flush: true);
      final backend = _UploadTestBackend(
        signatureKeys: <String>['messages/retried.pdf'],
        failedSignatureCount: 1,
      );
      await backend.start();
      addTearDown(backend.close);

      MessageService? service;
      addTearDown(() => service?.dispose());
      await HttpOverrides.runWithHttpOverrides(() async {
        service = MessageService(
          messageStorage: _InMemoryMessageStorage(<String, List<Message>>{}),
          chatCache: const ChatCache(),
        );
        await expectLater(
          service!.sendRichMessage(
            roomId: 'room-1',
            attachments: <MessageAttachmentDraft>[
              MessageAttachmentDraft(
                type: MessagePartType.file,
                file: localFile,
                displayName: 'unsigned.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
          throwsA(isA<MessageSendRetryScheduled>()),
        );

        final failed = service!.getMessages('room-1').single;
        expect(failed.status, MessageStatus.failed);
        expect(failed.parts.single.attachment?.key, startsWith('pending/'));
        await service!.resendMessage(failed.id);
      }, _PassthroughHttpOverrides());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service!.getMessages('room-1').single.status, MessageStatus.sent);
      expect(backend.sentBodies, hasLength(1));
    },
  );

  for (final fixture in <({MessagePartType type, String name, String mime})>[
    (type: MessagePartType.image, name: 'retry.png', mime: 'image/png'),
    (type: MessagePartType.file, name: 'retry.pdf', mime: 'application/pdf'),
    (type: MessagePartType.audio, name: 'retry.m4a', mime: 'audio/mp4'),
  ]) {
    test(
      'restores failed ${fixture.type.name} attachment for manual retry',
      () async {
        final localFile = File('${tempDir.path}/${fixture.name}');
        await localFile.writeAsBytes(<int>[4, 5, 6], flush: true);
        final backend = _UploadTestBackend(
          signatureKeys: <String>['messages/${fixture.name}'],
        );
        await backend.start();
        addTearDown(backend.close);

        final storage = _InMemoryMessageStorage({
          'room-1': <Message>[
            _buildPendingAttachmentMessage(
              id: 'failed-${fixture.type.name}',
              status: MessageStatus.failed,
              parts: <MessagePart>[
                _attachmentPart(
                  position: 0,
                  type: fixture.type,
                  key: 'messages/stale-${fixture.name}',
                  localPath: localFile.path,
                  uploadProgress: 0.2,
                  name: fixture.name,
                  mime: fixture.mime,
                ),
              ],
            ),
          ],
        });
        MessageService? service;
        addTearDown(() => service?.dispose());

        await HttpOverrides.runWithHttpOverrides(() async {
          service = MessageService(
            messageStorage: storage,
            chatCache: const ChatCache(),
          );
          await service!.loadCachedMessages('room-1');
          await service!.resendMessage('failed-${fixture.type.name}');
        }, _PassthroughHttpOverrides());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          service!.getMessages('room-1').single.status,
          MessageStatus.sent,
        );
        expect(backend.sentBodies, hasLength(1));
      },
    );
  }

  test('missing local attachment becomes failed without retry loop', () async {
    final missingPath = '${tempDir.path}/already-removed.m4a';
    final storage = _InMemoryMessageStorage({
      'room-1': <Message>[
        _buildPendingAttachmentMessage(
          id: 'missing-audio',
          parts: <MessagePart>[
            _attachmentPart(
              position: 0,
              type: MessagePartType.audio,
              key: 'messages/stale-audio.m4a',
              localPath: missingPath,
              uploadProgress: 0.2,
              name: 'already-removed.m4a',
              mime: 'audio/mp4',
            ),
          ],
        ),
      ],
    });
    final service = MessageService(
      messageStorage: storage,
      chatCache: const ChatCache(),
    );
    addTearDown(service.dispose);

    await service.loadCachedMessages('room-1');
    expect(service.getMessages('room-1').single.status, MessageStatus.failed);
    await service.resendMessage('missing-audio');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.getMessages('room-1').single.status, MessageStatus.failed);
  });

  test('restored mixed message does not duplicate text in parts', () async {
    final localFile = File('${tempDir.path}/already-uploaded.pdf');
    await localFile.writeAsBytes(<int>[1, 2, 3], flush: true);
    final backend = _UploadTestBackend(signatureKeys: const <String>[]);
    await backend.start();
    addTearDown(backend.close);
    final storage = _InMemoryMessageStorage({
      'room-1': <Message>[
        _buildPendingAttachmentMessage(
          id: 'failed-mixed',
          status: MessageStatus.failed,
          parts: <MessagePart>[
            _textPart('caption'),
            _attachmentPart(
              position: 1,
              type: MessagePartType.file,
              key: 'messages/already-uploaded.pdf',
              localPath: localFile.path,
              uploadProgress: null,
              name: 'already-uploaded.pdf',
              mime: 'application/pdf',
            ),
          ],
        ),
      ],
    });
    MessageService? service;
    addTearDown(() => service?.dispose());

    await HttpOverrides.runWithHttpOverrides(() async {
      service = MessageService(
        messageStorage: storage,
        chatCache: const ChatCache(),
      );
      await service!.loadCachedMessages('room-1');
      await service!.resendMessage('failed-mixed');
    }, _PassthroughHttpOverrides());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(backend.sentBodies.single['content'], 'caption');
    final parts = backend.sentBodies.single['parts'] as List<dynamic>;
    expect(parts, hasLength(1));
    expect(parts.single['type'], 'file');
  });
}
