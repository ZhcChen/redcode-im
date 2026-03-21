import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/widgets/reaction_picker.dart';

Widget _buildHost({
  required void Function(String reaction) onSelected,
  List<String> reactions = const ['😀', '🎉', '👍'],
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                showReactionPicker(
                  context: context,
                  position: const Offset(24, 24),
                  reactions: reactions,
                  onReactionSelected: onSelected,
                );
              },
              child: const Text('open-picker'),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  group('ReactionPicker', () {
    testWidgets('selecting a reaction triggers callback and closes dialog', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _buildHost(onSelected: (reaction) => selected = reaction),
      );

      await tester.tap(find.text('open-picker'));
      await tester.pumpAndSettle();

      expect(find.text('😀'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);

      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();

      expect(selected, '🎉');
      expect(find.text('😀'), findsNothing);
    });

    testWidgets('tap outside closes picker without selecting reaction', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _buildHost(onSelected: (reaction) => selected = reaction),
      );

      await tester.tap(find.text('open-picker'));
      await tester.pumpAndSettle();

      expect(find.text('👍'), findsOneWidget);

      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(selected, isNull);
      expect(find.text('👍'), findsNothing);
    });
  });
}
