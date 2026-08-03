import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/report_service.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/widgets/tip_dialog.dart';

class ReportDialog {
  const ReportDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    ReportService? reportService,
    ImagePicker? imagePicker,
    PermissionService? permissionService,
  }) {
    final service = reportService ?? ReportService();
    final picker = imagePicker ?? ImagePicker();
    final controller = TextEditingController();
    final attachments = <XFile>[];
    const maxAttachments = 3;
    var submitting = false;
    StateSetter? setDialogState;

    return TipDialog.showConfirm(
      context,
      title: targetType == 'room' ? '举报该群聊' : '举报该用户',
      contentWidget: StatefulBuilder(
        builder: (dialogContext, setState) {
          setDialogState = setState;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '恶意举报将受到处罚，请谨慎操作',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('report-content'),
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                enabled: !submitting,
                decoration: const InputDecoration(
                  hintText: '请输入举报内容（必填）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          submitting || attachments.length >= maxAttachments
                          ? null
                          : () async {
                              if (!await ensureAppPermission(
                                dialogContext,
                                AppPermission.photos,
                                service: permissionService,
                              )) {
                                return;
                              }
                              if (!dialogContext.mounted) return;
                              try {
                                final files = await picker.pickMultiImage(
                                  imageQuality: 85,
                                );
                                if (files.isEmpty) return;
                                setState(() {
                                  attachments.addAll(
                                    files.take(
                                      maxAttachments - attachments.length,
                                    ),
                                  );
                                });
                              } catch (_) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('打开相册失败，请稍后再试'),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('选择截图'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          submitting || attachments.length >= maxAttachments
                          ? null
                          : () async {
                              if (!await ensureAppPermission(
                                dialogContext,
                                AppPermission.camera,
                                service: permissionService,
                              )) {
                                return;
                              }
                              if (!dialogContext.mounted) return;
                              try {
                                final file = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 85,
                                );
                                if (file == null) return;
                                setState(() => attachments.add(file));
                              } catch (_) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('打开相机失败，请稍后再试'),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('拍照'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '已选择 ${attachments.length}/$maxAttachments 张（必填）',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attachments.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(entry.value.path),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            tooltip: '移除截图',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: submitting
                                ? null
                                : () => setState(
                                    () => attachments.removeAt(entry.key),
                                  ),
                            icon: const Icon(
                              Icons.cancel,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              if (submitting) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('提交中...'),
                  ],
                ),
              ],
            ],
          );
        },
      ),
      confirmText: '提交举报',
      cancelText: '取消',
      confirmDanger: true,
      barrierDismissible: false,
      onConfirm: () async {
        if (submitting) return false;
        final messenger = ScaffoldMessenger.of(context);
        if (controller.text.trim().isEmpty) {
          messenger.showSnackBar(const SnackBar(content: Text('请输入举报内容')));
          return false;
        }
        if (attachments.isEmpty) {
          messenger.showSnackBar(const SnackBar(content: Text('请至少上传 1 张截图')));
          return false;
        }

        setDialogState?.call(() => submitting = true);
        try {
          await service.submitReport(
            targetType: targetType,
            targetId: targetId,
            content: controller.text,
            attachments: attachments.map((item) => File(item.path)).toList(),
          );
          messenger.showSnackBar(const SnackBar(content: Text('举报已提交，感谢你的反馈')));
          return true;
        } on ReportServiceException catch (error) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
          return false;
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('举报失败，请稍后再试')));
          return false;
        } finally {
          setDialogState?.call(() => submitting = false);
        }
      },
    ).whenComplete(controller.dispose);
  }
}
