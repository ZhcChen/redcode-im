import 'package:flutter/foundation.dart';

import '../../features/auth/models/auth_user.dart';
import '../../features/contacts/models/friend_models.dart';

/// 全局好友状态存储（首屏 HTTP，全局增量由 WS 驱动）
class FriendStore with ChangeNotifier {
  FriendStore._internal();

  static FriendStore? _instance;
  static FriendStore get instance => _instance ??= FriendStore._internal();

  final Map<String, FriendInfo> _byUserId = {};
  int _pendingIncoming = 0;
  String? _version;

  List<FriendInfo> get friends => _byUserId.values.toList(growable: false);
  int get pendingIncoming => _pendingIncoming;
  String? get version => _version;

  void setFriends(List<FriendInfo> list, {String? version}) {
    _byUserId
      ..clear()
      ..addEntries(list.map((f) => MapEntry(f.user.id, f)));
    if (version != null) _version = version;
    notifyListeners();
  }

  void upsertFriend(FriendInfo friend) {
    _byUserId[friend.user.id] = friend;
    notifyListeners();
  }

  void removeFriendByUserId(String userId) {
    if (_byUserId.remove(userId) != null) notifyListeners();
  }

  void setPendingIncoming(int count) {
    final c = count < 0 ? 0 : count;
    if (_pendingIncoming != c) {
      _pendingIncoming = c;
      notifyListeners();
    }
  }

  /// 清空好友与待处理计数（用于登出/切换账号）
  void clearAll() {
    _byUserId.clear();
    _pendingIncoming = 0;
    _version = null;
    notifyListeners();
  }

  /// 以最少字段更新好友资料
  void updateFriendProfile({
    required String userId,
    String? username,
    String? nickname,
    String? avatarUrl,
  }) {
    final existing = _byUserId[userId];
    if (existing == null) return;
    final u = existing.user;
    final updated = AuthUser(
      id: u.id,
      username: username ?? u.username,
      email: u.email,
      nickname: nickname ?? u.nickname,
      avatarUrl: avatarUrl ?? u.avatarUrl,
      status: u.status,
    );
    _byUserId[userId] = FriendInfo(
      id: existing.id,
      user: updated,
      createdAt: existing.createdAt,
    );
    notifyListeners();
  }
}
