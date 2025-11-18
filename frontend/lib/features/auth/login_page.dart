import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/agreement_content_dialog.dart';
import '../../core/widgets/agreement_tip_dialog.dart';
import '../home/home_shell_page.dart';
import 'data/auth_repository.dart';

enum LoginType { password, sms, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.appName = ''});

  final String appName;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginType _type = LoginType.password;
  bool _agreed = false;
  bool _loading = false;
  int _smsCountdown = 0;
  bool _sendingCode = false;
  Timer? _smsTimer;
  bool _requireCaptchaForLogin = false;

  final AuthRepository _authRepository = AuthRepository();
  final SettingsService _settingsService = SettingsService();

  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _smsCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 设置状态栏颜色与背景图上边缘一致
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFCAF6F3),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _loadCaptchaSetting();
  }

  Future<void> _loadCaptchaSetting() async {
    try {
      final requireCaptcha = await _settingsService.fetchRequireCaptchaForLogin();
      if (mounted) {
        setState(() {
          _requireCaptchaForLogin = requireCaptcha;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值 false
    }
  }

  @override
  void dispose() {
    _smsTimer?.cancel();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _smsCtrl.dispose();
    _emailCtrl.dispose();
    // 恢复默认状态栏样式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  String get _submitText => _type == LoginType.register ? '注册账号' : '登录账号';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFCAF6F3),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: SafeArea(
          top: false, // 禁用顶部 SafeArea，让背景图延伸到状态栏
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景图
              Positioned.fill(
                child: SvgPicture.asset(
                  AppAssets.loginBackground,
                  fit: BoxFit.cover,
                ),
              ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                bottom: 32.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 48.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      '你好！',
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.appName.isNotEmpty ? '欢迎来到 ${widget.appName}' : '欢迎',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.textBlack,
                          ),
                        ),
                        SvgPicture.asset(AppAssets.loginTitle, height: 24.h),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildLoginCard(context),
                  ),
                ],
              ),
            ),
            if (_loading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final borderRadius = BorderRadius.circular(28.r);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          _buildTypeSelector(borderRadius),
          Padding(
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: _type == LoginType.register ? 24.h : 40.h,
              bottom: 32.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('手机号'),
                SizedBox(height: 12.h),
                _buildField(
                  controller: _mobileCtrl,
                  hint: '请输入手机号',
                  keyboardType: TextInputType.phone,
                  enabled: !_loading,
                ),
                if (_type == LoginType.password) ...[
                  SizedBox(height: 24.h),
                  _buildLabel('密码'),
                  SizedBox(height: 12.h),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: '请输入登录密码',
                    obscureText: true,
                    enabled: !_loading,
                  ),
                ],
                // 根据设置显示验证码输入：登录时如果开启验证码则显示，注册时如果开启验证码则显示，短信登录始终显示
                if ((_type == LoginType.password && _requireCaptchaForLogin) ||
                    (_type == LoginType.register && _requireCaptchaForLogin) ||
                    _type == LoginType.sms) ...[
                  SizedBox(height: 24.h),
                  _buildLabel('验证码'),
                  SizedBox(height: 12.h),
                  _buildField(
                    controller: _smsCtrl,
                    hint: '请输入验证码',
                    keyboardType: TextInputType.number,
                    suffix: _buildSmsAction(),
                    enabled: !_loading,
                  ),
                ],
                if (_type == LoginType.register) ...[
                  SizedBox(height: 24.h),
                  _buildLabel('设置密码'),
                  SizedBox(height: 12.h),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: '请设置您的登陆密码',
                    obscureText: true,
                    enabled: !_loading,
                  ),
                ],
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(
                    _submitText,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
                SizedBox(height: 24.h),
                _buildAgreeRow(),
                SizedBox(height: 48.h),
                _buildSwitchRow(),
                if (_type != LoginType.register) ...[
                  SizedBox(height: 12.h),
                  Center(
                    child: Text(
                      '忘记密码',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(BorderRadius radius) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: radius.topLeft,
        topRight: radius.topRight,
      ),
      child: Container(
        color: const Color(0xFFF3F7F8),
        height: 72.h,
        child: Row(
          children: _type == LoginType.register
              ? [_buildTypeButton(LoginType.register, '注册')]
              : [
                  _buildTypeButton(LoginType.password, '密码登录'),
                  // 如果关闭了登录/注册验证码，则隐藏验证码登录 tab
                  if (_requireCaptchaForLogin)
                    _buildTypeButton(LoginType.sms, '验证码登录'),
                ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(LoginType type, String label) {
    final isActive = _type == type;
    final isLeft = type == LoginType.password || type == LoginType.register;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isLeft ? 28.r : 0),
      topRight: Radius.circular(isLeft ? 0 : 28.r),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 72.h,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textBlack,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              SizedBox(height: 8.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4.h,
                width: isActive ? 32.w : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14.sp,
          color: AppColors.textSecondary,
        ),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(maxHeight: 48),
      ),
    );
  }

  Widget _buildSmsAction() {
    final disabled = _loading || _sendingCode || _smsCountdown > 0;
    final label = _smsCountdown > 0 ? '${_smsCountdown}s' : '获取验证码';
    return TextButton(
      onPressed: disabled ? null : _requestSmsCode,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFDDDDDD),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      child: _sendingCode
          ? SizedBox(
              height: 16.h,
              width: 16.w,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
            ),
    );
  }

  Future<void> _requestSmsCode() async {
    final phone = _mobileCtrl.text.trim();
    if (phone.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    if (_sendingCode || _smsCountdown > 0) {
      return;
    }

    setState(() => _sendingCode = true);
    try {
      await _authRepository.sendSmsCode(phone);
      if (mounted) {
        _showMessage('验证码已发送');
        _startSmsCountdown();
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('发送验证码失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      } else {
        _sendingCode = false;
      }
    }
  }

  void _startSmsCountdown([int seconds = 60]) {
    _smsTimer?.cancel();
    setState(() => _smsCountdown = seconds);
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_smsCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _smsCountdown = 0);
        }
      } else if (mounted) {
        setState(() => _smsCountdown -= 1);
      }
    });
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 12.sp),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          color: AppColors.textBlack,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAgreeRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 14.sp,
            height: 14.sp,
            child: _agreed
                ? SvgPicture.asset(
                    AppAssets.loginCheckboxSelected,
                    width: 14.sp,
                    height: 14.sp,
                  )
                : Container(
                    width: 14.sp,
                    height: 14.sp,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      height: 12.sp,
                      width: 12.sp,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textTertiary,
                ),
                children: [
                  const TextSpan(text: '注册/登陆即代表同意'),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _showUserAgreement(),
                      child: const Text(
                        '《用户协议》',
                        style: TextStyle(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '和'),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _showPrivacyAgreement(),
                      child: const Text(
                        '《隐私协议》',
                        style: TextStyle(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow() {
    final isRegister = _type == LoginType.register;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRegister ? '已有账号' : '新用户',
          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
        ),
        SizedBox(width: 4.w),
        GestureDetector(
          onTap: () => setState(() {
            _type = isRegister ? LoginType.password : LoginType.register;
          }),
          child: Text(
            isRegister ? '立即登录' : '立即注册',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }

    if (AppConfig.useMockData) {
      final phone = _mobileCtrl.text.trim().isEmpty
          ? '13800138000'
          : _mobileCtrl.text.trim();
      final password = _passwordCtrl.text.isEmpty
          ? 'mock-pass'
          : _passwordCtrl.text;
      final email = _emailCtrl.text.trim().isEmpty
          ? '$phone@example.com'
          : _emailCtrl.text.trim();
      final code = _smsCtrl.text.trim().isEmpty
          ? '123456'
          : _smsCtrl.text.trim();

      FocusScope.of(context).unfocus();
      setState(() => _loading = true);
      try {
        if (_type == LoginType.register) {
          await _authRepository.register(
            username: phone,
            email: email,
            password: password,
          );
          await _authRepository.login(username: phone, password: password);
        } else if (_type == LoginType.sms) {
          await _authRepository.loginWithSms(phone: phone, code: code);
        } else {
          await _authRepository.login(username: phone, password: password);
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShellPage()),
          (route) => false,
        );
        return;
      } on AuthException catch (error) {
        _showMessage(error.message);
      } catch (_) {
        _showMessage('网络异常，请稍后重试');
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        } else {
          _loading = false;
        }
      }
    }

    if (!_agreed) {
      await AgreementTipDialog.show(
        context,
        content: '请勾选并阅读《用户协议》和《隐私协议》，勾选默认代表用户阅读并接受本平台协议。',
        onConfirm: () {
          Navigator.of(context).pop();
          setState(() => _agreed = true);
        },
      );
      return;
    }

    if (_type == LoginType.register) {
      await _handleRegister();
      return;
    }

    // 如果关闭了登录/注册验证码，不允许验证码登录
    if (_type == LoginType.sms) {
      if (!_requireCaptchaForLogin) {
        _showMessage('验证码登录功能已关闭，请使用密码登录');
        return;
      }
      await _handleSmsLogin();
      return;
    }

    await _handlePasswordLogin();
  }

  Future<void> _handleRegister() async {
    final username = _mobileCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('请填写完整的注册信息');
      return;
    }

    // 如果开启验证码，需要验证码
    if (_requireCaptchaForLogin) {
      final code = _smsCtrl.text.trim();
      if (code.isEmpty) {
        _showMessage('请输入验证码');
        return;
      }
    }

    // 邮箱自动生成：手机号 + @example.com
    final email = '$username@example.com';

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.register(
        username: username,
        email: email,
        password: password,
      );
      await _authRepository.login(username: username, password: password);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShellPage()),
        (route) => false,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('网络异常，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
    }
  }

  Future<void> _handleSmsLogin() async {
    final phone = _mobileCtrl.text.trim();
    final code = _smsCtrl.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      _showMessage('请输入手机号和验证码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final success = await _attemptSmsLogin(phone, code);
      if (!mounted) {
        return;
      }

      if (success) {
        _smsTimer?.cancel();
        setState(() => _smsCountdown = 0);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShellPage()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
    }
  }

  Future<bool> _attemptSmsLogin(String phone, String code) async {
    try {
      await _authRepository.loginWithSms(phone: phone, code: code);
      return true;
    } on AuthException catch (error) {
      if (_isAccountMissingError(error.message)) {
        return _autoRegisterAndLogin(phone, code);
      }
      _showMessage(error.message);
    } catch (_) {
      _showMessage('验证码登录失败，请稍后重试');
    }
    return false;
  }

  bool _isAccountMissingError(String message) {
    return message.contains('用户不存在') || message.contains('未注册');
  }

  Future<bool> _autoRegisterAndLogin(String phone, String code) async {
    // 邮箱自动生成：手机号 + @example.com
    final email = '$phone@example.com';
    final password = _buildAutoRegisterPassword(phone);

    try {
      await _authRepository.register(
        username: phone,
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      if (_isUserAlreadyExistsError(error.message)) {
        // 忽略该错误，后续直接重试登录
      } else {
        _showMessage(error.message);
        return false;
      }
    } catch (_) {
      _showMessage('自动注册失败，请稍后重试');
      return false;
    }

    try {
      await _authRepository.loginWithSms(phone: phone, code: code);
      return true;
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('验证码登录失败，请稍后重试');
    }
    return false;
  }

  bool _isUserAlreadyExistsError(String message) {
    return message.contains('已被使用') || message.contains('已存在');
  }

  String _buildAutoRegisterEmail(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final localPart = normalized.isEmpty
        ? 'user${DateTime.now().millisecondsSinceEpoch}'
        : normalized;
    return '$localPart@auto.redcode-im';
  }

  String _buildAutoRegisterPassword(String phone) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final random = Random();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    if (digits.isNotEmpty) {
      buffer.write(
        digits.length >= 4 ? digits.substring(0, 4) : digits.padRight(4, '0'),
      );
    } else {
      buffer.write('rcim');
    }

    for (var i = 0; i < 6; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }

  Future<void> _handlePasswordLogin() async {
    final username = _mobileCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('请输入完整的账号和密码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.login(username: username, password: password);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShellPage()),
        (route) => false,
      );
    } on AuthException catch (error) {
      debugPrint('[LoginPage] AuthException: ${error.message}');
      _showMessage(error.message);
    } catch (e, stackTrace) {
      debugPrint('[LoginPage] 未知异常: $e');
      debugPrint('[LoginPage] 异常类型: ${e.runtimeType}');
      debugPrint('[LoginPage] 堆栈跟踪: $stackTrace');
      _showMessage('网络异常，请稍后重试：${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 显示用户协议
  Future<void> _showUserAgreement() async {
    try {
      final document = await _settingsService.fetchUserAgreement();
      if (!mounted) return;
      await AgreementContentDialog.show(
        context,
        title: document.title.isNotEmpty ? document.title : '用户协议',
        htmlContent: document.content,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('加载用户协议失败，请稍后重试');
    }
  }

  /// 显示隐私协议
  Future<void> _showPrivacyAgreement() async {
    try {
      final document = await _settingsService.fetchPrivacyPolicy();
      if (!mounted) return;
      await AgreementContentDialog.show(
        context,
        title: document.title.isNotEmpty ? document.title : '隐私协议',
        htmlContent: document.content,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('加载隐私协议失败，请稍后重试');
    }
  }
}
