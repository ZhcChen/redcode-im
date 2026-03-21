import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/attachment_url_cache.dart';

void main() {
  group('AttachmentUrlCache', () {
    final cache = AttachmentUrlCache.instance;

    setUp(() {
      cache.clear();
    });

    test('set/get/remove works', () {
      cache.set('file-1', '/tmp/file-1');
      expect(cache.get('file-1'), '/tmp/file-1');

      cache.remove('file-1');
      expect(cache.get('file-1'), isNull);
    });

    test('expires with custom ttl and cleanup clears stale entries', () async {
      cache.set(
        'file-expire',
        '/tmp/file-expire',
        ttl: const Duration(milliseconds: 10),
      );

      expect(cache.get('file-expire'), '/tmp/file-expire');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      cache.cleanup();

      expect(cache.get('file-expire'), isNull);
      expect(cache.length, 0);
    });
  });
}
