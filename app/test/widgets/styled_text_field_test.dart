import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/widgets/styled_text_field.dart';

Widget _buildHost(StyledTextField field) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: field),
    ),
  );
}

void main() {
  group('StyledTextField', () {
    testWidgets('多行模式会生成更高输入框并展示标签', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildHost(
          StyledTextField(
            controller: controller,
            labelText: '备注',
            hintText: '请输入备注',
            maxLines: 4,
            minLines: 2,
          ),
        ),
      );

      expect(find.text('备注'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      final textFieldSize = tester.getSize(find.byType(TextFormField));
      expect(textFieldSize.height, greaterThanOrEqualTo(140));
    });

    testWidgets('禁用态不可编辑且不更新 controller', (tester) async {
      final controller = TextEditingController(text: '只读内容');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildHost(
          StyledTextField(
            controller: controller,
            labelText: '名称',
            enabled: false,
          ),
        ),
      );

      expect(find.text('名称'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '尝试修改');
      await tester.pump();

      expect(controller.text, '只读内容');

      final inputDecorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(
        inputDecorator.decoration.labelStyle?.color,
        AppColors.settingsTextMuted,
      );
    });
  });
}
