import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:integration_test/integration_test.dart';

const bool _enableRealAuthIntegration = bool.fromEnvironment(
  'ENABLE_REAL_AUTH_INTEGRATION',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'flutter app integration auth: account register and password login',
    (tester) async {
      final storage = TokenStorage();
      await storage.clear();

      final repository = AuthRepository(storage: storage);
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final account = 'flutter$timestamp'.substring(0, 20);
      const password = 'pass123456';

      final registered = await repository.register(
        account: account,
        password: password,
      );
      expect(registered.email, endsWith('@account.redcode.local'));
      expect(registered.username, account);
      expect(registered.status, 'active');

      final session = await repository.login(
        account: account,
        password: password,
      );
      expect(session.token, isNotEmpty);
      expect(session.refreshToken, isNotEmpty);
      expect(session.user.email, registered.email);
      expect(session.user.username, account);

      final savedSession = await storage.readSession();
      expect(savedSession, isNotNull);
      expect(savedSession!.token, session.token);
      expect(savedSession.refreshToken, session.refreshToken);
      expect(savedSession.user.email, registered.email);

      final refreshed = await repository.refreshCurrentUser();
      expect(refreshed, isNotNull);
      expect(refreshed!.email, registered.email);
      expect(refreshed.username, account);

      await repository.logout();
      expect(await storage.readSession(), isNull);
    },
    skip: !_enableRealAuthIntegration,
  );
}
