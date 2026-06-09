import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/avatar_color_utils.dart';

void main() {
  group('AvatarColorUtils', () {
    test('returns default gray for empty input', () {
      expect(
        AvatarColorUtils.generateBackgroundColor('   '),
        const Color(0xFFF0F0F0),
      );
    });

    test('returns deterministic color for same text', () {
      final first = AvatarColorUtils.generateBackgroundColor('alice');
      final second = AvatarColorUtils.generateBackgroundColor('alice');

      expect(first, second);
      expect(
        AvatarColorUtils.avatarColors.contains(first),
        isTrue,
      );
    });

    test('returns uppercase initial for latin letters and keeps CJK char', () {
      expect(AvatarColorUtils.getInitial('alice'), 'A');
      expect(AvatarColorUtils.getInitial('张三'), '张');
      expect(AvatarColorUtils.getInitial('   '), '?');
    });
  });
}
