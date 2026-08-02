import 'package:flutter/material.dart';

import '../../features/chat/chat_detail_page_v2.dart';
import '../../features/chat/models/chat_model.dart';
import '../../features/contacts/add_friend_page.dart';
import '../../features/home/home_shell_page.dart';
import '../auth/auth_guard.dart';
import '../services/friend_store.dart';
import 'app_route.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@immutable
class ChatRouteArguments {
  const ChatRouteArguments({
    required this.roomId,
    required this.chatName,
    required this.chatType,
    this.initialMessageId,
  });

  final String roomId;
  final String chatName;
  final ChatType chatType;
  final String? initialMessageId;
}

abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final request = settings.arguments is AppRouteRequest
        ? settings.arguments! as AppRouteRequest
        : AppRouteRequest(path: settings.name ?? AppRoutePath.root);
    final routeSettings = RouteSettings(name: request.path, arguments: request);

    switch (request.path) {
      case AppRoutePath.home:
        return MaterialPageRoute<void>(
          settings: routeSettings,
          builder: (_) => AuthGuard(childBuilder: (_) => const HomeShellPage()),
        );
      case AppRoutePath.chat:
        final arguments = request.arguments;
        if (arguments is ChatRouteArguments && arguments.roomId.isNotEmpty) {
          return MaterialPageRoute<void>(
            settings: routeSettings,
            builder: (_) => ChatDetailPageV2(
              roomId: arguments.roomId,
              chatName: arguments.chatName,
              chatType: arguments.chatType,
              initialMessageId: arguments.initialMessageId,
            ),
          );
        }
        return _fallbackRoute(request);
      case AppRoutePath.friendRequests:
        return MaterialPageRoute<void>(
          settings: routeSettings,
          builder: (_) => AddFriendPage(
            existingFriendIds: FriendStore.instance.friends
                .map((friend) => friend.user.id)
                .toSet(),
            showRequestsFirst: true,
          ),
        );
      default:
        return _fallbackRoute(request);
    }
  }

  static Future<T?> open<T>(
    BuildContext context,
    AppRouteRequest request, {
    bool replace = false,
  }) {
    if (replace) {
      return Navigator.of(
        context,
      ).pushReplacementNamed<T, Object?>(request.path, arguments: request);
    }
    return Navigator.of(context).pushNamed<T>(request.path, arguments: request);
  }

  static void popOrFallback(BuildContext context, AppRouteRequest request) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(
      request.fallbackPath ?? AppRoutePath.home,
      arguments: AppRouteRequest(
        path: request.fallbackPath ?? AppRoutePath.home,
      ),
    );
  }

  static Route<void> _fallbackRoute(AppRouteRequest request) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutePath.home),
      builder: (_) => AuthGuard(childBuilder: (_) => const HomeShellPage()),
    );
  }
}
