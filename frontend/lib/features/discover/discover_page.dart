import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_badge.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = _mockSections();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _DiscoverSection(section: section);
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: sections.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '动态',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '发现更多精彩内容',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  List<DiscoverSectionData> _mockSections() {
    const avatar = AppAssets.loginLogo;
    return [
      DiscoverSectionData(
        items: [
          DiscoverItemData(
            title: '朋友圈',
            iconAsset: AppAssets.discoverMoments,
            badgeCount: 2,
            trailingAvatar: avatar,
          ),
        ],
      ),
      DiscoverSectionData(
        items: [
          DiscoverItemData(
            title: '视频号',
            iconAsset: AppAssets.discoverChannels,
            description: '最新短视频内容',
          ),
          DiscoverItemData(
            title: '直播',
            iconAsset: AppAssets.discoverLive,
            showDivider: false,
          ),
        ],
      ),
      DiscoverSectionData(
        items: [
          DiscoverItemData(title: '扫一扫', iconAsset: AppAssets.discoverScan),
          DiscoverItemData(
            title: '摇一摇',
            iconAsset: AppAssets.discoverShake,
            showDivider: false,
          ),
        ],
      ),
      DiscoverSectionData(
        items: [
          DiscoverItemData(title: '看一看', iconAsset: AppAssets.discoverLook),
          DiscoverItemData(title: '搜一搜', iconAsset: AppAssets.discoverSearch),
          DiscoverItemData(
            title: '附近',
            iconAsset: AppAssets.discoverNearby,
            showDivider: false,
          ),
        ],
      ),
      DiscoverSectionData(
        items: [
          DiscoverItemData(title: '购物', iconAsset: AppAssets.discoverShopping),
          DiscoverItemData(title: '游戏', iconAsset: AppAssets.discoverGames),
          DiscoverItemData(
            title: '小程序',
            iconAsset: AppAssets.discoverMiniApps,
            showDivider: false,
          ),
        ],
      ),
    ];
  }
}

class DiscoverSectionData {
  const DiscoverSectionData({required this.items});

  final List<DiscoverItemData> items;
}

class DiscoverItemData {
  const DiscoverItemData({
    required this.title,
    required this.iconAsset,
    this.description,
    this.badgeCount,
    this.trailingAvatar,
    this.showDivider = true,
  });

  final String title;
  final String iconAsset;
  final String? description;
  final int? badgeCount;
  final String? trailingAvatar;
  final bool showDivider;
}

class _DiscoverSection extends StatelessWidget {
  const _DiscoverSection({required this.section});

  final DiscoverSectionData section;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < section.items.length; i++)
            _DiscoverTile(
              data: section.items[i],
              isFirst: i == 0,
              isLast: i == section.items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.data,
    required this.isFirst,
    required this.isLast,
  });

  final DiscoverItemData data;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${data.title} 功能暂未接入（mock）')));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset(data.iconAsset, width: 28, height: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (data.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (data.badgeCount != null && data.badgeCount! > 0)
                  AppBadge(
                    count: data.badgeCount!,
                    size: 18,
                    fontSize: 12,
                    backgroundColor: AppColors.primary,
                  ),
                if (data.trailingAvatar != null) ...[
                  const SizedBox(width: 12),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          data.trailingAvatar!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textQuaternary,
                ),
              ],
            ),
            if (!isLast && data.showDivider)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Divider(height: 1, color: Color(0xFFE9EBEF)),
              ),
          ],
        ),
      ),
    );
  }
}
