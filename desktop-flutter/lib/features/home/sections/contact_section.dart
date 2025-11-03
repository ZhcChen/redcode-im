import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContactSection extends StatefulWidget {
  const ContactSection({super.key});

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection> {
  final List<_Contact> _contacts = _mockContacts;
  final List<_FriendRequest> _friendRequests = _mockFriendRequests;

  double _contactListWidth = 300;
  bool _showFriendRequests = false;
  _Contact? _selectedContact;

  @override
  void initState() {
    super.initState();
    _selectedContact = _contacts.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: _contactListWidth,
                  child: _showFriendRequests
                      ? _buildFriendRequests(theme)
                      : _buildContactList(theme),
                ),
                _ResizeHandle(
                  onDrag: (delta) {
                    setState(() {
                      _contactListWidth = (_contactListWidth + delta).clamp(260, 420);
                    });
                  },
                  onReset: () => setState(() => _contactListWidth = 300),
                ),
                Expanded(
                  child: _showFriendRequests
                      ? _buildFriendRequestDetail(theme)
                      : _buildContactDetail(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          SizedBox(
            width: _contactListWidth,
            child: Row(
              children: [
                SvgPicture.asset('assets/images/icon-menu.svg', width: 20, height: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: _SearchInput(
                    hintText: _showFriendRequests ? '搜索好友申请...' : '搜索联系人...',
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Text(
            _showFriendRequests ? '新的朋友' : '联系人详情',
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildContactList(ThemeData theme) {
    final grouped = <String, List<_Contact>>{};
    for (final contact in _contacts) {
      grouped.putIfAbsent(contact.letter, () => []).add(contact);
    }

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _FixedItem(
            icon: 'assets/images/icon-new-friend.svg',
            title: '新的朋友',
            trailing: _friendRequests.isNotEmpty
                ? Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _friendRequests.length.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () {
              setState(() {
                _showFriendRequests = true;
              });
            },
          ),
          _FixedItem(
            icon: 'assets/images/icon-group.svg',
            title: '群组',
            onTap: () {},
          ),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9B9BB0),
                ),
              ),
            ),
            ...entry.value.map((contact) {
              final isSelected = _selectedContact?.id == contact.id;
              return _ContactItem(
                contact: contact,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedContact = contact;
                    _showFriendRequests = false;
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendRequests(ThemeData theme) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _FriendRequestHeader(onBack: () {
            setState(() {
              _showFriendRequests = false;
            });
          }),
          const Divider(height: 1),
          Expanded(
            child: _friendRequests.isEmpty
                ? const Center(child: Text('暂无好友申请'))
                : ListView.builder(
                    itemCount: _friendRequests.length,
                    itemBuilder: (context, index) {
                      final request = _friendRequests[index];
                      return _FriendRequestItem(request: request);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetail(ThemeData theme) {
    final contact = _selectedContact;
    if (contact == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Text('请选择联系人', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: Text(
              contact.avatarLabel,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Text(contact.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(contact.remark, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          _InfoRow(label: '手机号', value: contact.phone ?? '未填写'),
          const SizedBox(height: 16),
          _InfoRow(label: '分组', value: contact.groupName ?? '默认分组'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('发起聊天'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestDetail(ThemeData theme) {
    if (_friendRequests.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Text('暂无好友申请详情', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final request = _friendRequests.first;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: Text(request.name.characters.first),
          ),
          const SizedBox(height: 24),
          Text(request.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(request.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('拒绝'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('通过验证'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixedItem extends StatelessWidget {
  const _FixedItem({required this.icon, required this.title, this.trailing, this.onTap});

  final String icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(icon, width: 32, height: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({required this.contact, required this.isSelected, required this.onTap});

  final _Contact contact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected ? const Color(0xFFEFFBF9) : Colors.transparent,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Text(contact.avatarLabel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                contact.name,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestHeader extends StatelessWidget {
  const _FriendRequestHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              children: [
                SvgPicture.asset('assets/images/icon-back.svg', width: 20, height: 20),
                const SizedBox(width: 8),
                const Text('返回联系人列表'),
              ],
            ),
          ),
          const Spacer(),
          SvgPicture.asset('assets/images/icon-new-friend.svg', width: 28, height: 28),
        ],
      ),
    );
  }
}

class _FriendRequestItem extends StatelessWidget {
  const _FriendRequestItem({required this.request});

  final _FriendRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E9F0), width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            child: Text(request.name.characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(request.name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text(request.status, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  request.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF707991)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text('$label：', style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF707991)),
          ),
        ),
      ],
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF9B9BB0)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact {
  const _Contact({
    required this.id,
    required this.name,
    required this.letter,
    this.phone,
    this.remark = '',
    this.groupName,
  });

  final String id;
  final String name;
  final String letter;
  final String? phone;
  final String remark;
  final String? groupName;

  String get avatarLabel => name.isNotEmpty ? name.characters.first : '?';
}

class _FriendRequest {
  const _FriendRequest({required this.id, required this.name, required this.message, required this.status});

  final String id;
  final String name;
  final String message;
  final String status;
}

const _mockContacts = <_Contact>[
  _Contact(id: '1', name: '张三', letter: 'Z', phone: '188****0001', remark: '项目经理', groupName: '同事'),
  _Contact(id: '2', name: '李四', letter: 'L', phone: '188****0002', remark: '后端开发', groupName: '同事'),
  _Contact(id: '3', name: '王五', letter: 'W', phone: '188****0003', remark: '设计师', groupName: '同事'),
  _Contact(id: '4', name: '产品群', letter: 'C', remark: '需求讨论群组', groupName: '群组'),
  _Contact(id: '5', name: '桌面端专项', letter: 'Z', remark: 'Flutter 迁移专项', groupName: '项目'),
];

const _mockFriendRequests = <_FriendRequest>[
  _FriendRequest(id: '1', name: '赵六', message: '您好，我是 QA，希望加入项目群。', status: '待验证'),
  _FriendRequest(id: '2', name: '测试账号', message: '一起测试桌面端', status: '待验证'),
];

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag, required this.onReset});

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onDoubleTap: onReset,
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
