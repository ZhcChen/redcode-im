import 'package:desktop_flutter/features/home/sections/chat_section.dart';
import 'package:desktop_flutter/features/home/sections/contact_section.dart';
import 'package:desktop_flutter/features/home/sections/settings_section.dart';
import 'package:desktop_flutter/features/home/widgets/side_menu.dart';
import 'package:desktop_flutter/state/app_state.dart';
import 'package:desktop_flutter/state/home_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeState(),
      child: Consumer2<HomeState, AppState>(
        builder: (context, homeState, appState, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F4F5),
            body: SafeArea(
              child: Row(
                children: [
                  SideMenu(
                    currentSection: homeState.currentSection,
                    onSectionSelected: homeState.select,
                    onOpenSettings: () => homeState.select(HomeSection.settings),
                    onLogout: context.read<AppState>().logout,
                    user: appState.currentUser,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildSection(homeState.currentSection),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(HomeSection section) {
    switch (section) {
      case HomeSection.chat:
        return const ChatSection();
      case HomeSection.contact:
        return const ContactSection();
      case HomeSection.settings:
        return const SettingsSection();
    }
  }
}
