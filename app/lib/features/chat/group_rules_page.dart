import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/widgets/tip_dialog.dart';

/// 群规页面
class GroupRulesPage extends StatefulWidget {
  const GroupRulesPage({
    super.key,
    required this.roomId,
    this.canManage = false,
  });

  final String roomId;
  final bool canManage;

  @override
  State<GroupRulesPage> createState() => _GroupRulesPageState();
}

class _GroupRulesPageState extends State<GroupRulesPage> {
  final RoomService _roomService = RoomService();
  List<GroupRule> _rules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await _roomService.listRules(widget.roomId);
      if (mounted) {
        setState(() {
          _rules = rules
              .where((r) => r.isActive)
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载群规失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('加载失败：$e');
      }
    }
  }

  void _showAddRuleDialog() {
    _showRuleFormDialog(null);
  }

  void _showEditRuleDialog(GroupRule rule) {
    _showRuleFormDialog(rule);
  }

  void _showRuleFormDialog(GroupRule? rule) {
    final titleController = TextEditingController(text: rule?.title ?? '');
    final contentController = TextEditingController(text: rule?.content ?? '');
    final isEditing = rule != null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditing ? '编辑群规' : '添加群规'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '请输入群规标题',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '请输入群规内容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty) {
                _showSnackBar('请输入群规标题');
                return;
              }
              if (content.isEmpty) {
                _showSnackBar('请输入群规内容');
                return;
              }

              Navigator.pop(dialogContext);

              if (isEditing) {
                await _updateRule(rule.id, title, content);
              } else {
                await _createRule(title, content);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRule(String title, String content) async {
    try {
      await _roomService.createRule(
        roomId: widget.roomId,
        title: title,
        content: content,
        orderIndex: _rules.length,
      );
      _showSnackBar('群规已添加');
      await _loadRules();
    } catch (e) {
      _showSnackBar('添加失败：$e');
    }
  }

  Future<void> _updateRule(String ruleId, String title, String content) async {
    try {
      await _roomService.updateRule(
        roomId: widget.roomId,
        ruleId: ruleId,
        title: title,
        content: content,
      );
      _showSnackBar('群规已更新');
      await _loadRules();
    } catch (e) {
      _showSnackBar('更新失败：$e');
    }
  }

  void _confirmDeleteRule(GroupRule rule) {
    TipDialog.showConfirm(
      context,
      title: '删除群规',
      content: '确定要删除群规「${rule.title}」吗？',
      confirmDanger: true,
      onConfirm: () async {
        try {
          await _roomService.deleteRule(
            roomId: widget.roomId,
            ruleId: rule.id,
          );
          _showSnackBar('群规已删除');
          await _loadRules();
          return true;
        } catch (e) {
          _showSnackBar('删除失败：$e');
          return false;
        }
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('群规'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: widget.canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddRuleDialog,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Text(
                    widget.canManage ? '暂无群规，点击右上角添加' : '暂无群规',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rule = _rules[index];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rule.title,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (widget.canManage) ...[
                                GestureDetector(
                                  onTap: () => _showEditRuleDialog(rule),
                                  child: Text(
                                    '编辑',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _confirmDeleteRule(rule),
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rule.content,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
