import 'dart:convert';
import 'dart:typed_data';

const _profileVersion = 1;

class E2eeDeviceProfile {
  const E2eeDeviceProfile({
    required this.deviceId,
    required this.deviceLabel,
    required this.registered,
    required this.keyPackagePublished,
    this.lastControlSequences = const {},
  });

  final String deviceId;
  final String deviceLabel;
  final bool registered;
  final bool keyPackagePublished;
  final Map<String, int> lastControlSequences;

  E2eeDeviceProfile copyWith({
    bool? registered,
    bool? keyPackagePublished,
    Map<String, int>? lastControlSequences,
  }) => E2eeDeviceProfile(
    deviceId: deviceId,
    deviceLabel: deviceLabel,
    registered: registered ?? this.registered,
    keyPackagePublished: keyPackagePublished ?? this.keyPackagePublished,
    lastControlSequences: lastControlSequences ?? this.lastControlSequences,
  );

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': _profileVersion,
        'device_id': deviceId,
        'device_label': deviceLabel,
        'registered': registered,
        'key_package_published': keyPackagePublished,
        'last_control_sequences': lastControlSequences,
      }),
    ),
  );

  static E2eeDeviceProfile decode(List<int> value) {
    final data = jsonDecode(utf8.decode(value));
    if (data is! Map<String, dynamic> ||
        data['version'] != _profileVersion ||
        data['device_id'] is! String ||
        (data['device_id'] as String).trim().isEmpty ||
        data['device_label'] is! String ||
        data['registered'] is! bool ||
        data['key_package_published'] is! bool ||
        data['last_control_sequences'] is! Map) {
      throw const FormatException('E2EE 设备档案格式无效');
    }
    final sequences = (data['last_control_sequences'] as Map).map((key, value) {
      if (key is! String || value is! int || value < 0) {
        throw const FormatException('E2EE 控制消息游标无效');
      }
      return MapEntry(key, value);
    });
    return E2eeDeviceProfile(
      deviceId: data['device_id'] as String,
      deviceLabel: data['device_label'] as String,
      registered: data['registered'] as bool,
      keyPackagePublished: data['key_package_published'] as bool,
      lastControlSequences: Map.unmodifiable(sequences),
    );
  }
}
