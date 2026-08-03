import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/permission_gate.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});

  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  static const String _backgroundKey = 'chat_background';
  static const String _backgroundTypeKey = 'chat_background_type';

  String? _selectedBackground;
  String _backgroundType = 'default'; // default, preset, custom
  bool _loading = true;
  bool _saving = false;

  // 预设背景颜色
  final List<Color> _presetColors = [
    Colors.white,
    const Color(0xFFF5F5F5),
    const Color(0xFFE8F4FD),
    const Color(0xFFFFF8E1),
    const Color(0xFFE8F5E9),
    const Color(0xFFFCE4EC),
    const Color(0xFFF3E5F5),
    const Color(0xFFE0F7FA),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentBackground();
  }

  Future<void> _loadCurrentBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString(_backgroundTypeKey) ?? 'default';
      final background = prefs.getString(_backgroundKey);
      if (mounted) {
        setState(() {
          _backgroundType = type;
          _selectedBackground = background;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveBackground(String type, String? value) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backgroundTypeKey, type);
      if (value != null) {
        await prefs.setString(_backgroundKey, value);
      } else {
        await prefs.remove(_backgroundKey);
      }

      if (mounted) {
        setState(() {
          _backgroundType = type;
          _selectedBackground = value;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('背景已保存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  Future<void> _selectCustomImage() async {
    if (!await ensureAppPermission(context, AppPermission.photos)) {
      return;
    }
    if (!mounted) return;
    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开相册失败: $error')));
      return;
    }

    if (pickedFile == null) return;

    // 复制图片到应用目录
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backgroundDir = Directory('${appDir.path}/chat_backgrounds');
      if (!await backgroundDir.exists()) {
        await backgroundDir.create(recursive: true);
      }

      final fileName = 'custom_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = '${backgroundDir.path}/$fileName';
      final sourceFile = File(pickedFile.path);
      await sourceFile.copy(destPath);

      await _saveBackground('custom', destPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存图片失败：$error')));
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
          '聊天背景',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textBlack,
            letterSpacing: 0,
            height: 1.2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 预览区域
                    Container(
                      width: double.infinity,
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: _getPreviewColor(),
                        borderRadius: BorderRadius.circular(16),
                        image:
                            _backgroundType == 'custom' &&
                                _selectedBackground != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedBackground!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                '预览效果',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 预设颜色
                    const Text(
                      '纯色背景',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _presetColors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final color = entry.value;
                          final isSelected =
                              _backgroundType == 'preset' &&
                              _selectedBackground == index.toString();
                          final isDefault =
                              index == 0 && _backgroundType == 'default';

                          return GestureDetector(
                            onTap: _saving
                                ? null
                                : () {
                                    if (index == 0) {
                                      _saveBackground('default', null);
                                    } else {
                                      _saveBackground(
                                        'preset',
                                        index.toString(),
                                      );
                                    }
                                  },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (isSelected || isDefault)
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: (isSelected || isDefault) ? 2 : 1,
                                ),
                              ),
                              child: (isSelected || isDefault)
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 自定义图片
                    const Text(
                      '自定义背景',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _selectCustomImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('从相册选择'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_backgroundType == 'custom' &&
                              _selectedBackground != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      '已设置自定义背景',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              _saveBackground('default', null),
                                    child: const Text('重置'),
                                  ),
                                ],
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

  Color _getPreviewColor() {
    if (_backgroundType == 'default') {
      return Colors.white;
    } else if (_backgroundType == 'preset' && _selectedBackground != null) {
      final index = int.tryParse(_selectedBackground!) ?? 0;
      if (index >= 0 && index < _presetColors.length) {
        return _presetColors[index];
      }
    }
    return Colors.white;
  }
}
