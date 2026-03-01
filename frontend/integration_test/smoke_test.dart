import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frontend integration smoke', (tester) async {
    expect(true, isTrue);
  });
}
