part of '../chat_detail_page_v2.dart';

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.onResend,
    this.canShowReadReceipts = false,
    this.onShowReadReceipts,
    this.onBubbleTap,
    this.onQuoteTap,
    this.onStartSelection,
    this.onToggleSelection,
    this.isSelected = false,
    this.multiSelectMode = false,
    this.isHighlighted = false,
  });

  final Message message;
  final VoidCallback onResend;
  final bool canShowReadReceipts;
  final VoidCallback? onShowReadReceipts;
  final void Function(Offset tapPosition, Message message, bool isSelf)?
  onBubbleTap;
  final void Function(String messageId)? onQuoteTap;
  final VoidCallback? onStartSelection;
  final VoidCallback? onToggleSelection;
  final bool isSelected;
  final bool multiSelectMode;
  final bool isHighlighted;

  static const double _avatarRadius = 12;
  static const double _avatarSpacing = 8;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  Message get _message => widget.message;
  bool get _isSelf => _message.isSelf;
  Offset? _lastTapPosition;

  // 高亮动画控制器
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;
  bool _wasHighlighted = false;

  @override
  void initState() {
    super.initState();
    // 创建高亮渐隐动画控制器（5秒渐隐，与桌面版一致）
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _highlightAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeOut),
    );

    // 如果初始状态就是高亮，启动动画
    if (widget.isHighlighted) {
      _wasHighlighted = true;
      _highlightController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测高亮状态变化
    if (widget.isHighlighted && !_wasHighlighted) {
      _wasHighlighted = true;
      _highlightController.reset();
      _highlightController.forward();
    } else if (!widget.isHighlighted && _wasHighlighted) {
      _wasHighlighted = false;
      _highlightController.reset();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_message.type == MessageType.system) {
      return _buildSystemMessage(context);
    }
    return _isSelf ? _buildSelfBubble(context) : _buildPeerBubble(context);
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        _message.content,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 构建高亮背景层（占满屏幕宽度）
  Widget _buildHighlightOverlay({required Widget child}) {
    if (!widget.isHighlighted && !_highlightController.isAnimating) {
      return child;
    }

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, _) {
        // 桌面版颜色: rgba(78, 205, 196, 0.5)
        final highlightColor = Color.fromRGBO(
          78,
          205,
          196,
          0.5 * _highlightAnimation.value,
        );

        // 使用 Stack + OverflowBox 实现全宽背景
        // 消息列表有 16px 的左右 padding，需要扩展背景来覆盖
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 背景层：向左右各扩展 16px 以覆盖整个屏幕宽度
            Positioned(
              left: -16,
              right: -16,
              top: 0,
              bottom: 0,
              child: Container(color: highlightColor),
            ),
            // 内容层
            child,
          ],
        );
      },
    );
  }

  Widget _buildSelfBubble(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.8;
    return _buildHighlightOverlay(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTapDown: (details) => _lastTapPosition = details.globalPosition,
          onTap: () {
            if (widget.multiSelectMode) {
              widget.onToggleSelection?.call();
            } else {
              widget.onBubbleTap?.call(
                _lastTapPosition ?? Offset.zero,
                _message,
                _isSelf,
              );
            }
          },
          onLongPress: widget.onStartSelection,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.multiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SelectionIndicator(isSelected: widget.isSelected),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _buildBubbleContainer(
                  context,
                  child: _buildMessageContent(context),
                  isSelf: true,
                  isSelected: widget.isSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeerBubble(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _message.displaySenderName;
    return _buildHighlightOverlay(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTapDown: (details) => _lastTapPosition = details.globalPosition,
          onTap: () {
            if (widget.multiSelectMode) {
              widget.onToggleSelection?.call();
            } else {
              widget.onBubbleTap?.call(
                _lastTapPosition ?? Offset.zero,
                _message,
                _isSelf,
              );
            }
          },
          onLongPress: widget.onStartSelection,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.multiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: _SelectionIndicator(isSelected: widget.isSelected),
                ),
              _buildAvatar(false),
              const SizedBox(width: _MessageBubble._avatarSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBubbleContainer(
                      context,
                      child: _buildMessageContent(context),
                      isSelf: false,
                      isSelected: widget.isSelected,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final body = _buildMessageBody(context);

    // 混合消息或纯媒体消息自带时间显示，不需要额外的时间行
    if (_isCurrentMessageMixed() || _isPureMediaMessage()) {
      return body;
    }

    final timeRow = _buildBubbleTimeRow(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [body, const SizedBox(height: 6), timeRow],
    );
  }

  /// 判断当前消息是否是混合消息
  bool _isCurrentMessageMixed() {
    final parts = _message.parts;
    if (parts.isEmpty) return false;

    final mediaParts = parts
        .where(
          (p) =>
              p.type == MessagePartType.image ||
              p.type == MessagePartType.video,
        )
        .toList();
    final fileParts = parts
        .where((p) => p.type == MessagePartType.file)
        .toList();
    final textPart = _getMeaningfulTextPart(parts);

    return _isMixedMessage(mediaParts, fileParts, textPart);
  }

  /// 判断是否是纯媒体消息（单图/单视频，无文字）
  bool _isPureMediaMessage() {
    final parts = _message.parts;
    if (parts.isEmpty) return false;

    final mediaParts = parts
        .where(
          (p) =>
              p.type == MessagePartType.image ||
              p.type == MessagePartType.video,
        )
        .toList();
    final textPart = _getMeaningfulTextPart(parts);
    final fileParts = parts
        .where((p) => p.type == MessagePartType.file)
        .toList();

    // 单图组件自带时间角标；单视频使用文件卡片，需要保留外层状态行。
    return mediaParts.length == 1 &&
        mediaParts.single.type == MessagePartType.image &&
        textPart == null &&
        fileParts.isEmpty;
  }

  Widget _buildMessageBody(BuildContext context) {
    final quoted = _message.quotedMessage;
    final children = <Widget>[];

    if (quoted != null) {
      children.add(
        _QuotedMessagePreview(
          quoted: quoted,
          isSelf: _isSelf,
          onTap: widget.onQuoteTap == null
              ? null
              : () => widget.onQuoteTap!(quoted.id),
        ),
      );
      children.add(const SizedBox(height: 6));
    }

    children.add(_buildPrimaryContent(context));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildPrimaryContent(BuildContext context) {
    if (_message.isDeleted) {
      return _buildDeletedContent(context);
    }

    final parts = [..._message.parts]
      ..sort((a, b) => a.position.compareTo(b.position));

    if (parts.isNotEmpty) {
      // 按类型分组
      final mediaParts = parts
          .where(
            (p) =>
                p.type == MessagePartType.image ||
                p.type == MessagePartType.video,
          )
          .toList();
      final fileParts = parts
          .where((p) => p.type == MessagePartType.file)
          .toList();
      final audioParts = parts
          .where((p) => p.type == MessagePartType.audio)
          .toList();

      // 获取有意义的文本部分（过滤占位符）
      final textPart = _getMeaningfulTextPart(parts);

      // 判断是否是混合消息
      final isMixed = _isMixedMessage(mediaParts, fileParts, textPart);

      if (isMixed) {
        return _buildMixedContent(
          context,
          mediaParts: mediaParts,
          fileParts: fileParts,
          audioParts: audioParts,
          textPart: textPart,
        );
      }

      // 非混合消息：简单遍历渲染
      final widgets = <Widget>[];
      for (final part in parts) {
        final widget = _buildPartWidget(context, part);
        if (widget == null) {
          continue;
        }
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        widgets.add(widget);
      }

      if (widgets.isNotEmpty) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _isSelf
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: widgets,
        );
      }
    }

    return _buildLegacyContent(context);
  }

  /// 判断文本是否是占位符
  bool _isPlaceholderText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return true;
    return normalized == '[混合消息]' ||
        normalized == '[附件]' ||
        normalized == '[图片]' ||
        normalized == '[视频]' ||
        normalized == '[文件]' ||
        normalized.startsWith('[混合消息]') ||
        normalized.startsWith('[附件]') ||
        normalized.startsWith('[图片]') ||
        normalized.startsWith('[视频]') ||
        normalized.startsWith('[文件]');
  }

  /// 获取有意义的文本部分
  MessagePart? _getMeaningfulTextPart(List<MessagePart> parts) {
    // 获取附件名称列表
    final attachmentNames = parts
        .where(
          (p) =>
              p.type != MessagePartType.text &&
              p.attachment?.name != null &&
              p.attachment!.name!.trim().isNotEmpty,
        )
        .map((p) => p.attachment!.name!.trim())
        .toList();

    for (final part in parts) {
      if (part.type != MessagePartType.text) continue;
      final text = part.text?.trim();
      if (text == null || text.isEmpty) continue;
      if (_isPlaceholderText(text)) continue;
      // 排除文件名作为文本
      if (attachmentNames.contains(text)) continue;
      return part;
    }
    return null;
  }

  /// 判断是否是混合消息
  bool _isMixedMessage(
    List<MessagePart> mediaParts,
    List<MessagePart> fileParts,
    MessagePart? textPart,
  ) {
    // 多个媒体附件
    if (mediaParts.length > 1) return true;
    // 媒体 + 文字
    if (mediaParts.isNotEmpty && textPart != null) return true;
    // 文件 + 文字
    if (fileParts.isNotEmpty && textPart != null) return true;
    // 多种类型附件
    if (mediaParts.isNotEmpty && fileParts.isNotEmpty) return true;
    return false;
  }

  /// 构建混合消息内容
  Widget _buildMixedContent(
    BuildContext context, {
    required List<MessagePart> mediaParts,
    required List<MessagePart> fileParts,
    required List<MessagePart> audioParts,
    required MessagePart? textPart,
  }) {
    final children = <Widget>[];

    // 1) 媒体网格（图片/视频）在最上方
    if (mediaParts.isNotEmpty) {
      children.add(
        _MediaGridView(
          message: _message,
          mediaParts: mediaParts,
          isSelf: _isSelf,
          hasText: textPart != null,
          onRetry: widget.onResend,
        ),
      );
    }

    // 2) 文件列表
    for (final part in fileParts) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.insert_drive_file,
          fallbackLabel: '文件',
        ),
      );
    }

    // 3) 音频
    for (final part in audioParts) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _AudioMessageTile(message: _message, part: part, isSelf: _isSelf),
      );
    }

    // 4) 文字在最下方（带内嵌时间）
    if (textPart != null) {
      final text = textPart.text?.trim() ?? '';
      children.add(
        _MixedTextWithTime(
          text: text,
          message: _message,
          isSelf: _isSelf,
          hasMediaAbove: mediaParts.isNotEmpty,
          onRetry: widget.onResend,
        ),
      );
    }

    // 使用固定宽度容器，让媒体和文字宽度一致
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildLegacyContent(BuildContext context) {
    Widget content;
    switch (_message.type) {
      case MessageType.text:
        content = _buildTextWithEmojis(_message.content, isSelf: _isSelf);
        break;
      case MessageType.image:
        content = Text(
          '[图片]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.video:
        content = Text(
          '[视频]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.audio:
        content = Text(
          '[语音]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.file:
        content = Text(
          '[文件]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.system:
        content = Text(
          _message.content,
          style: TextStyle(
            fontSize: 14,
            color: _isSelf ? Colors.white70 : AppColors.textSecondary,
          ),
        );
        break;
      case MessageType.mixed:
        content = Text(
          _message.content,
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
    }

    final forwardInfo = _message.forwardInfo;
    if (forwardInfo != null) {
      return _ForwardedMessageContent(
        forwardInfo: forwardInfo,
        isSelf: _isSelf,
        child: content,
      );
    }

    return content;
  }

  Widget? _buildPartWidget(BuildContext context, MessagePart part) {
    switch (part.type) {
      case MessagePartType.text:
        final text = part.text?.trim();
        if (text == null || text.isEmpty) {
          return null;
        }
        return _buildTextWithEmojis(text, isSelf: _isSelf);
      case MessagePartType.image:
        return _AttachmentImageView(
          message: _message,
          part: part,
          isSelf: _isSelf,
          onRetry: widget.onResend,
        );
      case MessagePartType.video:
        return _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.movie,
          fallbackLabel: '视频',
        );
      case MessagePartType.audio:
        return _AudioMessageTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
        );
      case MessagePartType.file:
        return _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.insert_drive_file,
          fallbackLabel: '文件',
        );
    }
  }

  Widget _buildTextWithEmojis(String text, {required bool isSelf}) {
    final baseStyle = TextStyle(
      fontSize: 15,
      color: isSelf ? Colors.white : AppColors.textPrimary,
    );
    final mentionStyle = baseStyle.copyWith(
      color: isSelf ? Colors.white : AppColors.primary,
      fontWeight: FontWeight.w600,
    );

    // 识别文本中的表情URL（http://或https://开头的URL）
    // 更精确的正则：匹配完整的URL，包括可能的查询参数和片段
    final emojiUrlPattern = RegExp(
      r'(https?://[^\s<>"{}|\\^`\[\]]+)',
      caseSensitive: false,
    );
    final matches = emojiUrlPattern.allMatches(text);

    if (matches.isEmpty) {
      // 没有表情URL，直接显示文本
      return Text.rich(
        TextSpan(
          children: _buildTextSpansWithMentions(
            text,
            baseStyle: baseStyle,
            mentionStyle: mentionStyle,
          ),
        ),
      );
    }

    // 有表情URL，需要混合显示文本和图片
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // 添加匹配前的文本
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        spans.addAll(
          _buildTextSpansWithMentions(
            beforeText,
            baseStyle: baseStyle,
            mentionStyle: mentionStyle,
          ),
        );
      }

      // 添加表情图片
      final emojiUrl = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _CachedEmojiInText(imageUrl: emojiUrl, size: 24.0),
        ),
      );

      lastEnd = match.end;
    }

    // 添加剩余的文本
    if (lastEnd < text.length) {
      final afterText = text.substring(lastEnd);
      spans.addAll(
        _buildTextSpansWithMentions(
          afterText,
          baseStyle: baseStyle,
          mentionStyle: mentionStyle,
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }

  List<InlineSpan> _buildTextSpansWithMentions(
    String text, {
    required TextStyle baseStyle,
    required TextStyle mentionStyle,
  }) {
    bool isEmailLikePrevChar(String ch) {
      if (ch.isEmpty) return false;
      final code = ch.codeUnitAt(0);
      final isAsciiAlphaNum =
          (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122);
      return isAsciiAlphaNum ||
          ch == '_' ||
          ch == '.' ||
          ch == '+' ||
          ch == '-';
    }

    final mentionPattern = RegExp(r'@([0-9A-Za-z_\u4e00-\u9fff-]+)');
    final matches = mentionPattern.allMatches(text);
    if (matches.isEmpty) {
      return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final mentionText = match.group(0) ?? '';
      final start = match.start;
      final highlight = start == 0 || !isEmailLikePrevChar(text[start - 1]);
      spans.add(
        TextSpan(
          text: mentionText,
          style: highlight ? mentionStyle : baseStyle,
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }

  Widget _buildDeletedContent(BuildContext context) {
    final color = _isSelf ? Colors.white70 : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _message.isSelf ? '你已删除这条消息' : '消息已删除',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContainer(
    BuildContext context, {
    required Widget child,
    required bool isSelf,
    bool isSelected = false,
  }) {
    // 混合消息或纯媒体消息使用透明背景，不需要气泡容器
    if (_isCurrentMessageMixed() || _isPureMediaMessage()) {
      return child;
    }

    final bubbleColor = isSelf ? AppColors.primary : Colors.white;

    // 选中时的边框
    Border? border;
    if (isSelected) {
      border = Border.all(
        color: AppColors.primary.withValues(alpha: 0.5),
        width: 1,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: border,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isSelf ? 16 : 0),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(isSelf ? 0 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBubbleTimeRow(BuildContext context) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: _isSelf
          ? Colors.white.withValues(alpha: 0.8)
          : AppColors.textQuaternary,
    );

    final timeText = Text(_formatBubbleTime(), style: timeStyle);
    final pinnedIcon = _message.isPinned
        ? Icon(
            Icons.push_pin,
            size: 14,
            color: _isSelf
                ? Colors.white.withValues(alpha: 0.85)
                : AppColors.textTertiary,
          )
        : null;
    Widget? status;
    if (_message.isSelf) {
      final readTap =
          (widget.canShowReadReceipts &&
              _message.status == MessageStatus.read &&
              widget.onShowReadReceipts != null)
          ? widget.onShowReadReceipts
          : null;
      status = _buildStatusIndicator(onReadTap: readTap);
    }

    const double statusRowHeight = 16;
    return SizedBox(
      height: statusRowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: _isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: timeText),
          if (pinnedIcon != null) ...[const SizedBox(width: 6), pinnedIcon],
          if (status != null) ...[const SizedBox(width: 8), status],
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isSelf) {
    return MessageAvatar(
      message: _message,
      radius: _MessageBubble._avatarRadius,
      isSelf: isSelf,
    );
  }

  Widget? _buildStatusIndicator({VoidCallback? onReadTap}) {
    if (_message.status == MessageStatus.delivered) return null;
    return MessageDeliveryStatus(
      status: _message.status,
      color: Colors.white,
      onReadTap: onReadTap,
      onRetry: widget.onResend,
      compact: true,
    );
  }

  String _formatBubbleTime() {
    final local = _message.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: 2,
        ),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: AppColors.primary)
          : null,
    );
  }
}

class _QuotedMessagePreview extends StatefulWidget {
  const _QuotedMessagePreview({
    required this.quoted,
    required this.isSelf,
    this.onTap,
  });

  final QuotedMessage quoted;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  State<_QuotedMessagePreview> createState() => _QuotedMessagePreviewState();
}

class _QuotedMessagePreviewState extends State<_QuotedMessagePreview> {
  String? _imageLocalPath;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _QuotedMessagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quoted.id != widget.quoted.id ||
        oldWidget.quoted.imageAttachment?.key !=
            widget.quoted.imageAttachment?.key) {
      _imageLocalPath = null;
      _imageLoading = false;
      _loadImageIfNeeded();
    }
  }

  Future<void> _loadImageIfNeeded() async {
    final attachment = widget.quoted.imageAttachment;
    if (attachment == null) return;

    // 优先使用已有的本地路径
    if (attachment.localPath != null && attachment.localPath!.isNotEmpty) {
      final file = File(attachment.localPath!);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _imageLocalPath = attachment.localPath;
          });
        }
        return;
      }
    }

    // 需要下载
    if (attachment.key.isEmpty) return;

    setState(() {
      _imageLoading = true;
    });

    try {
      // 对于引用消息，构造临时的 Message 和 MessagePart 来调用缓存服务
      final tempPart = MessagePart(
        position: 0,
        type: MessagePartType.image,
        attachment: attachment,
      );
      final tempMessage = Message(
        id: widget.quoted.id,
        roomId: widget.quoted.roomId,
        senderId: widget.quoted.senderId,
        senderUsername: widget.quoted.senderUsername,
        senderName: widget.quoted.senderName,
        senderAvatar: widget.quoted.senderAvatar,
        senderAvatarObjectKey: widget.quoted.senderAvatarObjectKey,
        content: widget.quoted.content ?? '',
        type: widget.quoted.type,
        status: MessageStatus.sent,
        timestamp: widget.quoted.createdAt ?? DateTime.now(),
        isSelf: false,
        parts: [tempPart],
      );

      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.quoted.roomId,
        message: tempMessage,
        part: tempPart,
      );
      if (!mounted) return;
      setState(() {
        _imageLocalPath = path;
        _imageLoading = false;
      });
    } catch (e) {
      debugPrint('加载引用图片失败: $e');
      if (mounted) {
        setState(() {
          _imageLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFEAFFFD);
    final borderColor = widget.isSelf
        ? Colors.white.withValues(alpha: 0.24)
        : AppColors.divider;
    // 用户名颜色：#9A9BB1
    const titleColor = Color(0xFF9A9BB1);
    // 消息文字颜色：#2C2D3A
    const bodyColor = Color(0xFF2C2D3A);

    // 判断是否是图片类型
    final isImage = widget.quoted.type == MessageType.image;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.quoted.displaySenderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 如果是图片类型，显示图片；否则显示文本
          if (isImage)
            _buildImageContent()
          else
            Text(
              widget.quoted.previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.2, color: bodyColor),
            ),
        ],
      ),
    );

    if (widget.onTap == null) return content;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildAvatar() {
    return QuotedMessageAvatar(
      quotedMessage: widget.quoted,
      radius: 12, // size=24, radius=12
      isSelf: widget.isSelf,
    );
  }

  Widget _buildImageContent() {
    if (_imageLoading) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_imageLocalPath != null && _imageLocalPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_imageLocalPath!),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey, size: 32),
    );
  }
}

