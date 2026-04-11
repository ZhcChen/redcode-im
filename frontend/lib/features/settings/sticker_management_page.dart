import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StickerManagementPage extends StatefulWidget {
  const StickerManagementPage({super.key});

  @override
  State<StickerManagementPage> createState() => _StickerManagementPageState();
}

class _StickerManagementPageState extends State<StickerManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<StickerPack> _myStickers = [];
  List<StickerPack> _storeStickers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStickers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStickers() async {
    // 模拟加载贴纸数据
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _myStickers = [
          StickerPack(
            id: '1',
            name: '默认表情',
            count: 24,
            coverUrl: null,
            isDefault: true,
          ),
        ];
        _storeStickers = [
          StickerPack(
            id: '2',
            name: '小黄脸',
            count: 36,
            coverUrl: null,
            isDefault: false,
          ),
          StickerPack(
            id: '3',
            name: '动物世界',
            count: 48,
            coverUrl: null,
            isDefault: false,
          ),
          StickerPack(
            id: '4',
            name: '可爱猫咪',
            count: 30,
            coverUrl: null,
            isDefault: false,
          ),
        ];
        _loading = false;
      });
    }
  }

  Future<void> _addStickerPack(StickerPack pack) async {
    setState(() {
      _myStickers.add(pack);
      _storeStickers.removeWhere((s) => s.id == pack.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加"${pack.name}"')));
    }
  }

  Future<void> _removeStickerPack(StickerPack pack) async {
    if (pack.isDefault) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('默认贴纸不可删除')));
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除贴纸'),
        content: Text('确定要删除"${pack.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _myStickers.removeWhere((s) => s.id == pack.id);
        _storeStickers.add(pack);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除"${pack.name}"')));
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
          '表情管理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textBlack,
            letterSpacing: 0,
            height: 1.2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '我的表情'),
            Tab(text: '表情商店'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMyStickersTab(), _buildStoreTab()],
            ),
    );
  }

  Widget _buildMyStickersTab() {
    if (_myStickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无贴纸',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('去商店看看'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myStickers.length,
      itemBuilder: (context, index) {
        final pack = _myStickers[index];
        return _StickerPackCard(
          pack: pack,
          trailing: pack.isDefault
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '默认',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _removeStickerPack(pack),
                ),
        );
      },
    );
  }

  Widget _buildStoreTab() {
    if (_storeStickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              '暂无更多贴纸',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _storeStickers.length,
      itemBuilder: (context, index) {
        final pack = _storeStickers[index];
        return _StickerPackCard(
          pack: pack,
          trailing: OutlinedButton(
            onPressed: () => _addStickerPack(pack),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('添加'),
          ),
        );
      },
    );
  }
}

class StickerPack {
  final String id;
  final String name;
  final int count;
  final String? coverUrl;
  final bool isDefault;

  StickerPack({
    required this.id,
    required this.name,
    required this.count,
    this.coverUrl,
    this.isDefault = false,
  });
}

class _StickerPackCard extends StatelessWidget {
  const _StickerPackCard({required this.pack, required this.trailing});

  final StickerPack pack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 贴纸封面
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.emoji_emotions,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // 贴纸信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pack.count} 个表情',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 操作按钮
          trailing,
        ],
      ),
    );
  }
}
