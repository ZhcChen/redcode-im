import 'package:flutter/material.dart';

enum HomeSection { chat, contact, settings }

extension HomeSectionX on HomeSection {
  String get label {
    switch (this) {
      case HomeSection.chat:
        return '聊天';
      case HomeSection.contact:
        return '联系人';
      case HomeSection.settings:
        return '设置';
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
