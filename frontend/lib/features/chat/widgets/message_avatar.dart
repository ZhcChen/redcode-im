import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_avatar_service.dart';
import '../models/message_model.dart';

/// 消息发送者头像组件
class MessageAvatar extends StatefulWidget {
  const MessageAvatar({
    super.key,
    required this.message,
    required this.radius,
    this.isSelf = false,
  });

  final Message message;
  final double radius;
  final bool isSelf;

  @override
  State<MessageAvatar> createState() => _MessageAvatarState();
}

class _MessageAvatarState extends State<MessageAvatar> {
  final _userAvatarService = UserAvatarService();
  String? _localAvatarPath;
  bool _isLoading = false;
  bool _loadAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadAvatarIfNeeded();
  }

  @override
  void didUpdateWidget(MessageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果消息或发送者变化，重新加载
    if (widget.message.senderId != oldWidget.message.senderId ||
        widget.message.senderAvatar != oldWidget.message.senderAvatar) {
      _loadAttempted = false;
      _loadAvatarIfNeeded();
    }
  }

  Future<void> _loadAvatarIfNeeded() async {
    // 如果已经尝试加载过，不再重复
    if (_loadAttempted || _isLoading) return;

    // 如果没有头像URL，显示默认头像
    final avatarUrl = widget.message.senderAvatar;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return;
    }

    // 如果是网络URL，尝试从缓存加载
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      setState(() {
        _isLoading = true;
        _loadAttempted = true;
      });

      try {
        // 尝试直接根据用户ID查找缓存的头像
        // 先检查是否有缓存
        final cachedPath = await _userAvatarService.resolveAvatarLocalPath(
          userId: widget.message.senderId,
        );

        if (cachedPath != null) {
          // 如果有缓存，直接使用
          if (mounted) {
            setState(() {
              _localAvatarPath = cachedPath;
              _isLoading = false;
            });
          }
        } else {
          // 如果没有缓存，尝试从URL中提取object key
          // URL格式可能是: https://xxx/avatar/object-key 或 https://xxx/users/xxx/avatar
          final uri = Uri.parse(avatarUrl);
          final pathSegments = uri.pathSegments;
          String? objectKey;

          // 尝试从URL路径中提取object key
          // 通常是最后一个路径段，或者倒数第二个（如果最后是 'avatar'）
          if (pathSegments.isNotEmpty) {
            if (pathSegments.last == 'avatar' && pathSegments.length > 1) {
              objectKey = pathSegments[pathSegments.length - 2];
            } else {
              objectKey = pathSegments.last;
            }

            // 移除可能的查询参数
            if (objectKey != null && objectKey.contains('?')) {
              objectKey = objectKey.split('?').first;
            }
          }

          if (objectKey != null && objectKey.isNotEmpty) {
            // 尝试从缓存加载
            final downloadedPath = await _userAvatarService.loadAndCacheAvatar(
              userId: widget.message.senderId,
              avatarObjectKey: objectKey,
            );

            if (mounted) {
              setState(() {
                _localAvatarPath = downloadedPath;
                _isLoading = false;
              });
            }
          } else {
            // 无法提取objectKey，静默失败，使用网络URL
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
      } catch (e) {
        // 加载失败，使用默认头像
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 优先使用本地缓存
    if (_localAvatarPath != null && _localAvatarPath!.isNotEmpty) {
      final file = File(_localAvatarPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: FileImage(file),
          backgroundColor: AppColors.surface,
        );
      }
    }

    // 其次使用网络头像
    final avatar = widget.message.senderAvatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
      // Asset头像
      if (!avatar.startsWith('/')) {
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: AssetImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
    }

    // 默认头像（首字母）
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final name = widget.message.displaySenderName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final backgroundColor = _generateBackgroundColor(name);

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.isSelf
          ? AppColors.primary.withValues(alpha: 0.85)
          : backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: widget.radius * 0.7,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 字符串哈希函数（与聊天列表保持一致）
  int _hashCode(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      int char = str.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs();
  }

  // 根据文本生成背景色（与聊天列表保持一致）
  Color _generateBackgroundColor(String text) {
    if (text.isEmpty) return const Color(0xFF6366f1);

    // 预设的柔和色调（与桌面端保持一致）
    const colors = [
      Color(0xFF6366f1), // 靛蓝
      Color(0xFF8b5cf6), // 紫色
      Color(0xFFec4899), // 粉红
      Color(0xFFf43f5e), // 玫瑰
      Color(0xFFf59e0b), // 琥珀
      Color(0xFF10b981), // 翠绿
      Color(0xFF06b6d4), // 青色
      Color(0xFF3b82f6), // 蓝色
      Color(0xFF6366f1), // 靛蓝
      Color(0xFFa855f7), // 紫罗兰
    ];

    final hash = _hashCode(text);
    return colors[hash % colors.length];
  }
}