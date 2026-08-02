import 'package:flutter/material.dart';
import 'tip_dialog.dart';

/// 输入对话框组件
/// 基于 TipDialog，支持文本输入和表单验证
class InputDialog extends StatefulWidget {
  /// 弹窗标题
  final String? title;

  /// 输入框提示文本
  final String hintText;

  /// 初始值
  final String? initialValue;

  /// 最大长度
  final int? maxLength;

  /// 是否自动聚焦
  final bool autofocus;

  /// 验证函数
  final String? Function(String?)? validator;

  /// 确认按钮文本
  final String confirmText;

  /// 取消按钮文本
  final String cancelText;

  /// 确认回调，返回输入的值
  final Future<String?> Function(String value)? onConfirm;

  /// 取消回调
  final VoidCallback? onCancel;

  const InputDialog({
    super.key,
    this.title,
    this.hintText = '请输入',
    this.initialValue,
    this.maxLength,
    this.autofocus = true,
    this.validator,
    this.confirmText = '保存',
    this.cancelText = '取消',
    this.onConfirm,
    this.onCancel,
  });

  /// 显示输入对话框
  static Future<String?> show(
    BuildContext context, {
    String? title,
    String hintText = '请输入',
    String? initialValue,
    int? maxLength,
    bool autofocus = true,
    String? Function(String?)? validator,
    String confirmText = '保存',
    String cancelText = '取消',
    Future<String?> Function(String value)? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        maxLength: maxLength,
        autofocus: autofocus,
        validator: validator,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final value = _controller.text.trim();
    if (widget.onConfirm != null) {
      final result = await widget.onConfirm!(value);
      if (mounted && result != null) {
        Navigator.of(context).pop(result);
        return false;
      }
      return false;
    } else {
      Navigator.of(context).pop(value);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TipDialog(
      title: widget.title,
      contentWidget: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hintText,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          validator: widget.validator,
        ),
      ),
      confirmText: widget.confirmText,
      cancelText: widget.cancelText,
      onConfirm: _handleConfirm,
      onCancel: widget.onCancel,
    );
  }
}
