import 'package:desktop_flutter/features/auth/widgets/login_form.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 960;
          return Row(
            children: [
              if (isWide)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1F2A56), Color(0xFF3A68FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Redcode IM',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '统一移动与桌面端体验，在桌面端继续享受即时沟通。',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: 4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: const LoginForm(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
