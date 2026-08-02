import 'models/chat_model.dart';
import 'models/message_model.dart';

typedef MessageForwardCallback =
    Future<void> Function(Message message, Chat target);

class MessageForwardFailure {
  const MessageForwardFailure({
    required this.message,
    required this.target,
    required this.error,
  });

  final Message message;
  final Chat target;
  final Object error;
}

class MessageForwardResult {
  const MessageForwardResult({
    required this.successCount,
    required this.failures,
    required this.targetCount,
  });

  final int successCount;
  final List<MessageForwardFailure> failures;
  final int targetCount;

  bool get isCompleteSuccess => failures.isEmpty && successCount > 0;
  bool get isCompleteFailure => successCount == 0 && failures.isNotEmpty;
  int get failureCount => failures.length;

  List<String> get failedTargetNames => failures
      .map((failure) => failure.target.name)
      .toSet()
      .toList(growable: false);
}

Future<MessageForwardResult> forwardMessagesToTargets({
  required List<Message> messages,
  required List<Chat> targets,
  required MessageForwardCallback forward,
}) async {
  final failures = <MessageForwardFailure>[];
  var successCount = 0;

  for (final target in targets) {
    for (final message in messages) {
      try {
        await forward(message, target);
        successCount += 1;
      } catch (error) {
        failures.add(
          MessageForwardFailure(message: message, target: target, error: error),
        );
      }
    }
  }

  return MessageForwardResult(
    successCount: successCount,
    failures: List.unmodifiable(failures),
    targetCount: targets.length,
  );
}
