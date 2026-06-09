import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('patrol harness smoke', ($) async {
    debugPrint('harness: before pumpWidget');
    await $.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: Text('harness-ok')))));
    debugPrint('harness: after pumpWidget');
    await $.pump(const Duration(milliseconds: 300));
    debugPrint('harness: after pump');
    expect($('harness-ok'), findsOneWidget);
    debugPrint('harness: after expect');
  });
}
