import 'package:desktop_flutter/core/theme/app_theme.dart';
import 'package:desktop_flutter/core/widgets/global_loading_overlay.dart';
import 'package:desktop_flutter/features/auth/login_page.dart';
import 'package:desktop_flutter/features/home/home_shell.dart';
import 'package:desktop_flutter/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DesktopFlutterApp extends StatelessWidget {
  const DesktopFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Redcode IM Desktop',
            theme: buildAppTheme(),
            home: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: appState.isAuthenticated
                      ? const HomeShell()
                      : const LoginPage(),
                ),
                GlobalLoadingOverlay(
                  visible: appState.loadingState.isLoading,
                  message: appState.loadingState.message,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
