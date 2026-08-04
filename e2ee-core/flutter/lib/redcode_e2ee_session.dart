import 'dart:convert';
import 'dart:typed_data';

import 'redcode_e2ee_core.dart';

enum E2eeCommandOperation {
  initialize(1),
  generateKeyPackage(2),
  createGroup(3),
  addMember(4),
  joinGroup(5),
  encrypt(6),
  decrypt(7),
  publicMaterial(8),
  processCommit(9);

  const E2eeCommandOperation(this.value);
  final int value;
}

class E2eeCommandException implements Exception {
  const E2eeCommandException(this.message);
  final String message;

  @override
  String toString() => message;
}

class E2eeCommandResult {
  const E2eeCommandResult(this.fields);
  final List<Uint8List> fields;

  Uint8List field(int index) {
    if (index < 0 || index >= fields.length) {
      throw const E2eeCommandException('E2EE 核心响应字段缺失');
    }
    return fields[index];
  }

  int epoch(int index) {
    final value = field(index);
    if (value.length != 8) {
      throw const E2eeCommandException('E2EE 核心 epoch 格式无效');
    }
    return ByteData.sublistView(value).getUint64(0, Endian.big);
  }
}

class RedcodeE2eeSession {
  const RedcodeE2eeSession({RedcodeE2eeCore core = const RedcodeE2eeCore()})
    : _core = core;

  final RedcodeE2eeCore _core;

  E2eeCommandResult execute(
    E2eeCommandOperation operation,
    List<List<int>> fields,
  ) {
    if (fields.length > 8) {
      throw const E2eeCommandException('E2EE 核心命令字段过多');
    }
    final request = BytesBuilder(copy: false)
      ..add(ascii.encode('RCCQ'))
      ..add([0, 1, operation.value, fields.length]);
    for (final field in fields) {
      if (field.length > 0xffffffff) {
        throw const E2eeCommandException('E2EE 核心命令字段过大');
      }
      final length = ByteData(4)..setUint32(0, field.length, Endian.big);
      request
        ..add(length.buffer.asUint8List())
        ..add(field);
    }
    return decodeResponse(_core.executeCommand(request.takeBytes()));
  }

  E2eeCommandResult initialize(
    String deviceIdentity, {
    List<int>? rootPublicKey,
  }) => execute(E2eeCommandOperation.initialize, [
    utf8.encode(deviceIdentity),
    if (rootPublicKey != null) rootPublicKey,
  ]);

  E2eeCommandResult createGroup(List<int> state, String roomId) =>
      execute(E2eeCommandOperation.createGroup, [state, utf8.encode(roomId)]);

  E2eeCommandResult addMember(
    List<int> state,
    String roomId,
    List<int> keyPackage,
  ) => execute(E2eeCommandOperation.addMember, [
    state,
    utf8.encode(roomId),
    keyPackage,
  ]);

  E2eeCommandResult joinGroup(List<int> state, List<int> welcome) =>
      execute(E2eeCommandOperation.joinGroup, [state, welcome]);

  E2eeCommandResult encrypt(
    List<int> state,
    String roomId,
    List<int> plaintext,
  ) => execute(E2eeCommandOperation.encrypt, [
    state,
    utf8.encode(roomId),
    plaintext,
  ]);

  E2eeCommandResult decrypt(
    List<int> state,
    String roomId,
    List<int> ciphertext,
  ) => execute(E2eeCommandOperation.decrypt, [
    state,
    utf8.encode(roomId),
    ciphertext,
  ]);

  E2eeCommandResult publicMaterial(List<int> state) =>
      execute(E2eeCommandOperation.publicMaterial, [state]);

  E2eeCommandResult processCommit(
    List<int> state,
    String roomId,
    List<int> commit,
  ) => execute(E2eeCommandOperation.processCommit, [
    state,
    utf8.encode(roomId),
    commit,
  ]);

  static E2eeCommandResult decodeResponse(List<int> response) {
    if (response.length < 8 || ascii.decode(response.sublist(0, 4)) != 'RCCR') {
      throw const E2eeCommandException('E2EE 核心响应头无效');
    }
    if (response[4] != 0 || response[5] != 1) {
      throw const E2eeCommandException('E2EE 核心响应版本不支持');
    }
    final status = response[6];
    final fieldCount = response[7];
    var offset = 8;
    final fields = <Uint8List>[];
    for (var index = 0; index < fieldCount; index++) {
      if (offset + 4 > response.length) {
        throw const E2eeCommandException('E2EE 核心响应已截断');
      }
      final length = ByteData.sublistView(
        Uint8List.fromList(response),
        offset,
        offset + 4,
      ).getUint32(0, Endian.big);
      offset += 4;
      if (offset + length > response.length) {
        throw const E2eeCommandException('E2EE 核心响应已截断');
      }
      fields.add(Uint8List.fromList(response.sublist(offset, offset + length)));
      offset += length;
    }
    if (offset != response.length) {
      throw const E2eeCommandException('E2EE 核心响应包含多余数据');
    }
    if (status != 0) {
      final message = fields.isEmpty
          ? 'E2EE 核心命令失败'
          : utf8.decode(fields.first, allowMalformed: true);
      throw E2eeCommandException(message);
    }
    return E2eeCommandResult(List.unmodifiable(fields));
  }
}
