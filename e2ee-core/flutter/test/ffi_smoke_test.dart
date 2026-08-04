import 'package:flutter_test/flutter_test.dart';
import 'package:redcode_e2ee_core/redcode_e2ee_core.dart';

void main() {
  test('Flutter can load the shared core and read its protocol version', () {
    expect(const RedcodeE2eeCore().protocolVersion, 1);
  });

  test('Flutter can validate opaque protocol state through the C ABI', () {
    const core = RedcodeE2eeCore();
    final state = core.newProtocolState();
    expect(state.sublist(0, 4), [0x52, 0x43, 0x53, 0x54]);
    expect(core.validateProtocolState(state), isTrue);
    state[0] = 0;
    expect(core.validateProtocolState(state), isFalse);
  });
}
