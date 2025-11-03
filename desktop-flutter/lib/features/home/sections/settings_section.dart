import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AvatarSection(onEdit: () {}),
            const SizedBox(height: 32),
            _SettingsCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('桌面端用户', style: theme.textTheme.titleLarge),
                  GestureDetector(
                    onTap: () {},
                    child: SvgPicture.asset('assets/images/icon-pen.svg', width: 24, height: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              child: Row(
                children: [
                  Text('手机号：', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text('188****0000', style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF707991))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              onTap: () {},
              child: Row(
                children: [
                  Text('隐私政策', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  SvgPicture.asset('assets/images/icon/right.svg', width: 20, height: 20),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _LogoutButton(onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        const CircleAvatar(
          radius: 60,
          backgroundColor: Color(0xFF4ECDC4),
          child: Text('桌', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: SvgPicture.asset('assets/images/icon-edit.svg', fit: BoxFit.scaleDown, width: 18, height: 18),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: SvgPicture.asset('assets/images/icon-logout-red.svg', width: 20, height: 20),
        label: const Text('退出登录'),
        style: ElevatedButton.styleFrom(
          foregroundColor: const Color(0xFFD43745),
          backgroundColor: const Color(0xFFFFF0F0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
    );
  }
}
