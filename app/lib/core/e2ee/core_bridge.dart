import 'dart:typed_data';

import 'package:redcode_e2ee_core/redcode_e2ee_core.dart';

const _supportedProtocolVersion = 1;

class E2eeCoreUnavailableException implements Exception {
  const E2eeCoreUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class E2eeProtocolCore {
  Uint8List newProtocolState();
  bool validateProtocolState(List<int> state);
}

final class NativeE2eeProtocolCore implements E2eeProtocolCore {
  NativeE2eeProtocolCore({RedcodeE2eeCore core = const RedcodeE2eeCore()})
    : _core = core {
    if (_core.protocolVersion != _supportedProtocolVersion) {
      throw E2eeCoreUnavailableException(
        '不支持的 E2EE 核心版本：${_core.protocolVersion}',
      );
    }
  }

  final RedcodeE2eeCore _core;

  @override
  Uint8List newProtocolState() => _core.newProtocolState();

  @override
  bool validateProtocolState(List<int> state) =>
      _core.validateProtocolState(state);
}
