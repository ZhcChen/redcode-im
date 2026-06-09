import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../contacts/models/friend_models.dart';

String friendDisplayName(FriendInfo friend) {
  final nickname = friend.user.nickname;
  if (nickname != null && nickname.trim().isNotEmpty) {
    return nickname;
  }
  return friend.user.username;
}

class FriendSelectionSheet extends StatefulWidget {
  const FriendSelectionSheet({
    super.key,
    required this.friends,
    required this.initialSelected,
    this.title = '选择群成员',
    this.searchHint = '搜索好友昵称或账号',
    this.emptyText = '暂无匹配的好友',
    this.confirmTextBuilder,
  });

  final List<FriendInfo> friends;
  final Set<String> initialSelected;
  final String title;
  final String searchHint;
  final String emptyText;
  final String Function(int count)? confirmTextBuilder;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<FriendInfo> friends,
    required Set<String> initialSelected,
    String title = '选择群成员',
    String searchHint = '搜索好友昵称或账号',
    String emptyText = '暂无匹配的好友',
    String Function(int count)? confirmTextBuilder,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FriendSelectionSheet(
        friends: friends,
        initialSelected: initialSelected,
        title: title,
        searchHint: searchHint,
        emptyText: emptyText,
        confirmTextBuilder: confirmTextBuilder,
      ),
    );
  }

  @override
  State<FriendSelectionSheet> createState() => _FriendSelectionSheetState();
}

class _FriendSelectionSheetState extends State<FriendSelectionSheet> {
  late final TextEditingController _searchController;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelected);
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim().toLowerCase();
    final filteredFriends = widget.friends.where((friend) {
      if (keyword.isEmpty) return true;
      final displayName = friendDisplayName(friend).toLowerCase();
      return displayName.contains(keyword) ||
          friend.user.username.toLowerCase().contains(keyword);
    }).toList();

    final confirmText =
        widget.confirmTextBuilder?.call(_selectedIds.length) ??
        '确定（${_selectedIds.length}）';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          widget.emptyText,
                          style: const TextStyle(color: AppColors.textTertiary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredFriends.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final friend = filteredFriends[index];
                          final user = friend.user;
                          final isSelected = _selectedIds.contains(user.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(user.id);
                                } else {
                                  _selectedIds.remove(user.id);
                                }
                              });
                            },
                            title: Text(friendDisplayName(friend)),
                            subtitle: Text(user.username),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(Set<String>.from(_selectedIds));
                      },
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
