import 'dart:async';
import 'dart:convert';

import 'package:app/core/constants/app_config.dart';
import 'package:app/core/services/feedback_service.dart';
import 'package:app/core/services/friend_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/room_service.dart';
import 'package:app/core/services/upload_policy_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const bool _enableRealContractIntegration = bool.fromEnvironment(
  'ENABLE_REAL_CONTRACT_INTEGRATION',
  defaultValue: false,
);

class _StaticTokenStorage extends TokenStorage {
  const _StaticTokenStorage(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<String?> readToken() async => _session.token;
}

class _GroupContractResult {
  const _GroupContractResult({required this.group, required this.rule});

  final CreatedRoom group;
  final GroupRule rule;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'flutter app integration contract: auth, friends, rooms, messages and settings',
    (tester) async {
      final sharedStorage = TokenStorage();
      await sharedStorage.clear();

      final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final accountA = 'fl${suffix}a';
      final accountB = 'fl${suffix}b';
      const password = 'pass123456';

      final httpClient = http.Client();
      AuthSession? sessionA;
      AuthSession? sessionB;
      MessageService? messageA;
      MessageService? messageB;
      CreatedRoom? group;
      String? pushDeviceId;

      try {
        final auth = AuthRepository(storage: sharedStorage);
        sessionA = await _registerAndLogin(auth, accountA, password);
        final storageA = _StaticTokenStorage(sessionA);

        sessionB = await _registerAndLogin(auth, accountB, password);
        final storageB = _StaticTokenStorage(sessionB);

        final friendA = FriendService(tokenStorage: storageA);
        final friendB = FriendService(tokenStorage: storageB);
        final roomA = RoomService(tokenStorage: storageA);
        final roomB = RoomService(tokenStorage: storageB);
        messageA = MessageService(tokenStorage: storageA);
        messageB = MessageService(tokenStorage: storageB);

        await _verifySettingsAndPolicyContract(httpClient, sessionA);
        await _verifyFeedbackContract(httpClient, storageA, accountA, suffix);
        await _verifyFriendContract(
          friendA,
          friendB,
          sessionA,
          sessionB,
          suffix,
        );

        final groupResult = await _verifyGroupContract(
          roomA: roomA,
          roomB: roomB,
          sessionB: sessionB,
          suffix: suffix,
          onGroupCreated: (created) => group = created,
        );

        final edited = await _verifyMessageContract(
          client: httpClient,
          sessionA: sessionA,
          sessionB: sessionB,
          messageA: messageA,
          messageB: messageB,
          group: groupResult.group,
          suffix: suffix,
        );

        pushDeviceId = 'flutter-contract-$suffix';
        await _registerAndUnregisterPushDevice(
          client: httpClient,
          session: sessionA,
          deviceId: pushDeviceId,
          deviceToken: 'mock-device-token-$suffix',
        );

        final deleted = await _deleteRawMessage(
          httpClient,
          sessionA,
          groupResult.group.id,
          edited.id,
        );
        expect(_asBool(deleted['is_deleted']), isTrue);

        await roomA.deleteRule(
          roomId: groupResult.group.id,
          ruleId: groupResult.rule.id,
        );
        expect(
          (await roomA.listRules(
            groupResult.group.id,
          )).any((item) => item.id == groupResult.rule.id),
          isFalse,
        );
      } finally {
        messageA?.dispose();
        messageB?.dispose();
        final cleanupSessionA = sessionA;
        final cleanupSessionB = sessionB;
        final cleanupGroup = group;
        final cleanupPushDeviceId = pushDeviceId;
        if (cleanupSessionA != null && cleanupPushDeviceId != null) {
          await _bestEffortUnregisterPushDevice(
            httpClient,
            cleanupSessionA,
            cleanupPushDeviceId,
          );
        }
        if (cleanupSessionA != null && cleanupGroup != null) {
          await _bestEffortDeleteRoom(
            httpClient,
            cleanupSessionA,
            cleanupGroup.id,
          );
        }
        if (cleanupSessionB != null) {
          await _bestEffortDeactivateUser(httpClient, cleanupSessionB);
        }
        if (cleanupSessionA != null) {
          await _bestEffortDeactivateUser(httpClient, cleanupSessionA);
        }
        httpClient.close();
        await sharedStorage.clear();
      }
    },
    skip: !_enableRealContractIntegration,
  );
}

