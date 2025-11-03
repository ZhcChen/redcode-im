import 'package:flutter/material.dart';

enum HomeSection { chat, contact, settings, privacy }

extension HomeSectionX on HomeSection {
  String get label {
    switch (this) {
      case HomeSection.chat:
        return '会话';
      case HomeSection.contact:
        return '联系人';
      case HomeSection.settings:
        return '设置';
      case HomeSection.privacy:
        return '隐私';
    }
  }

  IconData get icon {
    switch (this) {
      case HomeSection.chat:
        return Icons.chat_bubble_outline_rounded;
      case HomeSection.contact:
        return Icons.people_outline_rounded;
      case HomeSection.settings:
        return Icons.settings_outlined;
      case HomeSection.privacy:
        return Icons.verified_user_outlined;
    }
  }
}

class HomeState extends ChangeNotifier {
  HomeSection _currentSection = HomeSection.chat;

  HomeSection get currentSection => _currentSection;

  void select(HomeSection section) {
    if (_currentSection == section) return;
    _currentSection = section;
    notifyListeners();
  }
}
