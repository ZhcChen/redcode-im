import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/friend_store.dart';
import '../../core/services/room_service.dart';
import '../contacts/models/friend_models.dart';
import 'widgets/friend_selection_sheet.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key, this.friendService, this.roomService});

  final FriendService? friendService;
  final RoomService? roomService;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  late final FriendService _friendService;
  late final RoomService _roomService;
  final FriendStore _friendStore = FriendStore.instance;

  bool _isSubmitting = false;
  bool _isLoadingFriends = false;
  List<FriendInfo> _friends = [];
  final Set<String> _selectedFriendIds = <String>{};

  @override
  void initState() {
    super.initState();
    _friendService = widget.friendService ?? FriendService();
    _roomService = widget.roomService ?? RoomService();
    _loadFriends();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFriends = _friends
        .where((friend) => _selectedFriendIds.contains(friend.user.id))
        .toList();
    final hasFriendCandidates = _friends.isNotEmpty;
    final shouldBlockFriendSelection =
        _isLoadingFriends && !hasFriendCandidates;

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
                        onPressed: shouldBlockFriendSelection
                            ? null
                            : _selectMembers,
                        child: const Text(
                          '添加好友',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (shouldBlockFriendSelection)
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
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingFriends)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '正在刷新好友列表...',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (selectedFriends.isEmpty)
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
                                    label: Text(friendDisplayName(friend)),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                    onDeleted: () =>
                                        _removeMember(friend.user.id),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
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
    _primeFriendsFromStore();
    try {
      final friends = await _friendService.fetchFriends();
      if (!mounted) return;
      setState(() {
        // 已有应用内好友快照时，一次空返回先不抹空候选，避免刚建立好友关系后
        // 创建群页与当前联系人视图短暂脱节。
        if (friends.isNotEmpty || _friends.isEmpty) {
          _friends = friends;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (_friends.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取好友列表失败：$e')));
      }
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

  void _primeFriendsFromStore() {
    if (_friends.isNotEmpty) {
      return;
    }

    final storeFriends = _friendStore.friends;
    if (storeFriends.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _friends = List<FriendInfo>.from(storeFriends);
    });
  }

  Future<void> _createGroup() async {
    if (_isSubmitting) return;

    final groupName = _groupNameController.text.trim();

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

    final result = await FriendSelectionSheet.show(
      context,
      friends: _friends,
      initialSelected: _selectedFriendIds,
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
    super.dispose();
  }
}