Future<AuthSession> _registerAndLogin(
  AuthRepository auth,
  String account,
  String password,
) async {
  await auth.register(account: account, password: password);
  final session = await auth.login(account: account, password: password);
  expect(session.token, isNotEmpty);
  expect(session.refreshToken, isNotEmpty);
  expect(session.user.username, account);
  return session;
}

Future<void> _verifySettingsAndPolicyContract(
  http.Client client,
  AuthSession session,
) async {
  final general = await _getJsonMap(client, '/settings/general');
  final appName = _expectNonEmptyString(general['app_name'], 'app_name');
  final runtime = _expectJsonMap(general['message_runtime'], 'message_runtime');
  expect(
    _expectNonEmptyString(
      runtime['server_storage_mode'],
      'message_runtime.server_storage_mode',
    ),
    isIn(['persist', 'relay_only']),
  );
  expect(
    _expectNonEmptyString(
      runtime['content_audit_mode'],
      'message_runtime.content_audit_mode',
    ),
    isIn(['plaintext', 'e2ee']),
  );

  final appNamePayload = await _getJsonMap(client, '/settings/app-name');
  expect(appNamePayload['app_name'], appName);

  final captcha = await _getJsonMap(client, '/settings/captcha');
  expect(captcha['require_captcha_for_login'], isA<bool>());

  final privacy = await _getJsonMap(client, '/settings/privacy-policy');
  expect(
    _expectNonEmptyString(privacy['content'], 'privacy.content'),
    isNotEmpty,
  );

  final agreement = await _getJsonMap(client, '/settings/user-agreement');
  expect(
    _expectNonEmptyString(agreement['content'], 'agreement.content'),
    isNotEmpty,
  );

  final uploadPolicyJson = await _getJsonMap(
    client,
    '/system/upload-policy',
    session: session,
  );
  expect(
    _expectNonEmptyString(uploadPolicyJson['version'], 'version'),
    isNotEmpty,
  );
  expect(uploadPolicyJson['max_total_size_mb'], isA<int>());
  expect(uploadPolicyJson['max_attachments_per_message'], isA<int>());
  expect(
    uploadPolicyJson['max_attachments_per_message'] as int,
    greaterThan(0),
  );
  expect(uploadPolicyJson['mime_whitelist'], isA<List<dynamic>>());
  expect(uploadPolicyJson['mime_whitelist'] as List<dynamic>, isNotEmpty);
  expect(
    uploadPolicyJson['max_size_mb_by_part_type'],
    isA<Map<String, dynamic>>(),
  );
  expect(uploadPolicyJson['mime_by_part_type'], isA<Map<String, dynamic>>());
  final rawMaxSize = _expectJsonMap(
    uploadPolicyJson['max_size_mb_by_part_type'],
    'max_size_mb_by_part_type',
  );
  final rawMimeByPartType = _expectJsonMap(
    uploadPolicyJson['mime_by_part_type'],
    'mime_by_part_type',
  );
  for (final partType in const ['image', 'video', 'audio', 'file']) {
    expect(rawMaxSize[partType], isA<int>());
    expect(rawMaxSize[partType] as int, greaterThan(0));
    expect(rawMimeByPartType[partType], isA<List<dynamic>>());
    expect(rawMimeByPartType[partType] as List<dynamic>, isNotEmpty);
  }

  final policy = UploadPolicy.fromJson(uploadPolicyJson);
  expect(
    policy.version,
    _expectNonEmptyString(uploadPolicyJson['version'], 'version'),
  );
  expect(policy.maxAttachmentsPerMessage, greaterThan(0));
  expect(policy.mimeWhitelist, isNotEmpty);
  for (final partType in const ['image', 'video', 'audio', 'file']) {
    expect(policy.maxSizeMbByPartType[partType], rawMaxSize[partType]);
    expect(policy.mimeByPartType[partType], isNotEmpty);
  }
}

