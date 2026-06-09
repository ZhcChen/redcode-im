import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/chat/widgets/voice_message_widget.dart';

Widget _buildHost({required int duration, bool isMine = false}) {
  return MaterialApp(
    home: MediaQuery(
      // 锁定测试文本缩放，避免设备无障碍字体导致布局断言不稳定。
      data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
      child: Scaffold(
        body: Center(
          child: VoiceMessageWidget(
            audioUrl: 'https://example.com/audio.m4a',
            duration: duration,
            isMine: isMine,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VoiceMessageWidget', () {
    testWidgets('渲染时长文本与默认播放图标', (tester) async {
      await tester.pumpWidget(_buildHost(duration: 65000));

      expect(find.text('1:05'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('小时长时气泡宽度不小于最小值', (tester) async {
      await tester.pumpWidget(_buildHost(duration: 0));
      final width = tester.getSize(find.byType(VoiceMessageWidget)).width;

      expect(width, greaterThanOrEqualTo(100));
      expect(width, lessThanOrEqualTo(200));
    });

    testWidgets('长时长时气泡宽度不超过最大值', (tester) async {
      await tester.pumpWidget(_buildHost(duration: 65000));
      final width = tester.getSize(find.byType(VoiceMessageWidget)).width;

      expect(width, greaterThanOrEqualTo(100));
      expect(width, lessThanOrEqualTo(200));
    });
  });
}
