import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _trustRegistryVersion = 1;
const _securityCodeDomain = 'redcode-im/e2ee/security-code/v1\u0000';

class E2eeRootIdentity {
  const E2eeRootIdentity({
    required this.userId,
    required this.publicKey,
    required this.fingerprint,
    required this.protocolVersion,
  });

  final String userId;
  final Uint8List publicKey;
  final Uint8List fingerprint;
  final int protocolVersion;

  Map<String, Object> toJson() => {
    'user_id': userId,
    'public_key': base64Encode(publicKey),
    'fingerprint': base64Encode(fingerprint),
    'protocol_version': protocolVersion,
  };

  factory E2eeRootIdentity.fromJson(Map<String, dynamic> json) {
    return E2eeRootIdentity(
      userId: json['user_id'] as String,
      publicKey: base64Decode(json['public_key'] as String),
      fingerprint: base64Decode(json['fingerprint'] as String),
      protocolVersion: json['protocol_version'] as int,
    );
  }
}

class E2eeIdentityTrustRecord {
  const E2eeIdentityTrustRecord({
    required this.trusted,
    required this.trustedAt,
    this.pending,
    this.changedAt,
  });

  final E2eeRootIdentity trusted;
  final DateTime trustedAt;
  final E2eeRootIdentity? pending;
  final DateTime? changedAt;

  bool get isChanged => pending != null;

  Map<String, Object?> toJson() => {
    'trusted': trusted.toJson(),
    'trusted_at': trustedAt.toUtc().toIso8601String(),
    'pending': pending?.toJson(),
    'changed_at': changedAt?.toUtc().toIso8601String(),
  };

  factory E2eeIdentityTrustRecord.fromJson(Map<String, dynamic> json) {
    final pending = json['pending'];
    return E2eeIdentityTrustRecord(
      trusted: E2eeRootIdentity.fromJson(
        (json['trusted'] as Map).cast<String, dynamic>(),
      ),
      trustedAt: DateTime.parse(json['trusted_at'] as String).toUtc(),
      pending: pending == null
          ? null
          : E2eeRootIdentity.fromJson((pending as Map).cast<String, dynamic>()),
      changedAt: json['changed_at'] == null
          ? null
          : DateTime.parse(json['changed_at'] as String).toUtc(),
    );
  }
}

enum E2eeIdentityTrustDecision { firstUseTrusted, trusted, identityChanged }

class E2eeIdentityNotTrustedException implements Exception {
  const E2eeIdentityNotTrustedException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class E2eeIdentityTrustStore {
  Future<Map<String, E2eeIdentityTrustRecord>> readRecords(String accountId);
  Future<void> writeRecords(
    String accountId,
    Map<String, E2eeIdentityTrustRecord> records,
  );
  Future<void> deleteRecords(String accountId);
}

class E2eeIdentityTrustManager {
  E2eeIdentityTrustManager({
    required E2eeIdentityTrustStore store,
    DateTime Function()? now,
  }) : _store = store,
       _now = now ?? DateTime.now;

  final E2eeIdentityTrustStore _store;
  final DateTime Function() _now;

  Future<E2eeIdentityTrustDecision> observe(
    String accountId,
    E2eeRootIdentity identity,
  ) async {
    _validateIdentity(identity);
    final records = await _store.readRecords(accountId);
    final existing = records[identity.userId];
    if (existing == null) {
      records[identity.userId] = E2eeIdentityTrustRecord(
        trusted: identity,
        trustedAt: _now().toUtc(),
      );
      await _store.writeRecords(accountId, records);
      return E2eeIdentityTrustDecision.firstUseTrusted;
    }
    if (_sameIdentity(existing.trusted, identity)) {
      return E2eeIdentityTrustDecision.trusted;
    }
    records[identity.userId] = E2eeIdentityTrustRecord(
      trusted: existing.trusted,
      trustedAt: existing.trustedAt,
      pending: identity,
      changedAt: existing.changedAt ?? _now().toUtc(),
    );
    await _store.writeRecords(accountId, records);
    return E2eeIdentityTrustDecision.identityChanged;
  }

  Future<E2eeIdentityTrustRecord?> record(
    String accountId,
    String targetUserId,
  ) async => (await _store.readRecords(accountId))[targetUserId];

  Future<E2eeIdentityTrustRecord> requireTrusted(
    String accountId,
    String targetUserId,
  ) async {
    final existing = await record(accountId, targetUserId);
    if (existing == null) {
      throw const E2eeIdentityNotTrustedException('联系人 E2EE 身份尚未验证');
    }
    if (existing.isChanged) {
      throw const E2eeIdentityNotTrustedException('联系人 E2EE 身份已变化，核验安全码后才能发送');
    }
    return existing;
  }

  Future<E2eeIdentityTrustRecord> retrust(
    String accountId,
    String targetUserId,
  ) async {
    final records = await _store.readRecords(accountId);
    final existing = records[targetUserId];
    if (existing?.pending == null) {
      throw StateError('没有待确认的 E2EE 身份变化');
    }
    final accepted = E2eeIdentityTrustRecord(
      trusted: existing!.pending!,
      trustedAt: _now().toUtc(),
    );
    records[targetUserId] = accepted;
    await _store.writeRecords(accountId, records);
    return accepted;
  }

  static String securityCode(E2eeRootIdentity first, E2eeRootIdentity second) {
    _validateIdentity(first);
    _validateIdentity(second);
    final identities = [first, second]
      ..sort((left, right) => left.userId.compareTo(right.userId));
    final input = BytesBuilder(copy: false)
      ..add(utf8.encode(_securityCodeDomain));
    for (final identity in identities) {
      _addLengthPrefixed(input, utf8.encode(identity.userId));
      _addLengthPrefixed(input, identity.fingerprint);
    }
    final hex = sha256.convert(input.takeBytes()).toString().toUpperCase();
    return [
      for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join(' ');
  }

  static Uint8List encodeRegistry(
    Map<String, E2eeIdentityTrustRecord> records,
  ) {
    final sorted = records.keys.toList()..sort();
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': _trustRegistryVersion,
          'records': {for (final key in sorted) key: records[key]!.toJson()},
        }),
      ),
    );
  }

  static Map<String, E2eeIdentityTrustRecord> decodeRegistry(List<int> data) {
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _trustRegistryVersion ||
        decoded['records'] is! Map) {
      throw const FormatException('E2EE 信任记录格式无效');
    }
    return (decoded['records'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        E2eeIdentityTrustRecord.fromJson(
          (value as Map).cast<String, dynamic>(),
        ),
      ),
    );
  }

  static bool _sameIdentity(E2eeRootIdentity left, E2eeRootIdentity right) =>
      left.userId == right.userId &&
      left.protocolVersion == right.protocolVersion &&
      _bytesEqual(left.publicKey, right.publicKey) &&
      _bytesEqual(left.fingerprint, right.fingerprint);

  static void _validateIdentity(E2eeRootIdentity identity) {
    if (identity.userId.trim().isEmpty ||
        identity.publicKey.isEmpty ||
        identity.fingerprint.length < 16 ||
        identity.protocolVersion != 1) {
      throw const FormatException('E2EE 根身份无效');
    }
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }

  static void _addLengthPrefixed(BytesBuilder output, List<int> value) {
    if (value.length > 0xffff) throw const FormatException('安全码字段过长');
    output.add([(value.length >> 8) & 0xff, value.length & 0xff]);
    output.add(value);
  }
}
