// This is a generated file - do not edit.
//
// Generated from ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class PubSubPriority extends $pb.ProtobufEnum {
  static const PubSubPriority PUBSUB_PRIORITY_UNKNOWN =
      PubSubPriority._(0, _omitEnumNames ? '' : 'PUBSUB_PRIORITY_UNKNOWN');
  static const PubSubPriority PUBSUB_PRIORITY_CRITICAL =
      PubSubPriority._(1, _omitEnumNames ? '' : 'PUBSUB_PRIORITY_CRITICAL');
  static const PubSubPriority PUBSUB_PRIORITY_HIGH =
      PubSubPriority._(2, _omitEnumNames ? '' : 'PUBSUB_PRIORITY_HIGH');
  static const PubSubPriority PUBSUB_PRIORITY_NORMAL =
      PubSubPriority._(3, _omitEnumNames ? '' : 'PUBSUB_PRIORITY_NORMAL');
  static const PubSubPriority PUBSUB_PRIORITY_LOW =
      PubSubPriority._(4, _omitEnumNames ? '' : 'PUBSUB_PRIORITY_LOW');

  static const $core.List<PubSubPriority> values = <PubSubPriority>[
    PUBSUB_PRIORITY_UNKNOWN,
    PUBSUB_PRIORITY_CRITICAL,
    PUBSUB_PRIORITY_HIGH,
    PUBSUB_PRIORITY_NORMAL,
    PUBSUB_PRIORITY_LOW,
  ];

  static final $core.List<PubSubPriority?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static PubSubPriority? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PubSubPriority._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
