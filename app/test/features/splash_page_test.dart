import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/startup/splash_page.dart';
import 'package:app/features/startup/startup_session_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSplash(SplashPage page) {
    return MaterialApp(theme: AppTheme.light, home: page);
  }

  testWidgets('shows retry state for offline session and retries once', (
    tester,
  ) async {
    var sessionAttempts = 0;
    var versionChecks = 0;
    var hotUpdateInitializations = 0;

    await tester.pumpWidget(
      buildSplash(
        SplashPage(
          minimumDisplayDuration: Duration.zero,
          appNameLoader: () async => 'RedCode IM',
          versionGate: () async {
            versionChecks += 1;
            return true;
          },
          hotUpdateInitializer: () async {
            hotUpdateInitializations += 1;
          },
          sessionResolver: () async {
            sessionAttempts += 1;
            return StartupSessionResult.retry;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时无法连接服务器'), findsOneWidget);
    expect(find.text('已保留登录状态，请检查网络后重试。'), findsOneWidget);
    expect(sessionAttempts, 1);

    await tester.tap(find.text('重新连接'));
    await tester.pumpAndSettle();

    expect(sessionAttempts, 2);
    expect(versionChecks, 1);
    expect(hotUpdateInitializations, 1);
  });

  testWidgets('hot update initialization failure does not block auth check', (
    tester,
  ) async {
    var sessionResolved = false;

    await tester.pumpWidget(
      buildSplash(
        SplashPage(
          minimumDisplayDuration: Duration.zero,
          appNameLoader: () async => '',
          versionGate: () async => true,
          hotUpdateInitializer: () async => throw Exception('unavailable'),
          sessionResolver: () async {
            sessionResolved = true;
            return StartupSessionResult.retry;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(sessionResolved, isTrue);
    expect(find.text('重新连接'), findsOneWidget);
  });
}
