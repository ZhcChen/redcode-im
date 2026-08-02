import 'package:flutter/foundation.dart';

abstract final class AppRoutePath {
  static const root = '/';
  static const home = '/home';
  static const chat = '/chat';
  static const friendRequests = '/friend-requests';
}

enum AppRouteSource { inApp, deepLink, push }

@immutable
class AppRouteRequest {
  const AppRouteRequest({
    required this.path,
    this.source = AppRouteSource.inApp,
    this.fallbackPath,
    this.arguments,
  });

  final String path;
  final AppRouteSource source;
  final String? fallbackPath;
  final Object? arguments;
}
