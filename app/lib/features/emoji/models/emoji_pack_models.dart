class EmojiPack {
  final String id;
  final String name;
  final String? iconUrl;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EmojiItem> items;
  final int packType; // 0=单个, 1=贴纸包

  EmojiPack({
    required this.id,
    required this.name,
    this.iconUrl,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.packType = 0,
  });

  factory EmojiPack.fromJson(Map<String, dynamic> json) {
    return EmojiPack(
      id: json['id'] as String,
      name: json['name'] as String,
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['items'] != null
          ? (json['items'] as List)
                .map((item) => EmojiItem.fromJson(item as Map<String, dynamic>))
                .toList()
          : [],
      packType: json['pack_type'] as int? ?? 0,
    );
  }
}

class EmojiItem {
  final String id;
  final String packId;
  final String imageUrl;
  final String? name;
  final int sortOrder;
  final DateTime createdAt;

  EmojiItem({
    required this.id,
    required this.packId,
    required this.imageUrl,
    this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  factory EmojiItem.fromJson(Map<String, dynamic> json) {
    return EmojiItem(
      id: json['id'] as String,
      packId: json['pack_id'] as String,
      imageUrl: json['image_url'] as String,
      name: json['name'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
