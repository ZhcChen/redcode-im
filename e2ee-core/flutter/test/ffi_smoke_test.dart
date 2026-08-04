import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _ProtocolVersionNative = Uint16 Function();
typedef _ProtocolVersionDart = int Function();
typedef _StateValidateNative = Int32 Function(Pointer<Uint8>, IntPtr);
typedef _StateValidateDart = int Function(Pointer<Uint8>, int);
typedef _StateNewNative = IntPtr Function(Pointer<Uint8>, IntPtr);
typedef _StateNewDart = int Function(Pointer<Uint8>, int);

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

  test('Flutter can validate opaque protocol state through the C ABI', () {
    final libraryPath = Platform.environment['E2EE_CORE_LIBRARY'];
    expect(libraryPath, isNotNull, reason: 'E2EE_CORE_LIBRARY must be set');

    final library = DynamicLibrary.open(libraryPath!);
    final validate = library.lookupFunction<
      _StateValidateNative,
      _StateValidateDart
    >('rc_e2ee_state_validate');
    final create = library.lookupFunction<_StateNewNative, _StateNewDart>(
      'rc_e2ee_state_new',
    );
    final required = create(nullptr, 0);
    final buffer = calloc<Uint8>(required);
    try {
      expect(create(buffer, required), required);
      final valid = Uint8List.fromList(buffer.asTypedList(required));
      expect(valid.sublist(0, 4), [0x52, 0x43, 0x53, 0x54]);
      expect(validate(buffer, required), 1);
      buffer[0] = 0;
      expect(validate(buffer, required), 0);
    } finally {
      calloc.free(buffer);
    }
  });
}
