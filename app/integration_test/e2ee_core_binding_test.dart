import 'package:app/core/e2ee/core_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shared E2EE core loads and validates protocol state', (
    tester,
  ) async {
    final core = NativeE2eeProtocolCore();
    final state = core.newProtocolState();

    expect(state.sublist(0, 4), [0x52, 0x43, 0x53, 0x54]);
    expect(core.validateProtocolState(state), isTrue);

    state[0] = 0;
    expect(core.validateProtocolState(state), isFalse);
  });
}
