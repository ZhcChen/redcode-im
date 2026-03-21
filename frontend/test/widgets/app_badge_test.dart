import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppBadge', () {
    testWidgets('count greater than 99 shows 99+', (tester) async {
      await tester.pumpWidget(_wrap(AppBadge(count: 120)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('single digit count keeps zero horizontal padding', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(AppBadge(count: 7)));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppBadge),
          matching: find.byType(Container),
        ),
      );

      expect(container.padding, EdgeInsets.zero);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('custom text is displayed when count is absent', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(AppBadge(text: 'NEW')));
      expect(find.text('NEW'), findsOneWidget);
    });

    test('throws assertion when both count and text are absent', () {
      expect(() => AppBadge(), throwsA(isA<AssertionError>()));
    });
  });
}
