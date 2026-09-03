import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/admin/presentation/screens/admin_home_screen.dart';
import 'features/admin/presentation/screens/admin_login_screen.dart';
import 'shared/widgets/auth_gate.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'inDrive Entregas — Panel Admin',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: AuthGate(
        expectedRole: 'admin',
        loginBuilder: (_) => const AdminLoginScreen(),
        homeBuilder: (_) => const AdminHomeScreen(),
      ),
    );
  }
}
