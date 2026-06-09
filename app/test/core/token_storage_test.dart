import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenStorage', () {
    const storage = TokenStorage();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveSession and readSession keep token/user/refreshToken', () async {
      const user = AuthUser(id: 'user-1', username: 'alice', nickname: 'Alice');
      const session = AuthSession(
        token: 'token-1',
        user: user,
        refreshToken: 'refresh-1',
      );

      await storage.saveSession(session);
      final loaded = await storage.readSession();

      expect(loaded, isNotNull);
      expect(loaded!.token, 'token-1');
      expect(loaded.refreshToken, 'refresh-1');
      expect(loaded.user.username, 'alice');
      expect(loaded.user.displayName, 'Alice');
    });

    test('updateUser is ignored when no token exists', () async {
      const updatedUser = AuthUser(
        id: 'user-2',
        username: 'bob',
        nickname: 'Bobby',
      );

      await storage.updateUser(updatedUser);

      final loaded = await storage.readSession();
      expect(loaded, isNull);
    });

    test(
      'readSession clears all auth fields when user payload is corrupted',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_token': 'token-bad',
          'auth_user': '{bad json',
          'auth_refresh_token': 'refresh-bad',
        });

        final loaded = await storage.readSession();
        final prefs = await SharedPreferences.getInstance();

        expect(loaded, isNull);
        expect(prefs.getString('auth_token'), isNull);
        expect(prefs.getString('auth_user'), isNull);
        expect(prefs.getString('auth_refresh_token'), isNull);
      },
    );
  });
}
