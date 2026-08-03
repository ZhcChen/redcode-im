import 'package:flutter/widgets.dart';

class AppLifecycleRecovery {
  AppLifecycleRecovery({required Future<void> Function() onResume})
    : _onResume = onResume;

  final Future<void> Function() _onResume;
  bool _leftForeground = false;
  Future<void>? _activeRecovery;

  void handleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leftForeground = true;
        break;
      case AppLifecycleState.resumed:
        if (!_leftForeground) return;
        _leftForeground = false;
        _activeRecovery ??= _onResume().whenComplete(() {
          _activeRecovery = null;
        });
      case AppLifecycleState.inactive:
        break;
    }
  }
}
