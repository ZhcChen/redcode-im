import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../auth/data/auth_repository.dart';
import '../auth/models/auth_user.dart';

typedef UpdateNicknameAction = Future<AuthUser> Function(String nickname);
typedef UploadAvatarAction = Future<AuthUser> Function(File file);
typedef PickAvatarAction = Future<File?> Function();

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.user,
    this.updateNickname,
    this.uploadAvatar,
    this.pickAvatar,
  });

  final AuthUser user;
  final UpdateNicknameAction? updateNickname;
  final UploadAvatarAction? uploadAvatar;
  final PickAvatarAction? pickAvatar;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nicknameController;
  late AuthUser _user;
  File? _pendingAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _nicknameController = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<File?> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _selectAvatar() async {
    try {
      final file = await (widget.pickAvatar ?? _pickFromGallery)();
      if (!mounted || file == null) return;
      if (!file.existsSync()) {
        throw const AuthException('未找到所选文件');
      }
      setState(() => _pendingAvatar = file);
    } catch (error) {
      if (!mounted) return;
      final message = error is AuthException ? error.message : '打开相册失败：$error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    if (nickname.length > 20) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称不能超过 20 个字符')));
      return;
    }

    setState(() => _saving = true);
    try {
      var updated = _user;
      if (_pendingAvatar != null) {
        final upload = widget.uploadAvatar ?? AuthRepository().uploadAvatar;
        updated = await upload(_pendingAvatar!);
      }
      if (nickname != updated.displayName) {
        final update =
            widget.updateNickname ??
            (value) => AuthRepository().updateProfile(nickname: value);
        updated = await update(nickname);
      }
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar =
        _pendingAvatar ??
        ((_user.localAvatarPath?.isNotEmpty ?? false)
            ? File(_user.localAvatarPath!)
            : null);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '编辑资料',
        dense: true,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            key: const Key('profile-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: avatar != null && avatar.existsSync()
                        ? Image.file(
                            key: const Key('profile-avatar-preview'),
                            avatar,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 88,
                            height: 88,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            alignment: Alignment.center,
                            child: const Icon(Icons.person_outline, size: 36),
                          ),
                  ),
                  TextButton(
                    key: const Key('profile-pick-avatar'),
                    onPressed: _saving ? null : _selectAvatar,
                    child: const Text('更换头像'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('profile-nickname'),
              controller: _nicknameController,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '用户名',
                enabled: false,
              ),
              child: Text(_user.username),
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '邮箱',
                enabled: false,
              ),
              child: Text(_user.email ?? '未绑定'),
            ),
          ],
        ),
      ),
    );
  }
}
