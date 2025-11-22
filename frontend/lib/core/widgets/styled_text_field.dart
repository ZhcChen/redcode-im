import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 统一样式的文本输入框组件
class StyledTextField extends StatelessWidget {
  const StyledTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines != null && maxLines! > 1;

    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: enabled
              ? AppColors.textSecondary
              : AppColors.settingsTextMuted,
          fontSize: 14,
        ),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        alignLabelWithHint: isMultiline,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
    );
  }
}
