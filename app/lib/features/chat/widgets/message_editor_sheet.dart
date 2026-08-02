import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

Future<String?> showMessageEditorSheet({
  required BuildContext context,
  required String initialContent,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MessageEditorSheet(initialContent: initialContent),
  );
}

class _MessageEditorSheet extends StatefulWidget {
  const _MessageEditorSheet({required this.initialContent});

  final String initialContent;

  @override
  State<_MessageEditorSheet> createState() => _MessageEditorSheetState();
}

class _MessageEditorSheetState extends State<_MessageEditorSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final value = _controller.text.trim();
    return value.isNotEmpty && value != widget.initialContent.trim();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '编辑消息',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '取消编辑',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: '输入消息内容'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _canSubmit
                      ? () => Navigator.of(context).pop(_controller.text.trim())
                      : null,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
