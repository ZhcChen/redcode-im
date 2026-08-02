import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ImSearchField extends StatefulWidget {
  const ImSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.toolbar = false,
    this.contextLabel,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool toolbar;
  final String? contextLabel;

  @override
  State<ImSearchField> createState() => _ImSearchFieldState();
}

class _ImSearchFieldState extends State<ImSearchField> {
  late final FocusNode _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(ImSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode).removeListener(
        _handleFocusChanged,
      );
      _focusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    widget.controller.removeListener(_handleTextChanged);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() => setState(() {});
  void _handleTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = widget.toolbar
        ? AppControlSize.toolbarSearch
        : AppControlSize.field;
    final focusedColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.04),
      colors.surfaceContainerHighest,
    );

    return SizedBox(
      height: height,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        maxLines: 1,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: _focusNode.hasFocus
              ? focusedColor
              : colors.surfaceContainerHighest,
          hintText: widget.hintText,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 20),
                if (widget.contextLabel != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.contextLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: AppControlSize.minTapTarget,
            minHeight: AppControlSize.minTapTarget,
          ),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: widget.controller.clear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
      ),
    );
  }
}
