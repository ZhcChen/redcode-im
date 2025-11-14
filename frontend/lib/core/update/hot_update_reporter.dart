import 'dart:convert';

import 'package:http/http.dart' as http;

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
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/versions/hot-update/report');
    final body = <String, dynamic>{
      'platform': platform,
      'base_version': baseVersion,
      'patch_version': patchVersion,
      'event_type': eventType,
      if (channel != null && channel.isNotEmpty) 'channel': channel,
      if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
      if (message != null && message.isNotEmpty) 'message': message,
    };

    try {
      await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      // 静默失败，避免影响主流程
    }
  }
}
