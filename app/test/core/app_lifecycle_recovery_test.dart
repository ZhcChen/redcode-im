import 'dart:async';

import 'package:app/core/services/app_lifecycle_recovery.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('仅在离开前台后恢复，并合并并发恢复请求', () async {
    final recovery = Completer<void>();
    var calls = 0;
    final lifecycle = AppLifecycleRecovery(
      onResume: () {
        calls += 1;
        return recovery.future;
      },
    );

    lifecycle.handleState(AppLifecycleState.resumed);
    lifecycle.handleState(AppLifecycleState.inactive);
    lifecycle.handleState(AppLifecycleState.resumed);
    expect(calls, 0);

    lifecycle.handleState(AppLifecycleState.paused);
    lifecycle.handleState(AppLifecycleState.resumed);
    lifecycle.handleState(AppLifecycleState.hidden);
    lifecycle.handleState(AppLifecycleState.resumed);
    expect(calls, 1);

    recovery.complete();
    await recovery.future;
    await Future<void>.delayed(Duration.zero);

    lifecycle.handleState(AppLifecycleState.detached);
    lifecycle.handleState(AppLifecycleState.resumed);
    expect(calls, 2);
  });
}
