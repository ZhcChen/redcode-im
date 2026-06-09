import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/file_hash.dart';

void main() {
  group('computeFileHash', () {
    test('returns sha256 hash and alg id for bytes', () async {
      final bytes = Uint8List.fromList(utf8.encode('abc'));

      final result = await computeFileHash(bytes);

      expect(
        result.hashValue,
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
      expect(result.hashAlg, 2);
    });

    test('same input returns stable hash', () async {
      final bytes = Uint8List.fromList(utf8.encode('redcode-im'));
      final first = await computeFileHash(bytes);
      final second = await computeFileHash(bytes);

      expect(first.hashValue, isNotNull);
      expect(first.hashValue, second.hashValue);
      expect(first.hashAlg, second.hashAlg);
    });
  });
}
