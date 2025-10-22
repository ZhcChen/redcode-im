import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/settings_service.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  final SettingsService _service = SettingsService();
  DocumentContent? _policy;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.fetchPrivacyPolicy();
      if (!mounted) return;
      setState(() {
        _policy = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadPolicy,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '加载隐私政策失败',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _loadPolicy,
                    child: const Text('重试'),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_policy?.title.isNotEmpty == true)
                    Text(
                      _policy!.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (_policy?.title.isNotEmpty == true)
                    const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Html(
                      data: _policy?.content ?? '<p>暂无隐私政策内容</p>',
                      style: {
                        'body': Style(
                          color: AppColors.textPrimary,
                          fontSize: FontSize(16),
                          lineHeight: LineHeight.number(1.6),
                        ),
                        'p': Style(margin: Margins.only(bottom: 12)),
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
