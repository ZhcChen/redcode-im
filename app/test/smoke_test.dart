import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/environment.dart';

void main() {
  test('frontend unit smoke: environment has api/ws defaults', () {
    expect(EnvironmentConfig.apiBaseUrl, isNotEmpty);
    expect(EnvironmentConfig.wsUrl, isNotEmpty);
  });
}
