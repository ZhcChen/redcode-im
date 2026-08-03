import 'package:app/core/services/permission_service.dart';
import 'package:app/core/widgets/permission_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway({
    required this.current,
    this.requested = AppPermissionStatus.denied,
  });

  AppPermissionStatus current;
  AppPermissionStatus requested;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async => current;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requestCalls += 1;
    current = requested;
    return requested;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls += 1;
    return true;
  }
}

class _ThrowingPermissionGateway implements PermissionGateway {
  @override
  Future<bool> openSettings() => throw StateError('settings unavailable');

  @override
  Future<AppPermissionStatus> request(AppPermission permission) =>
      throw StateError('request unavailable');

  @override
  Future<AppPermissionStatus> status(AppPermission permission) =>
      throw StateError('status unavailable');
}

void main() {
  group('PermissionService', () {
    test('已授权时不重复请求', () async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.granted,
      );
      final service = PermissionService(gateway: gateway);

      final result = await service.ensure(AppPermission.camera);

      expect(result, PermissionAccess.granted);
      expect(gateway.requestCalls, 0);
    });

    test('首次拒绝后再次请求可以恢复', () async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.denied,
        requested: AppPermissionStatus.granted,
      );
      final service = PermissionService(gateway: gateway);

      final result = await service.ensure(AppPermission.microphone);

      expect(result, PermissionAccess.granted);
      expect(gateway.requestCalls, 1);
    });

    test('相册 limited 状态允许继续', () async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.limited,
      );
      final service = PermissionService(gateway: gateway);

      expect(
        await service.ensure(AppPermission.photos),
        PermissionAccess.granted,
      );
      expect(gateway.requestCalls, 0);
    });

    test('永久拒绝要求前往设置且不重复弹系统请求', () async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.permanentlyDenied,
      );
      final service = PermissionService(gateway: gateway);

      expect(
        await service.ensure(AppPermission.camera),
        PermissionAccess.settingsRequired,
      );
      expect(gateway.requestCalls, 0);
      expect(await service.openSettings(), isTrue);
      expect(gateway.openSettingsCalls, 1);
    });

    test('系统受限状态不可请求', () async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.restricted,
      );
      final service = PermissionService(gateway: gateway);

      expect(
        await service.ensure(AppPermission.microphone),
        PermissionAccess.unavailable,
      );
      expect(gateway.requestCalls, 0);
    });

    test('平台通道异常时降级为不可用', () async {
      final service = PermissionService(gateway: _ThrowingPermissionGateway());

      expect(
        await service.ensure(AppPermission.notification),
        PermissionAccess.unavailable,
      );
      expect(await service.openSettings(), isFalse);
    });
  });

  group('ensureAppPermission', () {
    testWidgets('永久拒绝时提供前往设置入口', (tester) async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.permanentlyDenied,
      );
      final service = PermissionService(gateway: gateway);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ensureAppPermission(
                  context,
                  AppPermission.camera,
                  service: service,
                ),
                child: const Text('拍照'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(find.text('前往设置'), findsOneWidget);
      await tester.tap(find.text('前往设置'));
      await tester.pumpAndSettle();
      expect(gateway.openSettingsCalls, 1);
    });

    testWidgets('普通拒绝保留再次触发能力', (tester) async {
      final gateway = _FakePermissionGateway(
        current: AppPermissionStatus.denied,
        requested: AppPermissionStatus.denied,
      );
      final service = PermissionService(gateway: gateway);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ensureAppPermission(
                  context,
                  AppPermission.microphone,
                  service: service,
                ),
                child: const Text('录音'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('录音'));
      await tester.pumpAndSettle();

      expect(find.text('未授予麦克风权限，可再次操作重新授权'), findsOneWidget);
      expect(gateway.requestCalls, 1);
    });
  });
}
