import 'dart:io';

import 'package:app/core/utils/local_file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasReadableLocalFile returns true for existing file', () async {
    final tempDir = await Directory.systemTemp.createTemp('local-file-utils');
    final file = File('${tempDir.path}/sample.txt');
    await file.writeAsString('ok');

    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    expect(hasReadableLocalFile(file.path), isTrue);
  });

  test('hasReadableLocalFile returns false for empty or missing file', () {
    expect(hasReadableLocalFile(null), isFalse);
    expect(hasReadableLocalFile(''), isFalse);
    expect(hasReadableLocalFile('/tmp/not-exists-redcode-im-file'), isFalse);
  });
}