Future<void> _verifyFeedbackContract(
  http.Client client,
  TokenStorage storage,
  String account,
  String suffix,
) async {
  await FeedbackService(tokenStorage: storage, client: client).submitFeedback(
    content: 'Flutter 首版 API 合同联调 $suffix',
    contact: '$account@account.redcode.local',
  );
}

Future<void> _verifyFriendContract(
  FriendService friendA,
  FriendService friendB,
  AuthSession sessionA,
  AuthSession sessionB,
  String suffix,
) async {
  final searchB = await friendA.searchUsers(sessionB.user.username);
  expect(searchB.any((user) => user.id == sessionB.user.id), isTrue);

  final request = await friendA.sendFriendRequest(
    sessionB.user.id,
    message: 'contract $suffix',
  );
  expect(request.id, isNotEmpty);

  final incoming = await friendB.fetchFriendRequests(
    direction: 'incoming',
    status: 'pending',
  );
  final incomingRequest = incoming.firstWhere((item) => item.id == request.id);
  final accepted = await friendB.respondFriendRequest(
    incomingRequest.id,
    FriendRequestAction.accept,
  );
  expect(accepted.status, FriendRequestStatus.accepted);

  final friendsOfB = await friendB.fetchFriends();
  expect(
    friendsOfB.any((friend) => friend.user.id == sessionA.user.id),
    isTrue,
  );

  final privateChat = await friendA.ensurePrivateChat(sessionB.user.id);
  expect(privateChat.roomId, isNotEmpty);
}

Future<_GroupContractResult> _verifyGroupContract({
  required RoomService roomA,
  required RoomService roomB,
  required AuthSession sessionB,
  required String suffix,
  required void Function(CreatedRoom group) onGroupCreated,
}) async {
  final group = await roomA.createGroup(
    name: 'Flutter 合同群 $suffix',
    description: 'Flutter/API contract smoke',
    memberIds: [sessionB.user.id],
  );
  expect(group.id, isNotEmpty);
  onGroupCreated(group);

  expect(await roomA.fetchRoomDetail(group.id), isNotNull);
  expect((await roomA.fetchGroupSettings(group.id)).maxMembers, greaterThan(0));

  await roomA.updateGroupSettings(
    roomId: group.id,
    joinApprovalRequired: true,
    memberCanInvite: false,
    maxMembers: 128,
  );
  final settings = await roomA.fetchGroupSettings(group.id);
  expect(settings.joinApprovalRequired, isTrue);
  expect(settings.memberCanInvite, isFalse);
  expect(settings.maxMembers, 128);

  final rule = await roomA.createRule(
    roomId: group.id,
    title: '合同群规',
    content: '保持 API 合同可用',
  );
  expect(rule.id, isNotEmpty);
  await roomA.updateRule(
    roomId: group.id,
    ruleId: rule.id,
    title: '合同群规更新',
    content: '保持 Flutter API 合同可用',
    isActive: true,
  );
  final updatedRule = (await roomA.listRules(
    group.id,
  )).firstWhere((item) => item.id == rule.id);
  expect(updatedRule.title, '合同群规更新');
  expect(updatedRule.content, '保持 Flutter API 合同可用');
  expect(updatedRule.isActive, isTrue);

  await roomA.appointAdmin(roomId: group.id, userId: sessionB.user.id);
  expect(
    (await roomA.listAdmins(
      group.id,
    )).any((admin) => admin.adminId == sessionB.user.id),
    isTrue,
  );
  await roomA.removeAdmin(roomId: group.id, userId: sessionB.user.id);
  expect(
    (await roomA.listAdmins(
      group.id,
    )).any((admin) => admin.adminId == sessionB.user.id),
    isFalse,
  );
  await roomA.muteUser(
    roomId: group.id,
    userId: sessionB.user.id,
    durationHours: 1,
    reason: 'contract mute $suffix',
  );
  final memberSettings = await roomB.fetchGroupSettings(group.id);
  expect(memberSettings.myMute, isNotNull);
  expect(memberSettings.myMute!.isMuted, isTrue);
  expect(memberSettings.myMute!.reason, 'contract mute $suffix');
  expect(
    (await roomA.listMutedUsers(
      group.id,
    )).any((mute) => mute.userId == sessionB.user.id),
    isTrue,
  );
  await roomA.unmuteUser(roomId: group.id, userId: sessionB.user.id);
  expect(
    (await roomA.listMutedUsers(
      group.id,
    )).any((mute) => mute.userId == sessionB.user.id),
    isFalse,
  );
  expect(await roomA.listJoinRequests(group.id), isEmpty);
  expect(await roomA.listOperationLogs(roomId: group.id), isNotEmpty);

  return _GroupContractResult(group: group, rule: updatedRule);
}

