import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/environment.dart';

void main() {
  test('flutter app unit smoke: environment has api/ws defaults', () {
    expect(EnvironmentConfig.apiBaseUrl, isNotEmpty);
    expect(EnvironmentConfig.wsUrl, isNotEmpty);

    final apiUri = Uri.parse(EnvironmentConfig.apiBaseUrl);
    final wsUri = Uri.parse(EnvironmentConfig.wsUrl);
    expect(apiUri.hasScheme, isTrue);
    expect(wsUri.hasScheme, isTrue);
    expect(apiUri.scheme, isIn(const ['http', 'https']));
    expect(wsUri.scheme, isIn(const ['ws', 'wss']));
  });
}
