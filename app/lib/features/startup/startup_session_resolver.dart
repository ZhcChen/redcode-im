enum StartupSessionResult { home, login, retry }

class StartupSessionRejected implements Exception {
  const StartupSessionRejected();
}

abstract final class StartupSessionResolver {
  static Future<StartupSessionResult> resolve({
    required Future<bool> Function() hasLocalSession,
    required Future<bool> Function() refreshSession,
    required Future<void> Function() clearInvalidSession,
  }) async {
    try {
      if (!await hasLocalSession()) {
        return StartupSessionResult.login;
      }

      final valid = await refreshSession();
      if (valid) {
        return StartupSessionResult.home;
      }
      await clearInvalidSession();
      return StartupSessionResult.login;
    } on StartupSessionRejected {
      try {
        await clearInvalidSession();
        return StartupSessionResult.login;
      } catch (_) {
        return StartupSessionResult.retry;
      }
    } catch (_) {
      return StartupSessionResult.retry;
    }
  }
}
