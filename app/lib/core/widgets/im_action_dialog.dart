import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

Future<bool?> showImActionDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
  bool barrierDismissible = true,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    builder: (context) => ImActionDialog(
      title: title,
      message: message,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      danger: danger,
    ),
  );
  if (previousFocus != null && previousFocus.canRequestFocus) {
    previousFocus.requestFocus();
  }
  return result;
}

class ImActionDialog extends StatelessWidget {
  const ImActionDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel = '确定',
    this.cancelLabel = '取消',
    this.danger = false,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: AlertDialog(
        title: Text(title),
        content: content ?? (message == null ? null : Text(message!)),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
