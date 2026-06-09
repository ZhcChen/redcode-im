import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:integration_test/integration_test.dart';

const bool _enableRealAuthIntegration = bool.fromEnvironment(
  'ENABLE_REAL_AUTH_INTEGRATION',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'frontend integration auth: email register and password login',
    (tester) async {
      final storage = TokenStorage();
      await storage.clear();

      final repository = AuthRepository(storage: storage);
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'frontend-auth-$timestamp@example.test';
      const password = 'pass123456';

      final registered = await repository.register(
        email: email,
        password: password,
      );
      expect(registered.email, email);
      expect(registered.username, email);
      expect(registered.status, 'active');

      final session = await repository.login(email: email, password: password);
      expect(session.token, isNotEmpty);
      expect(session.refreshToken, isNotEmpty);
      expect(session.user.email, email);
      expect(session.user.username, email);

      final savedSession = await storage.readSession();
      expect(savedSession, isNotNull);
      expect(savedSession!.token, session.token);
      expect(savedSession.refreshToken, session.refreshToken);
      expect(savedSession.user.email, email);

      final refreshed = await repository.refreshCurrentUser();
      expect(refreshed, isNotNull);
      expect(refreshed!.email, email);

      await repository.logout();
      expect(await storage.readSession(), isNull);
    },
    skip: !_enableRealAuthIntegration,
  );
}
