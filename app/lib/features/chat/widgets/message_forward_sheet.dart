import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/avatar_color_utils.dart';
import '../../../core/widgets/im_search_field.dart';
import '../models/chat_model.dart';

class MessageForwardSheet extends StatefulWidget {
  const MessageForwardSheet({
    super.key,
    required this.chats,
    required this.previewText,
    this.excludedRoomId,
  });

  final List<Chat> chats;
  final String previewText;
  final String? excludedRoomId;

  @override
  State<MessageForwardSheet> createState() => _MessageForwardSheetState();
}

class _MessageForwardSheetState extends State<MessageForwardSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String _keyword = '';

  List<Chat> get _availableChats => widget.chats
      .where((chat) => chat.roomId != widget.excludedRoomId)
      .toList(growable: false);

  List<Chat> get _filteredChats {
    if (_keyword.isEmpty) return _availableChats;
    return _availableChats
        .where((chat) => chat.name.toLowerCase().contains(_keyword))
        .toList(growable: false);
  }

  List<Chat> get _selectedChats => _availableChats
      .where((chat) => _selectedIds.contains(chat.id))
      .toList(growable: false);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(Chat chat) {
    setState(() {
      if (!_selectedIds.add(chat.id)) _selectedIds.remove(chat.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('转发消息', style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Text(
                        widget.previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ImSearchField(
                      controller: _searchController,
                      hintText: '搜索会话',
                      onChanged: (value) =>
                          setState(() => _keyword = value.trim().toLowerCase()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: _filteredChats.isEmpty
                    ? Center(
                        child: Text(
                          _availableChats.isEmpty ? '暂无可转发的会话' : '未找到匹配的会话',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final selected = _selectedIds.contains(chat.id);
                          return CheckboxListTile(
                            key: ValueKey('forward-target-${chat.id}'),
                            value: selected,
                            onChanged: (_) => _toggle(chat),
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: _ChatAvatar(chat: chat),
                            title: Text(
                              chat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              chat.type == ChatType.group ? '群聊' : '单聊',
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selectedChats),
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: Text('转发给 ${_selectedIds.length} 个会话'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final avatar = chat.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: avatar.startsWith('http')
            ? NetworkImage(avatar)
            : AssetImage(avatar) as ImageProvider,
      );
    }
    return CircleAvatar(
      backgroundColor: AvatarColorUtils.generateBackgroundColor(chat.roomId),
      child: Text(
        chat.name.isEmpty ? '?' : AvatarColorUtils.getInitial(chat.name),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