class _ForwardedMessageContent extends StatelessWidget {
  const _ForwardedMessageContent({
    required this.forwardInfo,
    required this.isSelf,
    required this.child,
  });

  final ForwardInfo forwardInfo;
  final bool isSelf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleColor = isSelf
        ? Colors.white.withValues(alpha: 0.9)
        : AppColors.textSecondary;
    final subtitleColor = isSelf
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textTertiary;

    IconData icon;
    switch (forwardInfo.sourceType) {
      case ForwardSourceType.group:
        icon = Icons.groups_2_rounded;
        break;
      case ForwardSourceType.favorite:
        icon = Icons.star_rounded;
        break;
      case ForwardSourceType.user:
        icon = Icons.person_rounded;
        break;
      case ForwardSourceType.unknown:
        icon = Icons.forward_to_inbox_rounded;
        break;
    }

    final originSender = forwardInfo.originSenderName?.trim();
    final showOriginSender =
        originSender != null &&
        originSender.isNotEmpty &&
        originSender != forwardInfo.displaySourceName;

    return Column(
      crossAxisAlignment: isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: titleColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '转发自 ${forwardInfo.displaySourceName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
        if (showOriginSender) ...[
          const SizedBox(height: 2),
          Text(
            '原发送人：$originSender',
            style: TextStyle(fontSize: 11, color: subtitleColor),
          ),
        ],
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _CachedEmojiInText extends StatefulWidget {
  const _CachedEmojiInText({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  State<_CachedEmojiInText> createState() => _CachedEmojiInTextState();
}

class _CachedEmojiInTextState extends State<_CachedEmojiInText> {
  String? _cachedPath;
  bool _loading = false;
  bool _error = false;
  late final EmojiItemService _emojiService = EmojiItemService();

  @override
  void initState() {
    super.initState();
    _loadEmoji();
  }

  Future<void> _loadEmoji() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      debugPrint('_CachedEmojiInText: 开始加载表情 ${widget.imageUrl}');
      final cachedPath = await _emojiService.loadAndCacheEmoji(widget.imageUrl);
      debugPrint('_CachedEmojiInText: 加载完成，缓存路径: $cachedPath');
      if (mounted) {
        setState(() {
          _cachedPath = cachedPath;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('_CachedEmojiInText: 加载失败: $e');
      debugPrint('_CachedEmojiInText: 堆栈: $stackTrace');
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SizedBox(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(Icons.image, size: widget.size * 0.6),
      );
    }

    // 优先使用缓存路径，如果缓存不存在则使用网络 URL
    if (_cachedPath != null) {
      return Image.file(
        File(_cachedPath!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          // 缓存文件损坏，尝试重新加载
          _loadEmoji();
          return Image.network(
            widget.imageUrl,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image, size: widget.size * 0.6),
          );
        },
      );
    }

    return Image.network(
      widget.imageUrl,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.image, size: widget.size * 0.6),
    );
  }
}

/// 更多操作面板

class _AttachmentImageView extends StatefulWidget {
  const _AttachmentImageView({
    required this.message,
    required this.part,
    required this.isSelf,
    required this.onRetry,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;
  final VoidCallback onRetry;

  @override
  State<_AttachmentImageView> createState() => _AttachmentImageViewState();
}

class _AttachmentImageViewState extends State<_AttachmentImageView> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  StreamSubscription<AttachmentPathUpdate>? _subscription;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;
    _loading = !hasReadableLocalFile(_localPath);
    _subscribeToUpdates();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AttachmentImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.attachment?.key != widget.part.attachment?.key) {
      _localPath = widget.part.attachment?.localPath;
      _error = null;
      _loading = !hasReadableLocalFile(_localPath);
      // 重新订阅新的 key
      _subscription?.cancel();
      _subscribeToUpdates();
      _load();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToUpdates() {
    final key = widget.part.attachment?.key;
    if (key == null) return;

    _subscription = MessageService.instance.attachmentPathUpdates.listen((
      update,
    ) {
      // 动态获取当前的 key，避免闭包捕获问题
      final currentKey = widget.part.attachment?.key;
      if (update.attachmentKey == currentKey && update.localPath != null) {
        if (mounted) {
          setState(() {
            _localPath = update.localPath;
            _loading = false;
            _error = null;
          });
        }
      }
    });
  }

  Future<void> _load() async {
    final attachment = widget.part.attachment;
    if (attachment == null) {
      setState(() {
        _loading = false;
        _error = '附件不存在';
      });
      return;
    }

    // 记录加载开始时的 key，用于检测 widget 是否被复用
    final loadingKey = attachment.key;

    if (hasReadableLocalFile(_localPath)) {
      if (widget.part.attachment?.key != loadingKey) return;
      if (_loading) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
      );
      if (!mounted) return;
      // 关键：检查 key 是否仍然匹配，防止异步竞态导致图片错乱
      // 如果 widget 已被复用显示其他图片，丢弃旧的加载结果
      if (widget.part.attachment?.key != loadingKey) return;
      setState(() {
        _localPath = path;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      // 同样检查 key 匹配
      if (widget.part.attachment?.key != loadingKey) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.part.attachment;
    final size = _resolveMediaDisplaySize(
      attachment?.width,
      attachment?.height,
    );

    // 默认占位（骨架屏）
    final skeletonPlaceHolder = Skeleton(
      width: size.width,
      height: size.height,
      borderRadius: 10,
    );

    if (_loading) {
      return skeletonPlaceHolder;
    }

    if (_error != null) {
      return Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: GestureDetector(
          onTap: _load,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 28),
              SizedBox(height: 6),
              Text('加载失败', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_localPath != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width,
          maxHeight: size.height,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // 使用 frameBuilder 实现平滑渐现
              Image.file(
                File(_localPath!),
                width: size.width,
                height: size.height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    skeletonPlaceHolder,
              ),
              // 点击预览层
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _previewImage(context),
                    highlightColor: Colors.black.withValues(alpha: 0.1),
                    splashColor: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
              // 上传进度遮罩
              if (attachment?.uploadProgress != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: attachment!.uploadProgress,
                          strokeWidth: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // 时间戳角标
              Positioned(
                right: 8,
                bottom: 8,
                child: _MediaTimeBadge(
                  message: widget.message,
                  isSelf: widget.isSelf,
                  onRetry: widget.onRetry,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return skeletonPlaceHolder;
  }

  Future<void> _previewImage(BuildContext context) async {
    if (_localPath == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withValues(alpha: 0.9),
            alignment: Alignment.center,
            child: InteractiveViewer(child: Image.file(File(_localPath!))),
          ),
        );
      },
    );
  }
}

/// 语音消息专用组件
class _AudioMessageTile extends StatefulWidget {
  const _AudioMessageTile({
    required this.message,
    required this.part,
    required this.isSelf,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;

  @override
  State<_AudioMessageTile> createState() => _AudioMessageTileState();
}

class _AudioMessageTileState extends State<_AudioMessageTile>
    with SingleTickerProviderStateMixin {
  String? _localPath;
  bool _loading = false;
  bool _isPlaying = false;
  double _playProgress = 0.0; // 播放进度 0-1
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _progressSubscription;
  late final AnimationController _animationController;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;

    // 创建动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // 150ms 平滑过渡
    );

    // 创建动画对象，初始值为 0
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playProgress = 0.0;
        });
        // 动画回退到 0
        _animationController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
        );
      }
    });

    // 监听播放进度
    _progressSubscription = _audioPlayer.onPositionChanged.listen((
      position,
    ) async {
      final duration = await _audioPlayer.getDuration();
      if (duration != null && duration.inMilliseconds > 0 && mounted) {
        final newProgress = position.inMilliseconds / duration.inMilliseconds;
        if ((newProgress - _playProgress).abs() > 0.01) {
          // 只有当进度变化超过 1% 时才更新，减少频繁重绘
          setState(() {
            _playProgress = newProgress;
          });
          // 直接让控制器从当前值动画到新进度
          _animationController.animateTo(
            newProgress,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AudioMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAttachment = oldWidget.part.attachment;
    final newAttachment = widget.part.attachment;
    if (oldAttachment?.key != newAttachment?.key ||
        oldAttachment?.localPath != newAttachment?.localPath) {
      _localPath = newAttachment?.localPath;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final attachment = widget.part.attachment;
    if (attachment == null) return;
    if (_loading || attachment.uploadProgress != null) return;

    // 如果有本地文件，直接播放
    if (_localPath != null && _localPath!.isNotEmpty) {
      final file = File(_localPath!);
      if (await file.exists()) {
        await _togglePlay();
        return;
      }
    }

    // 否则先下载
    setState(() {
      _loading = true;
    });

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
      );
      if (!mounted) return;
      _localPath = path;
      if (path != null && path.isNotEmpty) {
        await _togglePlay();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('下载语音失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_localPath != null) {
        await _audioPlayer.play(DeviceFileSource(_localPath!));
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '0:00';
    final seconds = (durationMs / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.part.attachment;
    final durationText = _formatDuration(attachment?.durationMs);
    final hasLocalFile = _localPath != null && _localPath!.isNotEmpty;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelf
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放/暂停/下载按钮
            if (_loading)
              const SizedBox(
                width: 32,
                height: 32,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (attachment?.uploadProgress != null)
              SizedBox(
                width: 32,
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    value: attachment!.uploadProgress,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isSelf
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasLocalFile
                      ? (_isPlaying ? Icons.pause : Icons.play_arrow)
                      : Icons.arrow_circle_down,
                  size: 18,
                  color: widget.isSelf ? Colors.white : AppColors.primary,
                ),
              ),
            const SizedBox(width: 10),
            // 波形/进度条
            Expanded(
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: widget.isSelf
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _WaveformPainter(
                        progress: _progressAnimation.value,
                        color: widget.isSelf ? Colors.white : AppColors.primary,
                        backgroundColor: widget.isSelf
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        isPlaying: _isPlaying,
                        animation: _progressAnimation,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 时长
            Text(
              durationText,
              style: TextStyle(
                fontSize: 12,
                color: widget.isSelf ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentFileTile extends StatefulWidget {
  const _AttachmentFileTile({
    required this.message,
    required this.part,
    required this.isSelf,
    required this.icon,
    required this.fallbackLabel,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;
  final IconData icon;
  final String fallbackLabel;

  @override
  State<_AttachmentFileTile> createState() => _AttachmentFileTileState();
}

class _AttachmentFileTileState extends State<_AttachmentFileTile> {
  String? _localPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;
  }

  @override
  void didUpdateWidget(covariant _AttachmentFileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当附件 key 或 localPath 变化时更新状态
    final oldAttachment = oldWidget.part.attachment;
    final newAttachment = widget.part.attachment;
    if (oldAttachment?.key != newAttachment?.key ||
        oldAttachment?.localPath != newAttachment?.localPath) {
      _localPath = newAttachment?.localPath;
      _loading = false;
    }
  }

  Future<void> _handleTap() async {
    final attachment = widget.part.attachment;
    if (attachment == null) {
      return;
    }

    if (_loading || attachment.uploadProgress != null) return;

    setState(() {
      _loading = true;
    });

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
        forceDownload: true,
      );
      if (!mounted) return;
      _localPath = path;
      if (path != null && path.isNotEmpty) {
        if (widget.part.type == MessagePartType.video) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoPreviewPage(
                path: path,
                title: attachment.name?.trim().isNotEmpty == true
                    ? attachment.name!.trim()
                    : '视频',
              ),
            ),
          );
          return;
        }
        await OpenFilex.open(path);
      } else {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('文件保存成功')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('打开文件失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.part.attachment;
    final name = attachment?.name ?? widget.fallbackLabel;
    final sizeText = _formatFileSize(attachment?.size);
    // 检查本地文件是否存在
    final hasLocalFile = _localPath != null && _localPath!.isNotEmpty;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isSelf
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSelf
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: widget.isSelf ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelf
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sizeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isSelf
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (attachment?.uploadProgress != null)
              // 上传中显示进度
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: attachment!.uploadProgress,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                // 有本地文件显示打开/播放图标，否则显示下载图标
                hasLocalFile ? Icons.open_in_new : Icons.arrow_circle_down,
                size: 22,
                color: widget.isSelf ? Colors.white : AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

Size _resolveMediaDisplaySize(int? width, int? height) {
  const double maxDimension = 220;
  const double minDimension = 120;

  if (width == null || height == null || width <= 0 || height <= 0) {
    return const Size(180, 180);
  }

  var w = width.toDouble();
  var h = height.toDouble();
  final ratio = w / h;

  if (w >= h) {
    w = maxDimension;
    h = maxDimension / ratio;
    if (h < minDimension) {
      h = minDimension;
      w = minDimension * ratio;
    }
  } else {
    h = maxDimension;
    w = maxDimension * ratio;
    if (w < minDimension) {
      w = minDimension;
      h = minDimension / ratio;
    }
  }

  return Size(w, h);
}

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return '--';
  }
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

class _WaveformPainter extends CustomPainter {
  final double progress; // 0-1
  final Color color;
  final Color backgroundColor; // 背景波形颜色
  final bool isPlaying; // 是否正在播放
  final Animation<double>? animation; // 用于平滑过渡

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.isPlaying = false,
    this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 20; // 波形条数量
    final barWidth = size.width / barCount * 0.6;
    final barSpacing = size.width / barCount * 0.4;

    // 使用动画值实现平滑过渡
    final animatedProgress = animation?.value ?? progress;

    // 先绘制背景波形（全部显示）
    _drawWaveformBars(
      canvas,
      size,
      barCount,
      barWidth,
      barSpacing,
      backgroundColor,
      fullWidth: true,
    );

    // 再绘制播放进度波形（只显示进度部分）
    _drawWaveformBars(
      canvas,
      size,
      barCount,
      barWidth,
      barSpacing,
      color,
      progress: animatedProgress,
    );

    // 如果正在播放，添加闪烁效果
    if (isPlaying && animatedProgress < 1.0) {
      _drawPlayingIndicator(canvas, size, barCount, barWidth, barSpacing);
    }
  }

  void _drawWaveformBars(
    Canvas canvas,
    Size size,
    int barCount,
    double barWidth,
    double barSpacing,
    Color color, {
    double progress = 1.0,
    bool fullWidth = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + barSpacing);

      // 计算波形高度
      final height = _calculateBarHeight(i, barCount, size);

      // 绘制背景波形时全部显示，绘制进度波形时只显示进度部分
      final shouldDraw = fullWidth || (x + barWidth <= size.width * progress);

      if (shouldDraw) {
        // 计算进度边缘的淡入效果
        if (!fullWidth && progress < 1.0) {
          final progressX = size.width * progress;
          if (x < progressX && x + barWidth > progressX) {
            // 部分可见的条（进度边缘）
            final edgePosition = (progressX - x) / barWidth;
            final edgePaint = Paint()
              ..color = color.withValues(alpha: edgePosition.clamp(0.0, 1.0))
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                Rect.fromLTWH(
                  x,
                  (size.height - height) / 2,
                  barWidth * edgePosition,
                  height,
                ),
                topLeft: const Radius.circular(2),
                topRight: const Radius.circular(2),
                bottomLeft: const Radius.circular(2),
                bottomRight: const Radius.circular(2),
              ),
              edgePaint,
            );
            continue;
          }
        }

        // 正常绘制
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, (size.height - height) / 2, barWidth, height),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
            bottomLeft: const Radius.circular(2),
            bottomRight: const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  /// 计算第 i 个波形条的高度
  double _calculateBarHeight(int index, int total, Size size) {
    // 多频率叠加生成更自然的波形
    // 基础波形（低频）
    final baseWave = (math.sin(index * 0.6) * 0.25 + 0.25);
    // 谐波（增加变化）
    final harmonic = (math.sin(index * 1.2 + 0.5) * 0.15 + 0.15);
    // 随机扰动（模拟音频的随机性）
    final noise = (math.sin(index * 2.3 + 1.7) * 0.08 + 0.08);
    // 组合波形
    final combined = baseWave + harmonic + noise;

    // 归一化到 0.2-0.9 范围
    final normalizedHeight = combined.clamp(0.2, 0.9);
    return size.height * normalizedHeight;
  }

  /// 绘制播放指示器（闪烁效果）
  void _drawPlayingIndicator(
    Canvas canvas,
    Size size,
    int barCount,
    double barWidth,
    double barSpacing,
  ) {
    // 使用脉冲动画效果
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final pulse = (math.sin(time * 4) * 0.3 + 0.7).clamp(0.4, 1.0);

    // 在当前播放位置绘制高亮指示器
    final currentX = size.width * (animation?.value ?? 0);

    if (currentX < size.width) {
      final indicatorPaint = Paint()
        ..color = color.withValues(alpha: 0.6 * pulse)
        ..style = PaintingStyle.fill;

      // 绘制一个小的指示器
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(currentX - 2, size.height * 0.1, 4, size.height * 0.8),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
          bottomLeft: const Radius.circular(2),
          bottomRight: const Radius.circular(2),
        ),
        indicatorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animation?.value != animation?.value;
  }
}

/// 多图网格布局组件

class _MediaGridView extends StatelessWidget {
  const _MediaGridView({
    required this.message,
    required this.mediaParts,
    required this.isSelf,
    required this.onRetry,
    this.hasText = false,
  });

  final Message message;
  final List<MessagePart> mediaParts;
  final bool isSelf;
  final VoidCallback onRetry;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    if (mediaParts.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = mediaParts.length;
    final gridChildren = <Widget>[];

    for (int i = 0; i < count; i++) {
      final part = mediaParts[i];
      gridChildren.add(
        _MediaGridItem(
          message: message,
          part: part,
          isSelf: isSelf,
          index: i,
          total: count,
        ),
      );
    }

    // 根据图片数量选择布局
    Widget grid;
    if (count == 1) {
      grid = gridChildren.first;
    } else if (count == 2) {
      grid = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: gridChildren[0]),
          const SizedBox(width: 2),
          Expanded(child: gridChildren[1]),
        ],
      );
    } else if (count == 3) {
      grid = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          gridChildren[0],
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: gridChildren[1]),
              const SizedBox(width: 2),
              Expanded(child: gridChildren[2]),
            ],
          ),
        ],
      );
    } else {
      // 4 张或更多：2x2 网格
      final rows = <Widget>[];
      for (int i = 0; i < count; i += 2) {
        final rowChildren = <Widget>[Expanded(child: gridChildren[i])];
        if (i + 1 < count) {
          rowChildren.add(const SizedBox(width: 2));
          rowChildren.add(Expanded(child: gridChildren[i + 1]));
        }
        if (rows.isNotEmpty) {
          rows.add(const SizedBox(height: 2));
        }
        rows.add(Row(mainAxisSize: MainAxisSize.min, children: rowChildren));
      }
      grid = Column(mainAxisSize: MainAxisSize.min, children: rows);
    }

    // 如果有文字，媒体网格底部圆角需要去掉
    final borderRadius = hasText
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          )
        : BorderRadius.circular(10);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          grid,
          // 如果没有文字，在媒体右下角显示时间戳
          if (!hasText)
            Positioned(
              right: 8,
              bottom: 8,
              child: _MediaTimeBadge(
                message: message,
                isSelf: isSelf,
                onRetry: onRetry,
              ),
            ),
        ],
      ),
    );
  }
}

/// 媒体网格中的单个项
class _MediaGridItem extends StatefulWidget {
  const _MediaGridItem({
    required this.message,
    required this.part,
    required this.isSelf,
    required this.index,
    required this.total,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;
  final int index;
  final int total;

  @override
  State<_MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<_MediaGridItem> {
  String? _localPath;
  bool _loading = true;
  StreamSubscription<AttachmentPathUpdate>? _subscription;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;
    _subscribeToUpdates();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.attachment?.key != widget.part.attachment?.key) {
      _localPath = widget.part.attachment?.localPath;
      _loading = true;
      // 重新订阅新的 key
      _subscription?.cancel();
      _subscribeToUpdates();
      _load();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToUpdates() {
    final key = widget.part.attachment?.key;
    if (key == null) return;

    _subscription = MessageService.instance.attachmentPathUpdates.listen((
      update,
    ) {
      // 动态获取当前的 key，避免闭包捕获问题
      final currentKey = widget.part.attachment?.key;
      if (update.attachmentKey == currentKey && update.localPath != null) {
        if (mounted) {
          setState(() {
            _localPath = update.localPath;
            _loading = false;
          });
        }
      }
    });
  }

  Future<void> _load() async {
    final attachment = widget.part.attachment;
    if (attachment == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 记录加载开始时的 key，用于检测 widget 是否被复用
    final loadingKey = attachment.key;

    if (_localPath != null && _localPath!.isNotEmpty) {
      final file = File(_localPath!);
      if (await file.exists()) {
        // 检查 key 是否仍然匹配（widget 可能已被复用）
        if (widget.part.attachment?.key != loadingKey) return;
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
      );
      if (!mounted) return;
      // 关键：检查 key 是否仍然匹配，防止异步竞态导致图片错乱
      // 如果 widget 已被复用显示其他图片，丢弃旧的加载结果
      if (widget.part.attachment?.key != loadingKey) return;
      setState(() {
        _localPath = path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 同样检查 key 匹配
      if (widget.part.attachment?.key != loadingKey) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.part.type == MessagePartType.video;

    // 计算高度：单图较大，多图较小
    final height = widget.total == 1 ? 200.0 : 140.0;

    if (_loading) {
      return SizedBox(height: height, child: const Skeleton(borderRadius: 0));
    }

    if (_localPath == null) {
      return Container(
        height: height,
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(
            isVideo ? Icons.movie : Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      );
    }

    Widget content = Image.file(
      File(_localPath!),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(
            isVideo ? Icons.movie : Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      ),
    );

    // 视频叠加播放按钮
    if (isVideo) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          content,
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
          ),
        ],
      );
    }

    return GestureDetector(onTap: () => _preview(context), child: content);
  }

  Future<void> _preview(BuildContext context) async {
    final isVideo = widget.part.type == MessagePartType.video;
    if (isVideo) {
      final attachment = widget.part.attachment;
      if (attachment == null) return;

      String? path = _localPath;
      if (path == null || path.isEmpty || !(await File(path).exists())) {
        try {
          path = await MessageService.instance.ensureAttachmentCached(
            roomId: widget.message.roomId,
            message: widget.message,
            part: widget.part,
            forceDownload: true,
          );
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text('加载视频失败：$error')));
          return;
        }
      }

      if (!context.mounted) return;
      if (path == null || path.isEmpty) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPreviewPage(
            path: path!,
            title: attachment.name?.trim().isNotEmpty == true
                ? attachment.name!.trim()
                : '视频',
          ),
        ),
      );
      return;
    }

    if (_localPath == null) return;

    // 图片预览
    await showDialog<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withValues(alpha: 0.9),
            alignment: Alignment.center,
            child: InteractiveViewer(child: Image.file(File(_localPath!))),
          ),
        );
      },
    );
  }
}

