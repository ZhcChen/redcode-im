part of '../chat_detail_page_v2.dart';

class _QuotePreviewBar extends StatelessWidget {
  const _QuotePreviewBar({
    super.key,
    required this.message,
    required this.onClose,
    this.onTap,
  });

  final Message message;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quoted = QuotedMessage.fromMessage(message);
    final previewText = '${quoted.displaySenderName}: ${quoted.previewText}';
    final textWidget = Text(
      previewText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );

    final content = onTap == null
        ? textWidget
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: textWidget,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionMember {
  _MentionMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  }) : usernameLower = username.toLowerCase(),
       displayNameLower = displayName.toLowerCase();

  final String userId;
  final String username;
  final String usernameLower;
  final String displayName;
  final String displayNameLower;
  final String? avatarUrl;

  String get displayNameAvatar {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return AvatarColorUtils.getInitial(trimmed);
  }
}

class _MentionTile extends StatelessWidget {
  const _MentionTile({
    required this.title,
    required this.subtitle,
    required this.avatarText,
    required this.onTap,
    this.avatarUrl,
  });

  final String title;
  final String subtitle;
  final String avatarText;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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

  Widget _buildAvatar() {
    final bg = AvatarColorUtils.generateBackgroundColor(title);
    final child = avatarUrl != null && avatarUrl!.trim().isNotEmpty
        ? ClipOval(
            child: Image.network(
              avatarUrl!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackAvatar(bg),
            ),
          )
        : _fallbackAvatar(bg);

    return SizedBox(width: 36, height: 36, child: child);
  }

  Widget _fallbackAvatar(Color bg) {
    return Container(
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        avatarText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 聊天输入框组件
class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSendMessage,
    required this.onToggleVoice,
    required this.onToggleEmoji,
    required this.onToggleMore,
    required this.showEmojiPanel,
    required this.showMorePanel,
    this.isDisabled = false,
    this.disabledHint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSendMessage;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleMore;
  final bool showEmojiPanel;
  final bool showMorePanel;
  final bool isDisabled;
  final String? disabledHint;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  @override
  void initState() {
    super.initState();
    // 监听文本变化，触发重建以更新输入框高度
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // 文本变化时触发重建，确保输入框高度能够更新
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 语音按钮
        _buildVoiceButton(),

        SizedBox(width: density.scale(8)),

        // 文本输入框 - 支持自动扩展高度，最多显示 6 行
        Expanded(child: _buildTextInput(context)),

        SizedBox(width: density.scale(8)),

        // 表情按钮
        _buildEmojiButton(),

        SizedBox(width: density.scale(4)),

        // 发送/更多按钮
        _buildSendOrMoreButton(),
      ],
    );
  }

  Widget _buildVoiceButton() {
    return _IconButton(
      buttonKey: const ValueKey('chat-input-voice-button'),
      semanticLabel: '语音',
      icon: AppAssets.iconVoice,
      onTap: widget.onToggleVoice,
    );
  }