Future<Message> _verifyMessageContract({
  required http.Client client,
  required AuthSession sessionA,
  required AuthSession sessionB,
  required MessageService messageA,
  required MessageService messageB,
  required CreatedRoom group,
  required String suffix,
}) async {
  final text = 'flutter-contract-message-$suffix';
  await messageA.sendTextMessage(group.id, text);
  final sent = await _waitForMessage(messageA, group.id, text);
  expect(sent.status, MessageStatus.sent);

  final memberCount = await messageA.fetchRoomMemberCount(group.id);
  expect(memberCount, greaterThanOrEqualTo(2));
  expect(await messageA.fetchRoomMembers(group.id), isNotEmpty);

  await messageA.editMessage(
    roomId: group.id,
    messageId: sent.id,
    content: '$text-edited',
  );
  final edited = await _waitForMessage(messageA, group.id, '$text-edited');
  expect(edited.isEdited, isTrue);

  final rawEdited = await _fetchRawMessage(
    client,
    sessionA,
    group.id,
    edited.id,
  );
  expect(rawEdited['content'], '$text-edited');
  expect(_asBool(rawEdited['is_edited']), isTrue);

  final reactions = await messageB.addReaction(
    roomId: group.id,
    messageId: edited.id,
    reactionKey: '👍',
  );
  expect(reactions.any((summary) => summary.reactionKey == '👍'), isTrue);
  expect(
    (await messageA.getReactions(
      roomId: group.id,
      messageId: edited.id,
    )).any((summary) => summary.reactionKey == '👍'),
    isTrue,
  );

  await messageA.pinMessage(group.id, edited.id);
  final pinned = await _fetchRawMessage(client, sessionA, group.id, edited.id);
  expect(_asBool(pinned['is_pinned']), isTrue);
  expect(pinned['pinned_at'], isNotNull);

  await messageA.unpinMessage(group.id, edited.id);
  final unpinned = await _fetchRawMessage(
    client,
    sessionA,
    group.id,
    edited.id,
  );
  expect(_asBool(unpinned['is_pinned']), isFalse);

  await messageB.loadMessages(group.id, limit: 20);
  await messageB.markMessagesAsRead(group.id, edited.id);
  final readers = await _eventually<List>(
    () async =>
        messageA.fetchMessageReaders(group.id, edited.id, forceRefresh: true),
    (value) => value.any((reader) => reader.userId == sessionB.user.id),
  );
  expect(readers, isNotEmpty);

  final chats = await messageA.fetchChats(force: true);
  expect(chats.any((chat) => chat.roomId == group.id), isTrue);

  await _verifyConversationPreferenceContract(
    client: client,
    session: sessionA,
    messageService: messageA,
    roomId: group.id,
  );

  final searchPayload = await _getJsonMap(
    client,
    '/messages/search',
    session: sessionA,
    queryParameters: {
      'query': '$text-edited',
      'room_id': group.id,
      'limit': '10',
    },
  );
  final results = searchPayload['results'] as List<dynamic>;
  expect(results.any((item) => '${item['id']}' == edited.id), isTrue);

  await messageB.removeReaction(
    roomId: group.id,
    messageId: edited.id,
    reactionKey: '👍',
  );
  expect(
    (await messageA.getReactions(
      roomId: group.id,
      messageId: edited.id,
    )).any((summary) => summary.reactionKey == '👍' && summary.count > 0),
    isFalse,
  );

  return edited;
}

