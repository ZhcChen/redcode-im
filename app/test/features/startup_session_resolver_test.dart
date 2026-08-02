import 'dart:async';

import 'package:app/features/startup/startup_session_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupSessionResolver', () {
    test('routes to login when no local session exists', () async {
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => false,
        refreshSession: () async => true,
        clearInvalidSession: () async {},
      );

      expect(result, StartupSessionResult.login);
    });

    test('routes to home after a valid session refresh', () async {
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => true,
        refreshSession: () async => true,
        clearInvalidSession: () async {},
      );

      expect(result, StartupSessionResult.home);
    });

    test('clears explicitly rejected session and routes to login', () async {
      var cleared = false;
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => true,
        refreshSession: () => throw const StartupSessionRejected(),
        clearInvalidSession: () async => cleared = true,
      );

      expect(result, StartupSessionResult.login);
      expect(cleared, isTrue);
    });

    test('clears invalid refresh result and routes to login', () async {
      var cleared = false;
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => true,
        refreshSession: () async => false,
        clearInvalidSession: () async => cleared = true,
      );

      expect(result, StartupSessionResult.login);
      expect(cleared, isTrue);
    });

    test('exposes retry when an invalid session cannot be cleared', () async {
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => true,
        refreshSession: () => throw const StartupSessionRejected(),
        clearInvalidSession: () => throw Exception('storage unavailable'),
      );

      expect(result, StartupSessionResult.retry);
    });

    test('preserves local session on timeout and exposes retry', () async {
      var cleared = false;
      final result = await StartupSessionResolver.resolve(
        hasLocalSession: () async => true,
        refreshSession: () => throw TimeoutException('offline'),
        clearInvalidSession: () async => cleared = true,
      );

      expect(result, StartupSessionResult.retry);
      expect(cleared, isFalse);
    });

    test(
      'preserves local session on transport failure and exposes retry',
      () async {
        final result = await StartupSessionResolver.resolve(
          hasLocalSession: () async => true,
          refreshSession: () => throw Exception('network unavailable'),
          clearInvalidSession: () async {},
        );

        expect(result, StartupSessionResult.retry);
      },
    );
  });
}
