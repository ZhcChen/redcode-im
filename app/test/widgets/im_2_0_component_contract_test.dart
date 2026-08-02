import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/design_tokens.dart';
import 'package:app/core/widgets/im_action_dialog.dart';
import 'package:app/core/widgets/im_app_bar.dart';
import 'package:app/core/widgets/im_list_row.dart';
import 'package:app/core/widgets/im_search_field.dart';
import 'package:app/core/widgets/im_state_panel.dart';
import 'package:app/core/widgets/im_surface.dart';
import 'package:app/core/widgets/im_tab_bar.dart';
import 'package:app/core/widgets/quiet_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(375, 812)}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('QuietIconButton keeps a 44dp target and accessible name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        QuietIconButton(
          icon: Icons.arrow_back,
          tooltip: '返回',
          onPressed: () {},
        ),
      ),
    );

    expect(tester.getSize(find.byType(QuietIconButton)), const Size(44, 44));
    expect(find.byTooltip('返回'), findsOneWidget);
  });

  testWidgets('ImAppBar and ImSurface use stable semantic dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: const ImAppBar(title: '联系人'),
          body: const ImSurface(child: Text('内容')),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ImAppBar)).height, 56);
    final surface = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ImSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.group));
  });

  testWidgets('ImListRow handles long content without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ImListRow(
          leading: const CircleAvatar(),
          title: const Text('这是一个用于验证超长联系人名称不会破坏列表布局的标题'),
          subtitle: const Text('这是一段更长的摘要内容，用于验证窄屏和大字号下的换行规则。'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        size: const Size(320, 700),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ImListRow)).height,
      greaterThanOrEqualTo(AppControlSize.minTapTarget),
    );
  });

  testWidgets('ImListRow supports 2x text scaling without overlap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: ImListRow(
              title: Text('超长标题在大字号模式下保持可读'),
              subtitle: Text('摘要允许换行且不会覆盖后续内容'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ImListRow)).height, greaterThan(80));
  });

  testWidgets('ImSearchField uses 48dp field and 44dp toolbar variants', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ImSearchField(controller: controller, hintText: '搜索'),
            ImSearchField(
              controller: controller,
              hintText: '搜索消息',
              toolbar: true,
            ),
          ],
        ),
      ),
    );

    final fields = find.byType(ImSearchField);
    expect(tester.getSize(fields.at(0)).height, AppControlSize.field);
    expect(tester.getSize(fields.at(1)).height, AppControlSize.toolbarSearch);
  });

  testWidgets('ImStatePanel action keeps a 44dp minimum target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ImStatePanel(
          icon: Icons.cloud_off_outlined,
          title: '加载失败',
          message: '请检查网络后重试',
          actionLabel: '重试',
          onAction: () {},
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, '重试')).height,
      greaterThanOrEqualTo(AppControlSize.minTapTarget),
    );
  });

  testWidgets('ImActionDialog exposes a named dialog route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showImActionDialog(
              context: context,
              title: '删除消息',
              message: '删除后无法恢复',
              confirmLabel: '删除',
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(ImActionDialog), findsOneWidget);
    expect(find.text('删除消息'), findsOneWidget);
    expect(find.bySemanticsLabel('删除消息'), findsWidgets);
  });

  testWidgets('ImActionDialog restores the previous focus after closing', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            dialogContext = context;
            return Scaffold(body: TextField(focusNode: focusNode));
          },
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final result = showImActionDialog(context: dialogContext, title: '确认操作');
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('ImTabBar keeps labels, selection and stable height', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.bottomCenter,
          child: StatefulBuilder(
            builder: (context, setState) => ImTabBar(
              currentIndex: selected,
              onSelected: (index) => setState(() => selected = index),
              items: const [
                ImTabItem(icon: Icons.chat_bubble_outline, label: '聊天'),
                ImTabItem(icon: Icons.people_outline, label: '联系人'),
                ImTabItem(icon: Icons.explore_outlined, label: '发现'),
                ImTabItem(icon: Icons.person_outline, label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ImTabBar)).height, 64);
    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(selected, 3);
  });

  testWidgets('ImTabBar expands only by the bottom safe area', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 812),
            padding: EdgeInsets.only(bottom: 20),
          ),
          child: Scaffold(
            bottomNavigationBar: ImTabBar(
              currentIndex: 0,
              onSelected: _ignoreSelection,
              items: const [
                ImTabItem(icon: Icons.chat_bubble_outline, label: '聊天'),
                ImTabItem(icon: Icons.person_outline, label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ImTabBar)).height, 84);
  });

  testWidgets('ImTabBar grows for large text without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            bottomNavigationBar: ImTabBar(
              currentIndex: 0,
              onSelected: _ignoreSelection,
              items: const [
                ImTabItem(icon: Icons.chat_bubble_outline, label: '聊天'),
                ImTabItem(icon: Icons.people_outline, label: '联系人'),
                ImTabItem(icon: Icons.explore_outlined, label: '发现'),
                ImTabItem(icon: Icons.person_outline, label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ImTabBar)).height,
      greaterThan(AppControlSize.bottomBar),
    );
  });
}

void _ignoreSelection(int _) {}
