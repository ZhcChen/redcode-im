import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/emoji/models/emoji_pack_models.dart';

void main() {
  group('emoji models', () {
    test('EmojiPack parses nested items and pack_type', () {
      final pack = EmojiPack.fromJson({
        'id': 'pack-1',
        'name': '默认贴纸',
        'icon_url': 'https://cdn.example.com/icon.png',
        'description': '描述',
        'is_active': true,
        'created_at': '2026-03-05T00:00:00Z',
        'updated_at': '2026-03-05T01:00:00Z',
        'pack_type': 1,
        'items': [
          {
            'id': 'item-1',
            'pack_id': 'pack-1',
            'image_url': 'https://cdn.example.com/1.png',
            'name': '开心',
            'sort_order': 3,
            'created_at': '2026-03-05T00:00:00Z',
          },
        ],
      });

      expect(pack.id, 'pack-1');
      expect(pack.packType, 1);
      expect(pack.items, hasLength(1));
      expect(pack.items.first.name, '开心');
      expect(pack.items.first.sortOrder, 3);
    });

    test('EmojiPack uses defaults for optional fields', () {
      final pack = EmojiPack.fromJson({
        'id': 'pack-2',
        'name': '最小数据包',
        'created_at': '2026-03-05T00:00:00Z',
        'updated_at': '2026-03-05T00:00:00Z',
      });

      expect(pack.isActive, isTrue);
      expect(pack.packType, 0);
      expect(pack.items, isEmpty);
    });

    test('EmojiItem defaults sort_order to 0 when absent', () {
      final item = EmojiItem.fromJson({
        'id': 'item-2',
        'pack_id': 'pack-2',
        'image_url': 'https://cdn.example.com/2.png',
        'created_at': '2026-03-05T00:00:00Z',
      });

      expect(item.sortOrder, 0);
      expect(item.name, isNull);
    });
  });
}
