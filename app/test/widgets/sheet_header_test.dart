import 'package:app/core/widgets/sheet_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHost(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
}

void main() {
  testWidgets('有关闭按钮时标题仍保持几何居中', (tester) async {
    await tester.pumpWidget(
      _buildHost(SheetHeader(title: '选择新群主', onClose: () {})),
    );

    final headerCenter = tester.getCenter(find.byType(SheetHeader));
    final titleCenter = tester.getCenter(find.text('选择新群主'));

    expect((titleCenter.dx - headerCenter.dx).abs(), lessThanOrEqualTo(0.1));
  });

  testWidgets('点击关闭按钮会触发回调', (tester) async {
    var closeCount = 0;

    await tester.pumpWidget(
      _buildHost(SheetHeader(title: '更多操作', onClose: () => closeCount += 1)),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closeCount, 1);
  });
}