Future<void> _verifyConversationPreferenceContract({
  required http.Client client,
  required AuthSession session,
  required MessageService messageService,
  required String roomId,
}) async {
  final notificationResponse = await client.post(
    Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/notification-settings'),
    headers: _jsonAuthHeaders(session),
    body: jsonEncode({'notification_settings': 1}),
  );
  expect(
    notificationResponse.statusCode,
    200,
    reason: 'update notification settings failed: ${notificationResponse.body}',
  );
  final notificationPayload = _expectJsonMap(
    jsonDecode(notificationResponse.body),
    'notification settings',
  );
  expect(notificationPayload['notification_settings'], 1);

  final chatsWithMentions = await messageService.fetchChats(force: true);
  expect(
    chatsWithMentions
        .singleWhere((chat) => chat.roomId == roomId)
        .notificationMode,
    ChatNotificationMode.mentions,
  );

  final archiveResponse = await client.delete(
    Uri.parse('${AppConfig.apiBaseUrl}/chats/$roomId'),
    headers: _authHeaders(session),
  );
  expect(
    archiveResponse.statusCode,
    200,
    reason: 'archive chat failed: ${archiveResponse.body}',
  );
  expect(
    _asBool(
      _expectJsonMap(
        jsonDecode(archiveResponse.body),
        'archive chat',
      )['success'],
    ),
    isTrue,
  );
  expect(
    (await messageService.fetchChats(
      force: true,
    )).any((chat) => chat.roomId == roomId),
    isFalse,
  );

  final restoreResponse = await client.post(
    Uri.parse('${AppConfig.apiBaseUrl}/chats/$roomId/restore'),
    headers: _authHeaders(session),
  );
  expect(
    restoreResponse.statusCode,
    200,
    reason: 'restore chat failed: ${restoreResponse.body}',
  );
  expect(
    _asBool(
      _expectJsonMap(
        jsonDecode(restoreResponse.body),
        'restore chat',
      )['success'],
    ),
    isTrue,
  );
  expect(
    (await messageService.fetchChats(
      force: true,
    )).any((chat) => chat.roomId == roomId),
    isTrue,
  );
}

Future<Message> _waitForMessage(
  MessageService service,
  String roomId,
  String content,
) {
  return _eventually<Message>(() async {
    final messages = await service.loadMessages(roomId, limit: 20);
    return messages.lastWhere((message) => message.content == content);
  }, (_) => true);
}

Future<T> _eventually<T>(
  Future<T> Function() action,
  bool Function(T value) predicate, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 300),
  Duration actionTimeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  StackTrace? lastStack;

  while (DateTime.now().isBefore(deadline)) {
    try {
      final remaining = deadline.difference(DateTime.now());
      final attemptTimeout = remaining < actionTimeout
          ? remaining
          : actionTimeout;
      final value = await action().timeout(attemptTimeout);
      if (predicate(value)) {
        return value;
      }
    } catch (error, stackTrace) {
      lastError = error;
      lastStack = stackTrace;
    }
    await Future<void>.delayed(interval);
  }

  if (lastError != null) {
    Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
  }
  throw TimeoutException('condition was not met before timeout');
}

Future<void> _registerAndUnregisterPushDevice({
  required http.Client client,
  required AuthSession session,
  required String deviceId,
  required String deviceToken,
}) async {
  final register = await client.post(
    Uri.parse('${AppConfig.apiBaseUrl}/push/devices'),
    headers: _jsonAuthHeaders(session),
    body: jsonEncode({
      'device_id': deviceId,
      'platform': 'android',
      'channel': 'fcm',
      'device_token': deviceToken,
    }),
  );
  expect(
    register.statusCode,
    200,
    reason: 'register push device failed: ${register.body}',
  );
  final registerPayload = _expectJsonMap(
    jsonDecode(register.body),
    'register_push_device',
  );
  expect(registerPayload['success'], isTrue);
  expect(registerPayload['device_id'], deviceId);

  final unregister = await client.delete(
    Uri.parse('${AppConfig.apiBaseUrl}/push/devices/$deviceId'),
    headers: _jsonAuthHeaders(session),
  );
  expect(
    unregister.statusCode,
    200,
    reason: 'unregister push device failed: ${unregister.body}',
  );
  final payload = _expectJsonMap(
    jsonDecode(unregister.body),
    'unregister_push_device',
  );
  expect(payload['success'], isTrue);
  expect(payload['message'], '设备已注销');
}

