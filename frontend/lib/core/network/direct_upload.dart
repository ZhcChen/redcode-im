import 'package:http/http.dart' as http;

/// 直传签名信息
class DirectUploadSignature {
  DirectUploadSignature({
    required this.url,
    required this.method,
    required Map<String, String> headers,
  }) : headers = Map.unmodifiable(
          headers.map((key, value) => MapEntry(key, value)),
        );

  final String url;
  final String method;
  final Map<String, String> headers;

  factory DirectUploadSignature.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw const FormatException('直传签名缺少上传地址');
    }

    final method = ((json['method'] as String?) ?? 'PUT').isEmpty
        ? 'PUT'
        : (json['method'] as String).toUpperCase();

    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key is String && value is String) {
          headers[key] = value;
        }
      });
    }

    return DirectUploadSignature(url: rawUrl, method: method, headers: headers);
  }

  /// 将签名头部附着在请求上
  void applyHeaders(http.BaseRequest request, {String? defaultContentType}) {
    headers.forEach((key, value) {
      request.headers[key] = value;
    });
    if (defaultContentType != null && defaultContentType.isNotEmpty) {
      request.headers.putIfAbsent('Content-Type', () => defaultContentType);
    }
  }
}
