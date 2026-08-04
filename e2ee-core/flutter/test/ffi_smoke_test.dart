import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

typedef _ProtocolVersionNative = Uint16 Function();
typedef _ProtocolVersionDart = int Function();

void main() {
  test('Flutter can load the shared core and read its protocol version', () {
    final libraryPath = Platform.environment['E2EE_CORE_LIBRARY'];
    expect(libraryPath, isNotNull, reason: 'E2EE_CORE_LIBRARY must be set');

    final library = DynamicLibrary.open(libraryPath!);
    final protocolVersion = library.lookupFunction<
      _ProtocolVersionNative,
      _ProtocolVersionDart
    >('rc_e2ee_protocol_version');

    expect(protocolVersion(), 1);
  });
}
