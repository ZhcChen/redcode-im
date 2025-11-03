import 'dart:async';

import 'package:flutter/material.dart';

class LoadingState {
  const LoadingState({this.isLoading = false, this.message});

  final bool isLoading;
  final String? message;

  LoadingState copyWith({bool? isLoading, String? message}) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
    );
  }
}

class UserProfile {
  const UserProfile({required this.displayName, required this.mobile});

  final String displayName;
  final String mobile;
}

class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  LoadingState _loadingState = const LoadingState();
  UserProfile? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  LoadingState get loadingState => _loadingState;
  UserProfile? get currentUser => _currentUser;

  Future<void> login({required String mobile, required String password}) async {
    _setLoading(true, message: '登录中...');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    _currentUser = UserProfile(
      displayName: '桌面端用户',
      mobile: mobile,
    );
    _isAuthenticated = true;

    _setLoading(false);
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool isLoading, {String? message}) {
    _loadingState = _loadingState.copyWith(
      isLoading: isLoading,
      message: message,
    );
    notifyListeners();
  }
}
