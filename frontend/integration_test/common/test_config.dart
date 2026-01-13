/// E2E 测试配置
///
/// 包含测试账号、服务器地址等配置信息

class TestConfig {
  TestConfig._();

  /// 测试服务器地址
  static const String baseUrl = 'http://localhost:3000';

  /// 测试账号 - 普通用户
  static const TestAccount testUser = TestAccount(
    mobile: '13800138000',
    password: 'Test123456',
    nickname: '测试用户',
  );

  /// 测试账号 - 第二个用户（用于好友、聊天测试）
  static const TestAccount testUser2 = TestAccount(
    mobile: '13800138001',
    password: 'Test123456',
    nickname: '测试用户2',
  );

  /// 测试超时时间
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// 等待元素出现的超时时间
  static const Duration waitTimeout = Duration(seconds: 10);
}

/// 测试账号模型
class TestAccount {
  const TestAccount({
    required this.mobile,
    required this.password,
    required this.nickname,
  });

  final String mobile;
  final String password;
  final String nickname;
}
