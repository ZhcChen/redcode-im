import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/room_service.dart';
import '../contacts/models/friend_models.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescController = TextEditingController();
  final FriendService _friendService = FriendService();
  final RoomService _roomService = RoomService();

  bool _isSubmitting = false;
  bool _isLoadingFriends = false;
  List<FriendInfo> _friends = [];
  final Set<String> _selectedFriendIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFriends = _friends
        .where((friend) => _selectedFriendIds.contains(friend.user.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _createGroup,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : const Text(
                    '创建',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _groupNameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '群聊名称',
                hintText: '请输入群聊名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groupDescController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '群公告（选填）',
                hintText: '请输入群公告',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '群成员（${_selectedFriendIds.length}）',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoadingFriends ? null : _selectMembers,
                        child: const Text(
                          '添加好友',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingFriends)
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  else if (selectedFriends.isEmpty)
                    const Text(
                      '点击右上角按钮，选择至少一位好友加入群聊',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedFriends
                          .map(
                            (friend) => Chip(
                              label: Text(_displayFriendName(friend)),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeMember(friend.user.id),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
    });
    try {
      final friends = await _friendService.fetchFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取好友列表失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      } else {
        _isLoadingFriends = false;
      }
    }
  }

  Future<void> _createGroup() async {
    if (_isSubmitting) return;

    final groupName = _groupNameController.text.trim();
    final description = _groupDescController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入群聊名称')));
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一位好友加入群聊')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final createdRoom = await _roomService.createGroup(
        name: groupName,
        description: description.isEmpty ? null : description,
        memberIds: _selectedFriendIds.toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(createdRoom.id);
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建群聊失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
    }
  }

  void _removeMember(String userId) {
    setState(() {
      _selectedFriendIds.remove(userId);
    });
  }

  Future<void> _selectMembers() async {
    if (_friends.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可添加的好友，请先添加好友')));
      return;
    }

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberSelectionSheet(
        friends: _friends,
        initialSelected: _selectedFriendIds,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedFriendIds
        ..clear()
        ..addAll(result);
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescController.dispose();
    super.dispose();
  }
}

class _MemberSelectionSheet extends StatefulWidget {
  const _MemberSelectionSheet({
    required this.friends,
    required this.initialSelected,
  });

  final List<FriendInfo> friends;
  final Set<String> initialSelected;

  @override
  State<_MemberSelectionSheet> createState() => _MemberSelectionSheetState();
}

class _MemberSelectionSheetState extends State<_MemberSelectionSheet> {
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
      final displayName = _displayFriendName(friend).toLowerCase();
      return displayName.contains(keyword) ||
          friend.user.username.toLowerCase().contains(keyword);
    }).toList();

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
              const Text(
                '选择群成员',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索好友昵称或账号',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredFriends.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无匹配的好友',
                          style: TextStyle(color: AppColors.textTertiary),
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
                            title: Text(_displayFriendName(friend)),
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
                        Navigator.of(
                          context,
                        ).pop(Set<String>.from(_selectedIds));
                      },
                      child: Text('确定（${_selectedIds.length}）'),
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

String _displayFriendName(FriendInfo friend) {
  final nickname = friend.user.nickname;
  if (nickname != null && nickname.trim().isNotEmpty) {
    return nickname;
  }
  return friend.user.username;
}
