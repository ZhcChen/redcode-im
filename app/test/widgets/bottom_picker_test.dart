import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme/screen_adaptation.dart';
import 'package:app/core/widgets/bottom_picker.dart';

Widget _buildHost({
  required VoidCallback onPrimaryTap,
  required VoidCallback onCancel,
}) {
  return AdaptiveScreenUtilInit(
    builder: (context, _) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  BottomPicker.show(
                    context: context,
                    title: '更多操作',
                    options: [
                      BottomPickerOption(label: '置顶', onTap: onPrimaryTap),
                      const BottomPickerOption(label: '删除'),
                    ],
                    onCancel: onCancel,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
    },
  );
}

void main() {
  group('BottomPicker', () {
    testWidgets('点击选项会回调并关闭弹窗', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _buildHost(onPrimaryTap: () => tapped += 1, onCancel: () {}),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('更多操作'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);

      await tester.tap(find.text('置顶'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
      expect(find.text('更多操作'), findsNothing);
    });

    testWidgets('点击取消按钮会触发取消回调', (tester) async {
      var cancelCount = 0;
      await tester.pumpWidget(
        _buildHost(onPrimaryTap: () {}, onCancel: () => cancelCount += 1),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(cancelCount, 1);
      expect(find.text('更多操作'), findsNothing);
    });
  });
}
