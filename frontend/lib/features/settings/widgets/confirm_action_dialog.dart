import 'package:flutter/material.dart';

class ConfirmActionDialog extends StatefulWidget {
  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.confirmationKeyword,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final String? confirmationKeyword;

  @override
  State<ConfirmActionDialog> createState() => _ConfirmActionDialogState();
}

class _ConfirmActionDialogState extends State<ConfirmActionDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _keywordSatisfied {
    if (widget.confirmationKeyword == null) {
      return true;
    }
    return _controller.text.trim() == widget.confirmationKeyword;
  }

  @override
  Widget build(BuildContext context) {
    final needKeyword = widget.confirmationKeyword != null;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (needKeyword) ...[
            const SizedBox(height: 16),
            Text(
              '安全确认：请输入 “${widget.confirmationKeyword}”',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: _keywordSatisfied
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<bool?> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  String? confirmationKeyword,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => ConfirmActionDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmationKeyword: confirmationKeyword,
    ),
  );
}