  Widget _buildTextInput(BuildContext context) {
    // 手动根据文本内容计算需要的高度，保证最多显示约 6 行，
    // 配合外层 AnimatedSize 做平滑过渡，减轻文字跳动感。
    const baseFontSize = 15.0;
    const maxVisibleLines = 6;
    const lineHeightMultiplier = 1.3;

    final density = context.phoneDensity;
    final mediaQuery = MediaQuery.maybeOf(context);
    final textScaler = mediaQuery?.textScaler ?? const TextScaler.linear(1.0);
    final scaledFontSize = textScaler.scale(baseFontSize);
    final horizontalPadding = density.scale(12);
    final verticalPadding = density.scale(10);
    final inputRadius = density.scale(8);
    final textStyle = TextStyle(
      fontSize: baseFontSize,
      height: lineHeightMultiplier,
      color: AppColors.textPrimary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawText = widget.controller.text;
        // 空文本时也要预留一行高度
        final text = rawText.isEmpty ? ' ' : rawText;

        final span = TextSpan(text: text, style: textStyle);
        final painter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          maxLines: maxVisibleLines,
          textScaler: textScaler,
        );

        // 减去左右 contentPadding 的宽度，避免低估行数
        var maxWidth = constraints.maxWidth - horizontalPadding * 2;
        if (maxWidth <= 0) {
          maxWidth = constraints.maxWidth;
        }
        painter.layout(maxWidth: maxWidth);

        final metrics = painter.computeLineMetrics();
        double lineHeight;
        if (metrics.isNotEmpty) {
          lineHeight = metrics.first.height;
        } else {
          lineHeight = scaledFontSize * lineHeightMultiplier;
        }
        final int lineCount = metrics.isEmpty
            ? 1
            : metrics.length.clamp(1, maxVisibleLines);
        final bool isSingleLine = lineCount == 1;
        final inputTextStyle = TextStyle(
          fontSize: baseFontSize,
          height: lineHeightMultiplier,
          color: widget.isDisabled
              ? AppColors.textTertiary
              : AppColors.textPrimary,
        );
        final hintTextStyle = TextStyle(
          fontSize: baseFontSize,
          height: lineHeightMultiplier,
          color: AppColors.textTertiary,
        );
        final strutStyle = StrutStyle(
          fontSize: baseFontSize,
          height: lineHeightMultiplier,
          forceStrutHeight: true,
        );

        final minHeight = lineHeight + verticalPadding * 2;
        final maxHeight = lineHeight * maxVisibleLines + verticalPadding * 2;
        final neededHeight = painter.height + verticalPadding * 2;
        final clampedHeight = neededHeight
            .clamp(minHeight, maxHeight)
            .toDouble();

        return ConstrainedBox(
          key: const ValueKey('chat-input-text-container'),
          constraints: BoxConstraints(
            minHeight: clampedHeight,
            maxHeight: clampedHeight,
          ),
          child: TextField(
            key: const ValueKey('chat-input-text-field'),
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: !widget.isDisabled,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            // 单行时使用垂直居中，多行时顶部对齐
            textAlignVertical: isSingleLine
                ? TextAlignVertical.center
                : TextAlignVertical.top,
            minLines: 1,
            maxLines: maxVisibleLines,
            cursorHeight: lineHeight,
            strutStyle: strutStyle,
            style: inputTextStyle,
            decoration: InputDecoration(
              // 覆盖全局 InputDecorationTheme 的固定高度约束，避免破坏聊天输入框的动态高度与单行垂直居中。
              constraints: const BoxConstraints(minHeight: 0),
              contentPadding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              filled: true,
              fillColor: widget.isDisabled
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFFEFEFF0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputRadius),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputRadius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(inputRadius),
                borderSide: BorderSide.none,
              ),
              hintText: widget.isDisabled
                  ? (widget.disabledHint ?? '已禁言')
                  : '发送消息...',
              hintStyle: hintTextStyle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiButton() {
    return _IconButton(
      buttonKey: const ValueKey('chat-input-emoji-button'),
      semanticLabel: '表情',
      icon: AppAssets.iconEmoji,
      isActive: widget.showEmojiPanel,
      onTap: widget.onToggleEmoji,
    );
  }

  Widget _buildSendOrMoreButton() {
    return Selector<ChatProvider, bool>(
      selector: (_, provider) => provider.isSending,
      builder: (context, isSending, child) {
        final hasText = widget.controller.text.trim().isNotEmpty;

        if (hasText) {
          return _buildSendButton(isSending);
        }

        return _buildMoreButton();
      },
    );
  }

  Widget _buildSendButton(bool isSending) {
    final density = context.phoneDensity;
    final buttonSize = density.scale(36);
    final buttonRadius = density.scale(18);
    final loadingSize = density.scale(20);
    return Semantics(
      button: true,
      label: '发送',
      child: Material(
        key: const ValueKey('chat-input-send-button'),
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonRadius),
          onTap: isSending ? null : widget.onSendMessage,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            alignment: Alignment.center,
            child: isSending
                ? SizedBox(
                    width: loadingSize,
                    height: loadingSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: density.scale(20),
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return _IconButton(
      buttonKey: const ValueKey('chat-input-more-button'),
      semanticLabel: '更多功能',
      icon: AppAssets.iconAdd,
      isActive: widget.showMorePanel,
      onTap: widget.onToggleMore,
    );
  }
}

/// 图标按钮
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.isActive = false,
    this.buttonKey,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool isActive;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    final buttonSize = density.scale(36);
    final buttonRadius = density.scale(18);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        key: buttonKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonRadius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              icon,
              width: density.scale(24),
              height: density.scale(24),
              colorFilter: ColorFilter.mode(
                isActive ? AppColors.primary : AppColors.iconSecondary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表情面板
class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onEmojiSelected});

  final Function(String) onEmojiSelected;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  int _selectedTabIndex = 1; // 默认选中 Emoji tab
  List<EmojiPack> _userPacks = [];
  bool _loadingPacks = false;
  late final EmojiItemService _emojiService = EmojiItemService();

  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  List<EmojiPack> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchTimer;

  // 贴纸包相关
  final Map<String, List<EmojiPack>> _suitePacksCache = {};
  final Map<String, bool> _loadingSuitePacks = {};

  static const List<String> emojis = desktopEmojiList;

  @override
  void initState() {
    super.initState();
    _loadUserPacks();
    _searchController.addListener(_handleSearchInput);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchInput);
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _handleSearchInput() {
    _searchTimer?.cancel();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(keyword);
    });
  }

