import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHost() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginPage(initialRequireCaptchaForLogin: true),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_agreed_to_terms': true});
  });

  testWidgets('账号注册不显示验证码输入，即使开启验证码登录', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildHost());
    await tester.pumpAndSettle();

    expect(find.text('验证码'), findsOneWidget);

    await tester.tap(find.text('立即注册'));
    await tester.pumpAndSettle();

    expect(find.text('注册账号'), findsOneWidget);
    expect(find.text('设置密码'), findsOneWidget);
    expect(find.text('验证码'), findsNothing);
    expect(find.text('获取验证码'), findsNothing);
  });
}