Future<Map<String, dynamic>> _fetchRawMessage(
  http.Client client,
  AuthSession session,
  String roomId,
  String messageId,
) async {
  final response = await client.get(
    Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages',
    ).replace(queryParameters: {'limit': '50'}),
    headers: _authHeaders(session),
  );
  expect(
    response.statusCode,
    200,
    reason: 'fetch message failed: ${response.body}',
  );
  final decoded = jsonDecode(response.body);
  expect(decoded, isA<List<dynamic>>());
  final messages = decoded as List<dynamic>;
  dynamic raw;
  for (final item in messages) {
    if ('${item['id']}' == messageId) {
      raw = item;
      break;
    }
  }
  expect(
    raw,
    isNotNull,
    reason: 'message $messageId not found in room $roomId: ${response.body}',
  );
  return _expectJsonMap(raw, 'message');
}

Future<Map<String, dynamic>> _deleteRawMessage(
  http.Client client,
  AuthSession session,
  String roomId,
  String messageId,
) async {
  final response = await client.delete(
    Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId'),
    headers: _authHeaders(session),
  );
  expect(
    response.statusCode,
    200,
    reason: 'delete message failed: ${response.body}',
  );
  final decoded = jsonDecode(response.body);
  return _expectJsonMap(decoded, 'deleted_message');
}

Future<Map<String, dynamic>> _getJsonMap(
  http.Client client,
  String path, {
  AuthSession? session,
  Map<String, String>? queryParameters,
}) async {
  final response = await client.get(
    Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: queryParameters),
    headers: session == null ? null : _authHeaders(session),
  );
  expect(response.statusCode, 200, reason: '$path failed: ${response.body}');
  final decoded = jsonDecode(response.body);
  return _expectJsonMap(decoded, path);
}

Map<String, String> _authHeaders(AuthSession session) => {
  'Authorization': 'Bearer ${session.token}',
};

Map<String, String> _jsonAuthHeaders(AuthSession session) => {
  ..._authHeaders(session),
  'Content-Type': 'application/json',
};

Map<String, dynamic> _expectJsonMap(dynamic value, String field) {
  expect(value, isA<Map<String, dynamic>>(), reason: '$field must be object');
  return value as Map<String, dynamic>;
}

String _expectNonEmptyString(dynamic value, String field) {
  expect(value, isA<String>(), reason: '$field must be string');
  final text = value as String;
  expect(text, isNotEmpty, reason: '$field must not be empty');
  return text;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

Future<void> _bestEffortUnregisterPushDevice(
  http.Client client,
  AuthSession session,
  String deviceId,
) async {
  try {
    final response = await client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/push/devices/$deviceId'),
      headers: _jsonAuthHeaders(session),
    );
    _debugCleanupFailure(
      operation: 'unregister push device $deviceId',
      response: response,
    );
  } catch (error) {
    debugPrint('best-effort cleanup failed: unregister push device: $error');
  }
}

Future<void> _bestEffortDeleteRoom(
  http.Client client,
  AuthSession session,
  String roomId,
) async {
  try {
    final response = await client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId'),
      headers: _authHeaders(session),
    );
    _debugCleanupFailure(operation: 'delete room $roomId', response: response);
  } catch (error) {
    debugPrint('best-effort cleanup failed: delete room: $error');
  }
}

Future<void> _bestEffortDeactivateUser(
  http.Client client,
  AuthSession session,
) async {
  try {
    final response = await client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me'),
      headers: _authHeaders(session),
    );
    _debugCleanupFailure(
      operation: 'deactivate user ${session.user.id}',
      response: response,
    );
  } catch (error) {
    debugPrint('best-effort cleanup failed: deactivate user: $error');
  }
}

void _debugCleanupFailure({
  required String operation,
  required http.Response response,
}) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return;
  }
  debugPrint(
    'best-effort cleanup failed: $operation: '
    '${response.statusCode} ${response.body}',
  );
}
