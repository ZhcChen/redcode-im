import 'package:app/features/chat/message_forward_executor.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continues forwarding after an individual target fails', () async {
    final messages = [_message('m1'), _message('m2')];
    final targets = [_chat('c1', 'Alice'), _chat('c2', 'Bob')];
    final attempts = <String>[];

    final result = await forwardMessagesToTargets(
      messages: messages,
      targets: targets,
      forward: (message, target) async {
        attempts.add('${message.id}:${target.id}');
        if (message.id == 'm2' && target.id == 'c1') throw Exception('failed');
      },
    );

    expect(attempts, ['m1:c1', 'm2:c1', 'm1:c2', 'm2:c2']);
    expect(result.successCount, 3);
    expect(result.failureCount, 1);
    expect(result.failedTargetNames, ['Alice']);
    expect(result.isCompleteSuccess, isFalse);
    expect(result.isCompleteFailure, isFalse);
  });
}

Chat _chat(String id, String name) => Chat(
  id: id,
  roomId: 'room-$id',
  name: name,
  type: ChatType.single,
  lastMessage: '',
  lastMessageTime: DateTime(2026, 8, 2),
);

Message _message(String id) => Message(
  id: id,
  roomId: 'source',
  senderId: 'sender',
  senderUsername: 'sender',
  senderName: 'Sender',
  content: 'hello',
  type: MessageType.text,
  status: MessageStatus.sent,
  timestamp: DateTime(2026, 8, 2),
  isSelf: true,
);
