import 'dart:io';

import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/mine/profile_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'u-1',
  username: 'alice',
  nickname: 'Alice',
  email: 'alice@example.com',
);

void main() {
  testWidgets('edits only supported nickname field', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(
          user: _user,
          updateNickname: (nickname) async {
            submitted = nickname;
            return _user.copyWith(nickname: nickname);
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('profile-nickname')),
      'Alice 2',
    );
    tester
        .widget<TextButton>(find.byKey(const Key('profile-save')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(submitted, 'Alice 2');
  });

  testWidgets('keeps form and pending avatar after upload failure', (
    tester,
  ) async {
    final file = File(
      '${Directory.current.path}/assets/images/login/app_logo.png',
    );
    expect(file.existsSync(), isTrue);
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(
          user: _user,
          pickAvatar: () async => file,
          uploadAvatar: (_) async {
            uploadCalls++;
            throw const AuthException('上传签名失败');
          },
        ),
      ),
    );
    tester
        .widget<TextButton>(find.byKey(const Key('profile-pick-avatar')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-avatar-preview')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-nickname')), '保留的昵称');
    tester
        .widget<TextButton>(find.byKey(const Key('profile-save')))
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(uploadCalls, 1);
    expect(find.text('上传签名失败'), findsOneWidget);
    expect(find.text('保留的昵称'), findsOneWidget);
    expect(find.byType(ProfileEditPage), findsOneWidget);
  });
}
