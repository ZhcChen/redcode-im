import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/phone_density.dart';
import 'package:app/core/theme/screen_adaptation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/chat/chat_detail_page_v2.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:provider/provider.dart';

class _StubChatProvider extends ChangeNotifier implements ChatProvider {
  _StubChatProvider({bool isSending = false}) : _isSending = isSending;

  bool _isSending;

  @override
  bool get isSending => _isSending;

  void setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildHost({
  required TextEditingController controller,
  required FocusNode focusNode,
  required VoidCallback onSendMessage,
  required VoidCallback onToggleVoice,
  required VoidCallback onToggleEmoji,
  required VoidCallback onToggleMore,
  required _StubChatProvider provider,
  bool isDisabled = false,
  String? disabledHint,
  bool showEmojiPanel = false,
  bool showMorePanel = false,
  bool useRealTheme = false,
  bool useAdaptiveDensity = false,
}) {
  Widget buildApp(ThemeData? theme) {
    return MaterialApp(
      theme: theme,
      builder: useAdaptiveDensity
          ? (context, child) =>
                AdaptivePhoneDensity(child: child ?? const SizedBox.shrink())
          : null,
      home: Scaffold(
        body: ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: ChatInputWidget(
            controller: controller,
            focusNode: focusNode,
            onSendMessage: onSendMessage,
            onToggleVoice: onToggleVoice,
            onToggleEmoji: onToggleEmoji,
            onToggleMore: onToggleMore,
            showEmojiPanel: showEmojiPanel,
            showMorePanel: showMorePanel,
            isDisabled: isDisabled,
            disabledHint: disabledHint,
          ),
        ),
      ),
    );
  }

  if (!useRealTheme) {
    return buildApp(null);
  }

  return AdaptiveScreenUtilInit(
    builder: (context, _) => buildApp(AppTheme.light),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatInputWidget', () {
    testWidgets('无输入文本时不显示发送按钮', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
        ),
      );

      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('整行输入区保持垂直居中对齐', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
        ),
      );

      final inputRow = tester.widget<Row>(
        find
            .descendant(
              of: find.byType(ChatInputWidget),
              matching: find.byType(Row),
            )
            .first,
      );

      expect(inputRow.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets('输入文本后显示发送按钮并触发发送回调', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();
      var sendCount = 0;

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () => sendCount += 1,
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
        ),
      );

      await tester.enterText(find.byType(TextField), '你好，世界');
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sendCount, 1);
    });

    testWidgets('可通过按钮触发语音/表情/更多操作回调', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();
      var voiceTapCount = 0;
      var emojiTapCount = 0;
      var moreTapCount = 0;

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () => voiceTapCount += 1,
          onToggleEmoji: () => emojiTapCount += 1,
          onToggleMore: () => moreTapCount += 1,
          provider: provider,
        ),
      );

      final iconButtons = find.byType(InkWell);
      expect(iconButtons, findsNWidgets(3));

      await tester.tap(iconButtons.at(0));
      await tester.pump();
      await tester.tap(iconButtons.at(1));
      await tester.pump();
      await tester.tap(iconButtons.at(2));
      await tester.pump();

      expect(voiceTapCount, 1);
      expect(emojiTapCount, 1);
      expect(moreTapCount, 1);
    });

    testWidgets('禁言态输入框禁用并展示禁言提示文案', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
          isDisabled: true,
          disabledHint: '全员禁言',
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(find.text('全员禁言'), findsOneWidget);
    });

    testWidgets('真实主题下空输入态提示文案和光标保持垂直居中', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;

      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
          useRealTheme: true,
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('chat-input-text-field')),
      );
      expect(field.decoration?.constraints?.minHeight, 0);
      expect(field.style?.fontSize, 15);
      expect(field.style?.height, 1.3);
      expect(field.decoration?.hintStyle?.fontSize, 15);
      expect(field.decoration?.hintStyle?.height, 1.3);

      final containerBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('chat-input-text-container')),
      );
      final containerTopLeft = containerBox.localToGlobal(Offset.zero);
      final containerCenterY =
          containerTopLeft.dy + containerBox.size.height / 2;

      final hintBox = tester.renderObject<RenderBox>(find.text('发送消息...'));
      final hintTopLeft = hintBox.localToGlobal(Offset.zero);
      final hintCenterY = hintTopLeft.dy + hintBox.size.height / 2;
      expect((hintCenterY - containerCenterY).abs(), lessThanOrEqualTo(2.0));

      await tester.tap(find.byKey(const ValueKey('chat-input-text-field')));
      await tester.pump();

      final editableState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final editable = editableState.renderEditable;
      final caretRect = editable.getLocalRectForCaret(
        const TextPosition(offset: 0),
      );
      final editableTopLeft = editable.localToGlobal(Offset.zero);
      final caretCenterY = editableTopLeft.dy + caretRect.center.dy;
      expect((caretCenterY - containerCenterY).abs(), lessThanOrEqualTo(2.0));
    });

    testWidgets('1.5k 设备下空输入态提示文案和光标保持垂直居中', (tester) async {
      tester.view.physicalSize = const Size(1220, 2712);
      tester.view.devicePixelRatio = 3;

      final controller = TextEditingController();
      final focusNode = FocusNode();
      final provider = _StubChatProvider();

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () {},
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
          useRealTheme: true,
          useAdaptiveDensity: true,
        ),
      );
      await tester.pumpAndSettle();

      final containerBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('chat-input-text-container')),
      );
      final containerTopLeft = containerBox.localToGlobal(Offset.zero);
      final containerCenterY =
          containerTopLeft.dy + containerBox.size.height / 2;

      final hintBox = tester.renderObject<RenderBox>(find.text('发送消息...'));
      final hintTopLeft = hintBox.localToGlobal(Offset.zero);
      final hintCenterY = hintTopLeft.dy + hintBox.size.height / 2;
      expect((hintCenterY - containerCenterY).abs(), lessThanOrEqualTo(2.0));

      await tester.tap(find.byKey(const ValueKey('chat-input-text-field')));
      await tester.pump();

      final editableState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final editable = editableState.renderEditable;
      final caretRect = editable.getLocalRectForCaret(
        const TextPosition(offset: 0),
      );
      final editableTopLeft = editable.localToGlobal(Offset.zero);
      final caretCenterY = editableTopLeft.dy + caretRect.center.dy;
      expect((caretCenterY - containerCenterY).abs(), lessThanOrEqualTo(2.0));
    });

    testWidgets('发送中时发送按钮进入 loading 态并不可触发', (tester) async {
      final controller = TextEditingController(text: '待发送消息');
      final focusNode = FocusNode();
      final provider = _StubChatProvider(isSending: true);
      var sendCount = 0;

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        provider.dispose();
      });

      await tester.pumpWidget(
        _buildHost(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: () => sendCount += 1,
          onToggleVoice: () {},
          onToggleEmoji: () {},
          onToggleMore: () {},
          provider: provider,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final maybeSendIcon = find.byIcon(Icons.send_rounded);
      if (maybeSendIcon.evaluate().isNotEmpty) {
        await tester.tap(maybeSendIcon);
        await tester.pump();
      }

      expect(sendCount, 0);
    });
  });
}
