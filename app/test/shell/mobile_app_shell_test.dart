import 'package:app/shell/mobile/mobile_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile shell keeps four tab states and handles reselection', (
    tester,
  ) async {
    var reselected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: MobileAppShell(
          pages: const [
            _CounterPage(label: '聊天页'),
            _CounterPage(label: '联系人页'),
            _CounterPage(label: '发现页'),
            _CounterPage(label: '我的页'),
          ],
          onReselect: (index) => reselected = index,
        ),
      ),
    );

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('联系人'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('联系人'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('联系人页: 1'), findsOneWidget);

    await tester.tap(find.text('聊天'));
    await tester.pump();
    await tester.tap(find.text('联系人'));
    await tester.pump();
    expect(find.text('联系人页: 1'), findsOneWidget);

    await tester.tap(find.text('联系人'));
    expect(reselected, 1);
  });

  testWidgets('mobile shell exposes chat and contact badges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileAppShell(
          pages: const [Text('聊天页'), Text('联系人页'), Text('发现页'), Text('我的页')],
          badgeCounts: const [3, 2, 0, 0],
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'聊天，3 条未读')), findsOneWidget);
  });
}

class _CounterPage extends StatefulWidget {
  const _CounterPage({required this.label});

  final String label;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.label}: $count'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: const Text('+'),
        ),
      ],
    );
  }
}
