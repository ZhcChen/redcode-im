import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/environment.dart';

void main() {
  test('flutter app unit smoke: environment has api/ws defaults', () {
    expect(EnvironmentConfig.apiBaseUrl, isNotEmpty);
    expect(EnvironmentConfig.wsUrl, isNotEmpty);
  });
}
