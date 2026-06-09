import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/custom_switch.dart';

Widget _buildHost(CustomSwitch child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('CustomSwitch', () {
    testWidgets('点击开关会回调反向值', (tester) async {
      bool? changedValue;
      await tester.pumpWidget(
        _buildHost(
          CustomSwitch(
            value: false,
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(CustomSwitch));
      await tester.pumpAndSettle();

      expect(changedValue, isTrue);
    });

    testWidgets('loading 状态显示进度并忽略点击', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _buildHost(
          CustomSwitch(
            value: true,
            loading: true,
            onChanged: (_) => tapCount += 1,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(CustomSwitch));
      await tester.pump();

      expect(tapCount, 0);
    });

    testWidgets('禁用时透明度降低', (tester) async {
      await tester.pumpWidget(
        _buildHost(const CustomSwitch(value: false, onChanged: null)),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0.6);
    });
  });
}
