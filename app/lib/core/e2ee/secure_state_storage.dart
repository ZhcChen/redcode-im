import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core_bridge.dart';

const _stateMagic = [0x52, 0x43, 0x45, 0x53]; // RCES
const _stateVersion = 1;
const _nonceLength = 12;
const _macLength = 16;
const _keyLength = 32;
const _aadPrefix = 'redcode-im/e2ee-state/v1\u0000';

class E2eeStateCorruptedException implements Exception {
  const E2eeStateCorruptedException([this.message = 'E2EE 协议状态已损坏或无法解密']);

  final String message;

  @override
  String toString() => message;
}

abstract interface class E2eeWrappingKeyStore {
  Future<List<int>?> read(String key);
  Future<void> write(String key, List<int> value);
  Future<void> delete(String key);
}

abstract interface class E2eeEncryptedStateStore {
  Future<List<int>?> read(String accountNamespace);
  Future<void> write(String accountNamespace, List<int> value);
  Future<void> delete(String accountNamespace);
}

class FlutterSecureWrappingKeyStore implements E2eeWrappingKeyStore {
  const FlutterSecureWrappingKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<List<int>?> read(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw const E2eeStateCorruptedException('E2EE wrapping key 格式无效');
    }
  }

  @override
  Future<void> write(String key, List<int> value) =>
      _storage.write(key: key, value: base64Encode(value));

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class FileE2eeEncryptedStateStore implements E2eeEncryptedStateStore {
  const FileE2eeEncryptedStateStore();

  Future<File> _file(String namespace) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'e2ee-state'));
    await directory.create(recursive: true);
    return File(p.join(directory.path, '$namespace.bin'));
  }

  @override
  Future<List<int>?> read(String accountNamespace) async {
    final file = await _file(accountNamespace);
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String accountNamespace, List<int> value) async {
    final file = await _file(accountNamespace);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(value, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(String accountNamespace) async {
    final file = await _file(accountNamespace);
    if (file.existsSync()) await file.delete();
  }
}

class E2eeSecureStateStorage {
  E2eeSecureStateStorage({
    E2eeWrappingKeyStore? wrappingKeys,
    E2eeEncryptedStateStore? encryptedStates,
    Cipher? cipher,
    E2eeProtocolCore? protocolCore,
  }) : _wrappingKeys = wrappingKeys ?? const FlutterSecureWrappingKeyStore(),
       _encryptedStates =
           encryptedStates ?? const FileE2eeEncryptedStateStore(),
       _cipher = cipher ?? AesGcm.with256bits(),
       _protocolCore = protocolCore ?? NativeE2eeProtocolCore();

  final E2eeWrappingKeyStore _wrappingKeys;
  final E2eeEncryptedStateStore _encryptedStates;
  final Cipher _cipher;
  final E2eeProtocolCore _protocolCore;

  Uint8List newProtocolState() => _protocolCore.newProtocolState();

  Future<void> write(String accountId, List<int> state) async {
    if (!_protocolCore.validateProtocolState(state)) {
      throw const E2eeStateCorruptedException('E2EE 协议状态格式无效');
    }
    final namespace = _namespace(accountId);
    final keyName = _keyName(namespace);
    var keyBytes = await _wrappingKeys.read(keyName);
    if (keyBytes == null) {
      keyBytes = await (await _cipher.newSecretKey()).extractBytes();
      await _wrappingKeys.write(keyName, keyBytes);
    }
    if (keyBytes.length != _keyLength) {
      throw const E2eeStateCorruptedException('E2EE wrapping key 长度无效');
    }

    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      state,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
      aad: _associatedData(accountId),
    );
    final encoded = <int>[
      ..._stateMagic,
      _stateVersion,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
    await _encryptedStates.write(namespace, encoded);
  }

  Future<Uint8List?> read(String accountId) async {
    final namespace = _namespace(accountId);
    final encoded = await _encryptedStates.read(namespace);
    if (encoded == null) return null;
    final keyBytes = await _wrappingKeys.read(_keyName(namespace));
    if (keyBytes == null || keyBytes.length != _keyLength) {
      throw const E2eeStateCorruptedException();
    }
    if (encoded.length < _stateMagic.length + 1 + _nonceLength + _macLength ||
        !_hasMagic(encoded) ||
        encoded[_stateMagic.length] != _stateVersion) {
      throw const E2eeStateCorruptedException();
    }

    final nonceStart = _stateMagic.length + 1;
    final macStart = nonceStart + _nonceLength;
    final ciphertextStart = macStart + _macLength;
    final box = SecretBox(
      encoded.sublist(ciphertextStart),
      nonce: encoded.sublist(nonceStart, macStart),
      mac: Mac(encoded.sublist(macStart, ciphertextStart)),
    );
    try {
      final plaintext = await _cipher.decrypt(
        box,
        secretKey: SecretKey(keyBytes),
        aad: _associatedData(accountId),
      );
      if (!_protocolCore.validateProtocolState(plaintext)) {
        throw const E2eeStateCorruptedException('E2EE 协议状态格式无效');
      }
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const E2eeStateCorruptedException();
    }
  }

  Future<void> delete(String accountId) async {
    final namespace = _namespace(accountId);
    await _wrappingKeys.delete(_keyName(namespace));
    await _encryptedStates.delete(namespace);
  }

  static String _namespace(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw const E2eeStateCorruptedException('E2EE 账号标识不能为空');
    }
    return hashes.sha256.convert(utf8.encode(normalized)).toString();
  }

  static String _keyName(String namespace) =>
      'redcode.e2ee.wrapping-key.$namespace';

  static List<int> _associatedData(String accountId) =>
      utf8.encode('$_aadPrefix${accountId.trim()}');

  static bool _hasMagic(List<int> value) {
    for (var index = 0; index < _stateMagic.length; index++) {
      if (value[index] != _stateMagic[index]) return false;
    }
    return true;
  }
}
