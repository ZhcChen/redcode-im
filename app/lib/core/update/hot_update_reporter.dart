import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../constants/app_config.dart';

class HotUpdateReporter {
  HotUpdateReporter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> reportEvent({
    required String platform,
    required String baseVersion,
    required String patchVersion,
    required String eventType,
    String? channel,
    String? clientId,
    String? message,
    int? buildNumber,
    String? triggerSource,
  }) async {
    try {
      // 收集客户端详细信息
      final clientDetails = await _collectClientDetails();

      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/versions/hot-update-events',
      );
      final body = <String, dynamic>{
        'platform': platform,
        'base_version': baseVersion,
        'patch_version': patchVersion,
        'event_type': eventType,
        'client_type': 'frontend', // 移动端固定为frontend
        if (channel != null && channel.isNotEmpty) 'channel': channel,
        if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
        if (message != null && message.isNotEmpty) 'message': message,
        if (buildNumber != null) 'build_number': buildNumber,
        if (triggerSource != null && triggerSource.isNotEmpty)
          'trigger_source': triggerSource,
        ...clientDetails, // 展开客户端详细信息
      };

      await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (error) {
      // 静默失败，避免影响主流程
    }
  }

  Future<Map<String, dynamic>> _collectClientDetails() async {
    final details = <String, dynamic>{};

    try {
      // 操作系统信息
      if (Platform.isAndroid) {
        details['os_version'] = 'Android ${Platform.operatingSystemVersion}';
        details['os_arch'] = Platform.version.contains('arm64')
            ? 'arm64'
            : 'arm';
        details['app_arch'] = Platform.version.contains('arm64')
            ? 'arm64'
            : 'arm';
      } else if (Platform.isIOS) {
        details['os_version'] = 'iOS ${Platform.operatingSystemVersion}';
        details['os_arch'] = Platform.version.contains('arm64')
            ? 'arm64'
            : 'arm64'; // iOS通常是arm64
        details['app_arch'] = 'arm64';
      } else {
        details['os_version'] = Platform.operatingSystem;
        details['os_arch'] = 'unknown';
        details['app_arch'] = 'unknown';
      }

      // 网络类型
      final connectivityResult = await Connectivity().checkConnectivity();
      switch (connectivityResult) {
        case ConnectivityResult.mobile:
          details['network_type'] = 'cellular';
          break;
        case ConnectivityResult.wifi:
          details['network_type'] = 'wifi';
          break;
        case ConnectivityResult.ethernet:
          details['network_type'] = 'ethernet';
          break;
        default:
          details['network_type'] = 'unknown';
      }

      // 设备信息
      final deviceInfo = DeviceInfoPlugin();
      final deviceInfoList = <String>[];

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceInfoList.addAll([
          'brand:${androidInfo.brand}',
          'model:${androidInfo.model}',
          'androidVersion:${androidInfo.version.release}',
          'apiLevel:${androidInfo.version.sdkInt}',
        ]);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceInfoList.addAll([
          'model:${iosInfo.model}',
          'systemVersion:${iosInfo.systemVersion}',
          'localizedModel:${iosInfo.localizedModel}',
        ]);
      }

      if (deviceInfoList.isNotEmpty) {
        details['device_info'] = deviceInfoList.join(',');
      }
    } catch (error) {
      // 如果收集设备信息失败，使用基本信息
      details['device_info'] = 'collection_failed:$error';
    }

    return details;
  }
}
