import 'package:app/core/routing/app_route.dart';
import 'package:app/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route contract keeps stable names and source-aware fallback', () {
    expect(AppRoutePath.home, '/home');
    expect(AppRoutePath.chat, '/chat');
    expect(AppRoutePath.friendRequests, '/friend-requests');

    const request = AppRouteRequest(
      path: AppRoutePath.chat,
      source: AppRouteSource.push,
      fallbackPath: AppRoutePath.home,
    );
    expect(request.source, AppRouteSource.push);
    expect(request.fallbackPath, AppRoutePath.home);
  });

  test('incomplete direct chat link falls back to home', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutePath.chat,
        arguments: AppRouteRequest(
          path: AppRoutePath.chat,
          source: AppRouteSource.deepLink,
          fallbackPath: AppRoutePath.home,
        ),
      ),
    );

    expect(route, isNotNull);
    expect(route!.settings.name, AppRoutePath.home);
  });

  test('unknown route falls back to home', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: '/unknown'),
    );

    expect(route, isNotNull);
    expect(route!.settings.name, AppRoutePath.home);
  });
}
