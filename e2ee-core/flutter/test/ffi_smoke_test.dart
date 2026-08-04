import 'package:flutter_test/flutter_test.dart';
import 'package:redcode_e2ee_core/redcode_e2ee_core.dart';
import 'package:redcode_e2ee_core/redcode_e2ee_session.dart';

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

  test('Flutter can execute versioned commands through the C ABI', () {
    const core = RedcodeE2eeCore();
    final response = core.executeCommand('invalid'.codeUnits);

    expect(String.fromCharCodes(response.take(4)), 'RCCR');
    expect(response[6], 1);
  });

  test('Flutter exchanges a direct message through the shared MLS core', () {
    const session = RedcodeE2eeSession();
    final alice = session.initialize('alice-device-1');
    final bob = session.initialize('bob-device-1');
    final created = session.createGroup(alice.field(0), 'room-direct-1');
    final added = session.addMember(
      created.field(0),
      'room-direct-1',
      bob.field(1),
    );
    final joined = session.joinGroup(bob.field(0), added.field(2));
    final encrypted = session.encrypt(
      added.field(0),
      'room-direct-1',
      'hello from Flutter'.codeUnits,
    );
    final decrypted = session.decrypt(
      joined.field(0),
      'room-direct-1',
      encrypted.field(1),
    );

    expect(String.fromCharCodes(decrypted.field(1)), 'hello from Flutter');
    expect(decrypted.epoch(2), 1);
  });
}
