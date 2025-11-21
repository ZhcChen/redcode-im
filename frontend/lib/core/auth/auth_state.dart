import 'dart:async';

/// 全局认证状态
enum AuthState { authenticated, unauthenticated }

/// 全局认证状态事件总线，确保多处使用同一份流
class AuthStateBus {
  AuthStateBus._();

  static final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  static Stream<AuthState> get stream => _controller.stream;

  static void emit(AuthState state) {
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }
}