/// 媒体时间戳角标
class _MediaTimeBadge extends StatelessWidget {
  const _MediaTimeBadge({
    required this.message,
    required this.isSelf,
    required this.onRetry,
  });

  final Message message;
  final bool isSelf;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(message.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time, style: const TextStyle(fontSize: 11, color: Colors.white)),
          if (isSelf) ...[
            const SizedBox(width: 4),
            MessageDeliveryStatus(
              status: message.status,
              color: Colors.white,
              readColor: const Color(0xFF40A9FF),
              onRetry: onRetry,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 混合消息中的文字区域（带内嵌时间）
class _MixedTextWithTime extends StatelessWidget {
  const _MixedTextWithTime({
    required this.text,
    required this.message,
    required this.isSelf,
    required this.onRetry,
    this.hasMediaAbove = false,
  });

  final String text;
  final Message message;
  final bool isSelf;
  final VoidCallback onRetry;
  final bool hasMediaAbove;

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(message.timestamp);

    // 如果上方有媒体，顶部圆角去掉
    final borderRadius = hasMediaAbove
        ? const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          )
        : BorderRadius.circular(10);

    final bgColor = isSelf ? AppColors.primary : Colors.white;
    final textColor = isSelf ? Colors.white : AppColors.textPrimary;
    final timeColor = isSelf
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textQuaternary;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Stack(
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
          ),
          Positioned(
            right: 0,
            bottom: -14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(fontSize: 11, color: timeColor)),
                if (isSelf) ...[
                  const SizedBox(width: 4),
                  MessageDeliveryStatus(
                    status: message.status,
                    color: timeColor,
                    readColor: const Color(0xFF40A9FF),
                    onRetry: onRetry,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 回到底部浮动按钮
