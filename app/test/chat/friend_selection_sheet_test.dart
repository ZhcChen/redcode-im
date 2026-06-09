import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/widgets/friend_selection_sheet.dart';
import 'package:app/features/contacts/models/friend_models.dart';

Widget _buildHost({
  required List<FriendInfo> friends,
  required ValueChanged<Set<String>?> onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final result = await FriendSelectionSheet.show(
                context,
                friends: friends,
                initialSelected: const {},
                title: '选择成员',
              );
              onResult(result);
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
}

FriendInfo _friend({
  required String id,
  required String username,
  String? nickname,
}) {
  return FriendInfo(
    id: 'f-$id',
    user: AuthUser(id: id, username: username, nickname: nickname),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('FriendSelectionSheet', () {
    testWidgets('支持搜索并返回选中的好友 ID', (tester) async {
      Set<String>? result;
      final friends = [
        _friend(id: 'u-1', username: 'alice', nickname: '爱丽丝'),
        _friend(id: 'u-2', username: 'bob'),
      ];

      await tester.pumpWidget(
        _buildHost(friends: friends, onResult: (value) => result = value),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('选择成员'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pumpAndSettle();

      expect(find.text('爱丽丝'), findsOneWidget);
      expect(find.text('bob'), findsNothing);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(find.text('确定（1）'), findsOneWidget);

      await tester.tap(find.text('确定（1）'));
      await tester.pumpAndSettle();

      expect(result, {'u-1'});
    });
  });
}
