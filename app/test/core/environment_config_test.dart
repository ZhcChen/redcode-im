import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/environment.dart';

void main() {
  group('EnvironmentConfig (default compile-time)', () {
    test('uses development env when ENV is not provided', () {
      expect(EnvironmentConfig.current, Environment.development);
      expect(EnvironmentConfig.isDevelopment, isTrue);
      expect(EnvironmentConfig.isStaging, isFalse);
      expect(EnvironmentConfig.isProduction, isFalse);
    });

    test(
      'api/ws default to development endpoints without dart-define override',
      () {
        expect(EnvironmentConfig.apiBaseUrl, EnvironmentConfig.devApiBaseUrl);
        expect(EnvironmentConfig.wsUrl, EnvironmentConfig.devWsUrl);
        expect(EnvironmentConfig.apiBaseUrl, startsWith('http'));
        expect(EnvironmentConfig.wsUrl, startsWith('ws'));
      },
    );

    test('envName and flags are consistent', () {
      expect(EnvironmentConfig.envName, '开发环境');
      expect(EnvironmentConfig.enableDebugLog, isTrue);
      expect(EnvironmentConfig.enablePerformanceMonitor, isTrue);
      expect(EnvironmentConfig.useMockData, isFalse);
    });
  });
}
