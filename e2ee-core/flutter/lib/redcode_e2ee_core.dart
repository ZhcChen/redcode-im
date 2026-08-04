import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const _assetId = 'package:redcode_e2ee_core/redcode_e2ee_core';

@Native<Uint16 Function()>(
  symbol: 'rc_e2ee_protocol_version',
  assetId: _assetId,
  isLeaf: true,
)
external int _protocolVersion();

@Native<IntPtr Function(Pointer<Uint8>, IntPtr)>(
  symbol: 'rc_e2ee_state_new',
  assetId: _assetId,
)
external int _stateNew(Pointer<Uint8> output, int capacity);

@Native<Int32 Function(Pointer<Uint8>, IntPtr)>(
  symbol: 'rc_e2ee_state_validate',
  assetId: _assetId,
  isLeaf: true,
)
external int _stateValidate(Pointer<Uint8> data, int length);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    IntPtr,
    Pointer<Pointer<Uint8>>,
    Pointer<IntPtr>,
  )
>(symbol: 'rc_e2ee_command_execute', assetId: _assetId)
external int _commandExecute(
  Pointer<Uint8> input,
  int inputLength,
  Pointer<Pointer<Uint8>> output,
  Pointer<IntPtr> outputLength,
);

@Native<Void Function(Pointer<Uint8>, IntPtr)>(
  symbol: 'rc_e2ee_command_free',
  assetId: _assetId,
)
external void _commandFree(Pointer<Uint8> output, int outputLength);

final class RedcodeE2eeCore {
  const RedcodeE2eeCore();

  int get protocolVersion => _protocolVersion();

  Uint8List newProtocolState() {
    final required = _stateNew(nullptr, 0);
    if (required <= 0) {
      throw StateError('E2EE core returned an invalid state size');
    }
    final buffer = calloc<Uint8>(required);
    try {
      final written = _stateNew(buffer, required);
      if (written != required) {
        throw StateError('E2EE core failed to initialize protocol state');
      }
      return Uint8List.fromList(buffer.asTypedList(written));
    } finally {
      buffer.asTypedList(required).fillRange(0, required, 0);
      calloc.free(buffer);
    }
  }

  bool validateProtocolState(List<int> state) {
    if (state.isEmpty) return false;
    final buffer = calloc<Uint8>(state.length);
    try {
      buffer.asTypedList(state.length).setAll(0, state);
      return _stateValidate(buffer, state.length) == 1;
    } finally {
      buffer.asTypedList(state.length).fillRange(0, state.length, 0);
      calloc.free(buffer);
    }
  }

  Uint8List executeCommand(List<int> command) {
    if (command.isEmpty) throw ArgumentError.value(command, 'command');
    final input = calloc<Uint8>(command.length);
    final output = calloc<Pointer<Uint8>>();
    final outputLength = calloc<IntPtr>();
    try {
      input.asTypedList(command.length).setAll(0, command);
      if (_commandExecute(input, command.length, output, outputLength) != 0 ||
          output.value == nullptr ||
          outputLength.value <= 0) {
        throw StateError('E2EE core command failed');
      }
      return Uint8List.fromList(output.value.asTypedList(outputLength.value));
    } finally {
      input.asTypedList(command.length).fillRange(0, command.length, 0);
      calloc.free(input);
      if (output.value != nullptr && outputLength.value > 0) {
        _commandFree(output.value, outputLength.value);
      }
      calloc.free(output);
      calloc.free(outputLength);
    }
  }
}
