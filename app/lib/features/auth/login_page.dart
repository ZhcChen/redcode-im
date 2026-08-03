import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/routing/app_route.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/agreement_content_dialog.dart';
import '../../core/widgets/agreement_tip_dialog.dart';
import 'data/auth_repository.dart';

enum LoginType { password, register }

bool _isValidAccount(String account) {
  return RegExp(r'^[a-z0-9._-]{3,20}$').hasMatch(account);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginType _type = LoginType.password;
  bool _agreed = false;
  bool _loading = false;
  String _appName = '';

  final AuthRepository _authRepository = AuthRepository();
  final SettingsService _settingsService = SettingsService();
  final AppConfigService _appConfigService = AppConfigService.instance;

  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

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
    _loadAppName();
    _loadAgreementState();
  }

  Future<void> _loadAppName() async {
    try {
      final appName = await _appConfigService.getAppName();
      if (mounted) {
        setState(() {
          _appName = appName;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值
    }
  }

  Future<void> _loadAgreementState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agreed = prefs.getBool('user_agreed_to_terms') ?? false;
      if (mounted) {
        setState(() {
          _agreed = agreed;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值 false
    }
  }

  Future<void> _saveAgreementState(bool agreed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_agreed_to_terms', agreed);
    } catch (_) {
      // 静默失败
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _appName.isNotEmpty ? '欢迎来到 $_appName' : '欢迎',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: AppColors.textBlack,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
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
                _buildLabel('账号'),
                SizedBox(height: 12.h),
                _buildField(
                  controller: _accountCtrl,
                  hint: '请输入账号',
                  keyboardType: TextInputType.text,
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
                  child: Text(_submitText, style: TextStyle(fontSize: 14.sp)),
                ),
                SizedBox(height: 24.h),
                _buildAgreeRow(),
                SizedBox(height: 48.h),
                _buildSwitchRow(),
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
        constraints: BoxConstraints(minHeight: 72.h),
        child: Row(
          children: _type == LoginType.register
              ? [_buildTypeButton(LoginType.register, '注册')]
              : [_buildTypeButton(LoginType.password, '密码登录')],
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
          constraints: BoxConstraints(minHeight: 72.h),
          padding: EdgeInsets.symmetric(vertical: 16.h),
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
      style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints: BoxConstraints(maxHeight: 44.h),
      ),
    );
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
      onTap: () {
        final newAgreed = !_agreed;
        setState(() => _agreed = newAgreed);
        _saveAgreementState(newAgreed);
      },
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
                      child: Text(
                        '《用户协议》',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '和'),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _showPrivacyAgreement(),
                      child: Text(
                        '《隐私协议》',
                        style: TextStyle(
                          fontSize: 11.sp,
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

    // 确保所有输入框失去焦点
    FocusScope.of(context).unfocus();

    if (AppConfig.useMockData) {
      final account = _accountCtrl.text.trim().isEmpty
          ? '13800138000'
          : _accountCtrl.text.trim();
      final password = _passwordCtrl.text.isEmpty
          ? 'mock-pass'
          : _passwordCtrl.text;
      FocusScope.of(context).unfocus();
      setState(() => _loading = true);
      try {
        if (_type == LoginType.register) {
          await _authRepository.register(account: account, password: password);
          await _authRepository.login(account: account, password: password);
        } else {
          await _authRepository.login(account: account, password: password);
        }
        if (!mounted) {
          return;
        }
        _openHome();
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
      // 取消所有输入框的焦点，避免弹窗关闭后自动聚焦
      FocusScope.of(context).unfocus();
      await AgreementTipDialog.show(
        context,
        content: '请勾选并阅读《用户协议》和《隐私协议》，勾选默认代表用户阅读并接受本平台协议。',
        onConfirm: () async {
          Navigator.of(context).pop();
          // 弹窗关闭后延迟取消焦点，确保UI完全重建后再取消
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            FocusScope.of(context).unfocus();
          }
        },
      );
      return;
    }

    if (_type == LoginType.register) {
      await _handleRegister();
      return;
    }

    await _handlePasswordLogin();
  }

  Future<void> _handleRegister() async {
    final account = _accountCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (account.isEmpty || password.isEmpty) {
      _showMessage('请填写完整的注册信息');
      return;
    }
    if (!_isValidAccount(account)) {
      _showMessage('账号需为 3-20 位字母、数字、点、下划线或短横线');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.register(account: account, password: password);
      await _authRepository.login(account: account, password: password);
      if (!mounted) {
        return;
      }

      _openHome();
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

  Future<void> _handlePasswordLogin() async {
    final account = _accountCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (account.isEmpty || password.isEmpty) {
      _showMessage('请输入完整的账号和密码');
      return;
    }
    if (!_isValidAccount(account)) {
      _showMessage('账号需为 3-20 位字母、数字、点、下划线或短横线');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.login(account: account, password: password);
      if (!mounted) {
        return;
      }

      _openHome();
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

  void _openHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutePath.home,
      (route) => false,
      arguments: const AppRouteRequest(path: AppRoutePath.home),
    );
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
