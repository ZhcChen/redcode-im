import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermission { photos, camera, microphone, notification }

enum AppPermissionStatus {
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

enum PermissionAccess { granted, denied, settingsRequired, unavailable }

abstract interface class PermissionGateway {
  Future<AppPermissionStatus> status(AppPermission permission);

  Future<AppPermissionStatus> request(AppPermission permission);

  Future<bool> openSettings();
}

class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  ph.Permission _resolve(AppPermission permission) => switch (permission) {
    AppPermission.photos => ph.Permission.photos,
    AppPermission.camera => ph.Permission.camera,
    AppPermission.microphone => ph.Permission.microphone,
    AppPermission.notification => ph.Permission.notification,
  };

  AppPermissionStatus _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isProvisional) {
      return AppPermissionStatus.granted;
    }
    if (status.isLimited) return AppPermissionStatus.limited;
    if (status.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) return AppPermissionStatus.restricted;
    if (status.isDenied) return AppPermissionStatus.denied;
    return AppPermissionStatus.unavailable;
  }

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async {
    return _map(await _resolve(permission).status);
  }

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    return _map(await _resolve(permission).request());
  }

  @override
  Future<bool> openSettings() => ph.openAppSettings();
}

class PermissionService {
  PermissionService({PermissionGateway? gateway})
    : _gateway = gateway ?? const PermissionHandlerGateway();

  static final PermissionService instance = PermissionService();

  final PermissionGateway _gateway;

  Future<PermissionAccess> ensure(AppPermission permission) async {
    try {
      var status = await _gateway.status(permission);
      if (status == AppPermissionStatus.denied) {
        status = await _gateway.request(permission);
      }
      return switch (status) {
        AppPermissionStatus.granted ||
        AppPermissionStatus.limited => PermissionAccess.granted,
        AppPermissionStatus.denied => PermissionAccess.denied,
        AppPermissionStatus.permanentlyDenied =>
          PermissionAccess.settingsRequired,
        AppPermissionStatus.restricted ||
        AppPermissionStatus.unavailable => PermissionAccess.unavailable,
      };
    } catch (_) {
      return PermissionAccess.unavailable;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _gateway.openSettings();
    } catch (_) {
      return false;
    }
  }
}
