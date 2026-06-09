import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

class FeedbackServiceException implements Exception {
  FeedbackServiceException(this.message);

  final String message;

  @override
  String toString() => 'FeedbackServiceException: $message';
}

class FeedbackService {
  FeedbackService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<void> submitFeedback({
    required String content,
    String? contact,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw FeedbackServiceException('反馈内容不能为空');
    }

    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw FeedbackServiceException('用户未登录');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/feedbacks');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': trimmedContent,
        if (contact != null && contact.trim().isNotEmpty)
          'contact': contact.trim(),
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    final message = _extractErrorMessage(response.body);
    throw FeedbackServiceException(message ?? '反馈提交失败');
  }

  String? _extractErrorMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