  Future<void> _performSearch(String keyword) async {
    setState(() {
      _searchLoading = true;
    });

    try {
      final service = EmojiPackService();
      final results = await service.searchPacks(keyword);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('搜索贴纸失败: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPacks() async {
    setState(() {
      _loadingPacks = true;
    });
    try {
      final service = EmojiPackService();
      final packs = await service.getUserPacks();
      debugPrint('_loadUserPacks: 加载到 ${packs.length} 个贴纸');
      for (final pack in packs) {
        debugPrint(
          '  贴纸: id=${pack.id}, name=${pack.name}, packType=${pack.packType}, items数量=${pack.items.length}',
        );
      }
      setState(() {
        _userPacks = packs;
      });
    } catch (e) {
      // 静默失败，不影响表情面板显示
      debugPrint('加载贴纸失败: $e');
    } finally {
      setState(() {
        _loadingPacks = false;
      });
    }
  }

  List<_TabItem> _buildTabs() {
    final tabs = <_TabItem>[];

    // 搜索 tab
    tabs.add(_TabItem(type: _TabType.search, icon: 'search', label: '搜索'));

    // Emoji tab
    tabs.add(_TabItem(type: _TabType.emoji, icon: 'emoji', label: 'Emoji'));

    // 自定义表情 tab
    tabs.add(_TabItem(type: _TabType.custom, icon: 'custom', label: '自定义'));

    // 只添加贴纸包（packType === 1）作为动态 tab
    for (final pack in _userPacks) {
      if (pack.packType == 1) {
        tabs.add(
          _TabItem(
            type: _TabType.pack,
            icon: pack.iconUrl,
            label: pack.name,
            pack: pack,
          ),
        );
      }
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();

    return Container(
      key: const ValueKey('chat-emoji-panel'),
      height: 320,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          // Tab 切换栏
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ...tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTabIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: EdgeInsets.only(
                        right: index < tabs.length - 1 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(child: _buildTabIcon(tab.icon, isSelected)),
                    ),
                  );
                }),
              ],
            ),
          ),
          // 内容区域
          Expanded(child: _buildContent(tabs[_selectedTabIndex])),
        ],
      ),
    );
  }

  Widget _buildTabIcon(String? icon, bool isSelected) {
    if (icon == null) return const SizedBox.shrink();

    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    // 特殊图标类型
    if (icon == 'search') {
      return Icon(Icons.search, size: 20, color: color);
    } else if (icon == 'emoji') {
      return Icon(Icons.emoji_emotions_outlined, size: 20, color: color);
    } else if (icon == 'custom') {
      return Icon(Icons.favorite_outline, size: 20, color: color);
    }

    // 网络图片
    if (icon.startsWith('http')) {
      return Image.network(
        icon,
        width: 20,
        height: 20,
        errorBuilder: (_, __, ___) => Icon(Icons.image, size: 20, color: color),
      );
    }

    // Emoji 字符
    return Text(icon, style: const TextStyle(fontSize: 18));
  }

  Widget _buildContent(_TabItem tab) {
    if (_loadingPacks && tab.type == _TabType.custom) {
      return const Center(child: CircularProgressIndicator());
    }

    // 切换到贴纸包 tab 时，如果缓存中没有数据，主动加载
    if (tab.type == _TabType.pack && tab.pack != null) {
      final suiteId = tab.pack!.id;
      if (tab.pack!.packType == 1 &&
          !_suitePacksCache.containsKey(suiteId) &&
          (_loadingSuitePacks[suiteId] != true)) {
        // 异步加载，不阻塞 UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadSuitePacks(suiteId);
        });
      }
    }

    // 使用 key 确保在数据变化时重新构建内容
    final contentKey = tab.type == _TabType.custom
        ? ValueKey('custom_content_${_userPacks.length}')
        : (tab.type == _TabType.pack && tab.pack != null
              ? ValueKey('pack_content_${tab.pack!.id}')
              : null);

    Widget content;
    switch (tab.type) {
      case _TabType.search:
        content = _buildSearchTab();
        break;
      case _TabType.emoji:
        content = _buildEmojiGrid();
        break;
      case _TabType.custom:
        content = _buildCustomEmojiGrid();
        break;
      case _TabType.pack:
        content = _buildPackGrid(tab.pack!);
        break;
    }

    return contentKey != null
        ? KeyedSubtree(key: contentKey, child: content)
        : content;
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索贴纸或贴纸包...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _searchLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchController.text.trim().isEmpty
              ? const Center(
                  child: Text(
                    '输入关键词搜索贴纸或贴纸包',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    '未找到相关贴纸',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final pack = _searchResults[index];
                    return ListTile(
                      leading: pack.iconUrl != null
                          ? Image.network(
                              pack.iconUrl!,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image, size: 40),
                            )
                          : const Icon(Icons.image, size: 40),
                      title: Text(pack.name),
                      subtitle: pack.description != null
                          ? Text(pack.description!)
                          : null,
                      trailing: Text(
                        pack.packType == 1 ? '贴纸包' : '贴纸',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () async {
                        // 显示确认对话框
                        final confirmed = await TipDialog.showConfirm(
                          context,
                          title: pack.packType == 1 ? '添加贴纸包' : '添加贴纸',
                          content: pack.packType == 1
                              ? '确定要添加贴纸包"${pack.name}"吗？这将添加贴纸包下的所有贴纸。'
                              : '确定要添加贴纸"${pack.name}"到自定义表情吗？',
                          confirmText: '确定',
                          cancelText: '取消',
                        );

                        if (confirmed != true) return;

                        try {
                          final service = EmojiPackService();
                          if (pack.packType == 1) {
                            // 贴纸包：使用 addUserSuite
                            final result = await service.addUserSuite(pack.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('成功添加 ${result['count']} 个贴纸'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // 单个贴纸：使用 addUserPack
                            await service.addUserPack(pack.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('添加成功'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }

                          // 重新加载用户贴纸
                          await _loadUserPacks();

                          // 如果是贴纸包，清除贴纸包缓存以便重新加载
                          if (pack.packType == 1) {
                            _suitePacksCache.remove(pack.id);
                          }

                          // 等待状态更新完成
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );

                          // 切换到对应的 tab
                          if (mounted) {
                            if (pack.packType == 1) {
                              // 贴纸包：切换到贴纸包 tab
                              // 需要等待 tabs 更新后再查找
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                              final tabs = _buildTabs();
                              final suiteIndex = tabs.indexWhere(
                                (t) =>
                                    t.type == _TabType.pack &&
                                    t.pack?.id == pack.id,
                              );
                              if (suiteIndex >= 0) {
                                setState(() {
                                  _selectedTabIndex = suiteIndex;
                                });
                              }
                            } else {
                              // 单个贴纸：切换到自定义 tab
                              final tabs = _buildTabs();
                              final customIndex = tabs.indexWhere(
                                (t) => t.type == _TabType.custom,
                              );
                              if (customIndex >= 0) {
                                // 强制刷新 UI
                                setState(() {
                                  _selectedTabIndex = customIndex;
                                  // 触发重新构建，确保 _userPacks 的变化被检测到
                                });
                                // 再次等待，确保 currentItems 计算完成
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                // 再次触发 setState 确保 UI 更新
                                if (mounted) {
                                  setState(() {});
                                }
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('添加贴纸失败: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is EmojiPackServiceException
                                      ? e.message
                                      : '添加失败，请重试',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onEmojiSelected(emojis[index]),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomEmojiGrid() {
    // 收集所有独立的单个贴纸（packType === 0）中的表情项
    // 排除贴纸包（packType === 1）
    final allItems = <EmojiItem>[];
    for (final pack in _userPacks) {
      if (pack.packType == 0) {
        allItems.addAll(pack.items);
      }
    }

    if (allItems.isEmpty) {
      return const Center(
        child: Text(
          '暂无自定义表情\n请在设置中添加贴纸',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // 使用 key 确保在数据变化时重新构建
    return GridView.builder(
      key: ValueKey('custom_emoji_${allItems.length}_${_userPacks.length}'),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        return _CachedEmojiItem(
          imageUrl: item.imageUrl,
          onTap: () => widget.onEmojiSelected(item.imageUrl),
          emojiService: _emojiService,
        );
      },
    );
  }

  Widget _buildPackGrid(EmojiPack pack) {
    if (pack.packType == 1) {
      // 贴纸包：显示贴纸包下所有子贴纸的 icon_url
      return _buildSuiteGrid(pack);
    } else {
      // 单个贴纸：显示 pack.items
      if (pack.items.isEmpty) {
        return const Center(
          child: Text(
            '此贴纸暂无表情',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: pack.items.length,
        itemBuilder: (context, index) {
          final item = pack.items[index];
          return _CachedEmojiItem(
            imageUrl: item.imageUrl,
            onTap: () => widget.onEmojiSelected(item.imageUrl),
            emojiService: _emojiService,
          );
        },
      );
    }
  }

  Widget _buildSuiteGrid(EmojiPack suitePack) {
    final suiteId = suitePack.id;
    final suitePacks = _suitePacksCache[suiteId];
    final isLoading = _loadingSuitePacks[suiteId] ?? false;

    // 如果缓存中没有且未在加载中，异步加载
    if (suitePacks == null && !isLoading) {
      _loadSuitePacks(suiteId);
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (suitePacks == null || suitePacks.isEmpty) {
      return const Center(
        child: Text(
          '该贴纸包暂无贴纸\n请先添加贴纸到贴纸包',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // 显示子贴纸的 icon_url
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: suitePacks.length,
      itemBuilder: (context, index) {
        final childPack = suitePacks[index];
        if (childPack.iconUrl == null || childPack.iconUrl!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _CachedEmojiItem(
          imageUrl: childPack.iconUrl!,
          onTap: () => widget.onEmojiSelected(childPack.iconUrl!),
          emojiService: _emojiService,
        );
      },
    );
  }

  Future<void> _loadSuitePacks(String suiteId) async {
    if (_suitePacksCache.containsKey(suiteId)) {
      debugPrint('贴纸包已缓存，跳过加载: $suiteId');
      return;
    }
    if (_loadingSuitePacks[suiteId] == true) {
      debugPrint('贴纸包正在加载中，跳过重复加载: $suiteId');
      return;
    }

    setState(() {
      _loadingSuitePacks[suiteId] = true;
    });

    try {
      debugPrint('开始加载贴纸包贴纸: $suiteId');
      final service = EmojiPackService();
      final suitePacks = await service.getSuitePacks(suiteId);
      debugPrint('贴纸包贴纸加载成功: $suiteId, 数量: ${suitePacks.length}');
      if (mounted) {
        setState(() {
          _suitePacksCache[suiteId] = suitePacks;
          _loadingSuitePacks[suiteId] = false;
        });
      }
    } catch (e) {
      debugPrint('加载贴纸包贴纸失败: $suiteId, 错误: $e');
      if (mounted) {
        setState(() {
          _suitePacksCache[suiteId] = [];
          _loadingSuitePacks[suiteId] = false;
        });
      }
    }
  }
}

enum _TabType { search, emoji, custom, pack }

class _TabItem {
  final _TabType type;
  final String? icon;
  final String label;
  final EmojiPack? pack;

  _TabItem({required this.type, this.icon, required this.label, this.pack});
}

/// 带缓存的表情项组件（支持 GIF）
class _CachedEmojiItem extends StatefulWidget {
  const _CachedEmojiItem({
    required this.imageUrl,
    required this.onTap,
    required this.emojiService,
  });

  final String imageUrl;
  final VoidCallback onTap;
  final EmojiItemService emojiService;

  @override
  State<_CachedEmojiItem> createState() => _CachedEmojiItemState();
}

class _CachedEmojiItemState extends State<_CachedEmojiItem> {
  String? _cachedPath;
  bool _loading = false;
  bool _error = false;

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
      final cachedPath = await widget.emojiService.loadAndCacheEmoji(
        widget.imageUrl,
      );
      if (mounted) {
        setState(() {
          _cachedPath = cachedPath;
          _loading = false;
        });
      }
    } catch (e) {
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_loading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.image, size: 24),
      );
    }

    // 优先使用缓存路径，如果缓存不存在则使用网络 URL
    // Flutter 的 Image 组件原生支持 GIF 动画
    if (_cachedPath != null) {
      return Image.file(
        File(_cachedPath!),
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (_, __, ___) {
          // 缓存文件损坏，尝试重新加载
          _loadEmoji();
          return Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => const Icon(Icons.image),
          );
        },
      );
    }

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) => const Icon(Icons.image),
    );
  }
}

/// 文本消息中的表情图片组件
class _MoreActionsPanel extends StatelessWidget {
  const _MoreActionsPanel({required this.onActionSelected});

  final Function(String) onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionItem(
            icon: Icons.photo,
            label: '相册',
            onTap: () => onActionSelected('album'),
          ),
          _ActionItem(
            icon: Icons.camera_alt,
            label: '拍摄',
            onTap: () => onActionSelected('camera'),
          ),
          _ActionItem(
            icon: Icons.folder,
            label: '文件',
            onTap: () => onActionSelected('file'),
          ),
        ],
      ),
    );
  }
}

/// 操作项
class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: AppColors.iconPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 波形绘制器
