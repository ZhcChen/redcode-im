import 'package:app/core/widgets/input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHost({
  required Future<String?> Function(String value)? onConfirm,
  String? Function(String?)? validator,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              InputDialog.show(
                context,
                title: '编辑名称',
                hintText: '请输入名称',
                confirmText: '保存',
                onConfirm: onConfirm,
                validator: validator,
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
}

void main() {
  group('InputDialog', () {
    testWidgets('输入有效内容后确认会关闭弹窗', (tester) async {
      await tester.pumpWidget(_buildHost(onConfirm: (value) async => value));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  新名字  ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('编辑名称'), findsNothing);
    });

    testWidgets('校验不通过时不会关闭弹窗并展示错误', (tester) async {
      await tester.pumpWidget(
        _buildHost(
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.length < 3) return '至少3个字';
            return null;
          },
          onConfirm: (value) async => value,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ab');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('编辑名称'), findsOneWidget);
      expect(find.text('至少3个字'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'abcd');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('编辑名称'), findsNothing);
    });

    testWidgets('onConfirm 返回 null 时保持弹窗开启', (tester) async {
      await tester.pumpWidget(_buildHost(onConfirm: (_) async => null));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '内容');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('编辑名称'), findsOneWidget);

      Navigator.of(tester.element(find.byType(InputDialog))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('确认输入只关闭弹窗并保留宿主页', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('宿主页'),
                  TextButton(
                    onPressed: () async {
                      result = await InputDialog.show(context, title: '设置备注');
                    },
                    child: const Text('打开'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '新备注');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, '新备注');
      expect(find.text('宿主页'), findsOneWidget);
      expect(find.byType(InputDialog), findsNothing);
    });
  });
}
