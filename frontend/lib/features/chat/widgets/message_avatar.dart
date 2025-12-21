import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_avatar_service.dart';
import '../../../core/utils/avatar_color_utils.dart';
import '../../../core/widgets/skeleton.dart';
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
        // 优先使用 message 中的 objectKey
        final objectKey = widget.message.senderAvatarObjectKey;

        if (objectKey != null && objectKey.isNotEmpty) {
          // 先检查缓存（使用 objectKey 验证）
          final cachedPath = await _userAvatarService.resolveAvatarLocalPath(
            userId: widget.message.senderId,
            objectKey: objectKey,
          );

          if (cachedPath != null) {
            if (mounted) {
              setState(() {
                _localAvatarPath = cachedPath;
                _isLoading = false;
              });
            }
            return;
          }

          // 缓存未命中或已失效，下载新头像
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
          // 没有 objectKey，尝试仅根据 userId 查找缓存
          final cachedPath = await _userAvatarService.resolveAvatarLocalPath(
            userId: widget.message.senderId,
          );

          if (cachedPath != null && mounted) {
            setState(() {
              _localAvatarPath = cachedPath;
              _isLoading = false;
            });
          } else if (mounted) {
            setState(() {
              _isLoading = false;
            });
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildAvatarContent(),
    );
  }

  Widget _buildAvatarContent() {
    // 优先使用本地缓存
    if (_localAvatarPath != null && _localAvatarPath!.isNotEmpty) {
      final file = File(_localAvatarPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          key: ValueKey('local_$_localAvatarPath'),
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
          key: ValueKey('network_$avatar'),
          radius: widget.radius,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
      // Asset头像
      if (!avatar.startsWith('/')) {
        return CircleAvatar(
          key: ValueKey('asset_$avatar'),
          radius: widget.radius,
          backgroundImage: AssetImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
    }

    // 默认头像（首字母）
    if (_isLoading) {
      return Skeleton(
        key: const ValueKey('skeleton'),
        width: widget.radius * 2,
        height: widget.radius * 2,
        shape: BoxShape.circle,
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final name = widget.message.displaySenderName.trim();
    final initial = AvatarColorUtils.getInitial(name);
    // 背景色使用稳定种子(优先 senderId)，保证与聊天列表一致
    final seed = widget.message.senderId?.toString();
    final backgroundColor =
        AvatarColorUtils.generateBackgroundColor(seed ?? name);

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: backgroundColor,
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
}
