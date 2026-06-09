import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../../core/storage/attachment_cache.dart';
import '../../core/storage/attachment_url_cache.dart';
import '../../core/storage/avatar_cache.dart';
import '../../core/storage/emoji_cache.dart';
import 'chat_background_page.dart';
import 'sticker_management_page.dart';
import 'widgets/confirm_action_dialog.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  bool _clearingHistory = false;
  bool _clearingCache = false;

  void _openChatBackground() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatBackgroundPage()));
  }

  void _openStickerManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StickerManagementPage()));
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;

    final confirm = await showConfirmActionDialog(
      context,
      title: '清除缓存',
      message: '将清除所有本地缓存（包括图片、附件等），此操作不可恢复，确认继续？',
      confirmLabel: '清除',
    );
    if (!mounted || confirm != true) {
      return;
    }

    setState(() => _clearingCache = true);
    try {
      // 清除附件缓存
      await AttachmentCache.instance.clearAll();
      // 清除附件 URL 内存缓存
      AttachmentUrlCache.instance.clear();
      // 清除头像缓存
      await AvatarCache.instance.clearAll();
      // 清除表情缓存
      await EmojiCache.instance.clearAll();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清除缓存失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      } else {
        _clearingCache = false;
      }
    }
  }

  Future<void> _clearChatHistory() async {
    if (_clearingHistory) return;

    final confirm = await showConfirmActionDialog(
      context,
      title: '清空聊天记录',
      message: '将删除所有本地聊天记录，此操作不可恢复，确认继续？',
      confirmLabel: '清空',
    );
    if (!mounted || confirm != true) {
      return;
    }

    setState(() => _clearingHistory = true);
    try {
      await MessageService.instance.clearAll();
      await MessageService.instance.fetchChats();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('聊天记录已清空')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清空聊天记录失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _clearingHistory = false);
      } else {
        _clearingHistory = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '聊天',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textBlack,
            letterSpacing: 0,
            height: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ChatSettingItem(
                  title: '聊天背景',
                  onTap: _openChatBackground,
                  showDivider: true,
                ),
                _ChatSettingItem(
                  title: '表情管理',
                  onTap: _openStickerManagement,
                  showDivider: true,
                ),
                _ChatSettingItem(
                  title: '清除缓存',
                  onTap: _clearingCache ? null : _clearCache,
                  showDivider: true,
                  isLoading: _clearingCache,
                  isDanger: true,
                ),
                _ChatSettingItem(
                  title: '清空聊天记录',
                  onTap: _clearingHistory ? null : _clearChatHistory,
                  showDivider: false,
                  isLoading: _clearingHistory,
                  isDanger: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatSettingItem extends StatelessWidget {
  const _ChatSettingItem({
    required this.title,
    required this.onTap,
    required this.showDivider,
    this.isLoading = false,
    this.isDanger = false,
  });

  final String title;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool isLoading;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.settingsDivider,
                      width: 1,
                    ),
                  ),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDanger ? AppColors.danger : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else if (!isDanger)
                const Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: AppColors.textPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
