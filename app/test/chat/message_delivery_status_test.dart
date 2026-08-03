import 'package:app/core/services/message_service.dart';
import 'package:app/features/chat/widgets/message_delivery_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed status exposes retry semantics and invokes callback', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageDeliveryStatus(
            status: MessageStatus.failed,
            color: Colors.white,
            onRetry: () => retries += 1,
          ),
        ),
      ),
    );

    expect(find.byTooltip('发送失败，点击重试'), findsOneWidget);
    expect(tester.getSize(find.byType(InkResponse)), const Size(44, 44));
    await tester.tap(find.byType(InkResponse));
    expect(retries, 1);
  });

  testWidgets('sending status is non-interactive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageDeliveryStatus(
            status: MessageStatus.sending,
            color: Colors.black,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-delivery-status-sending')),
      findsOneWidget,
    );
    expect(find.byType(InkResponse), findsNothing);
  });
}
