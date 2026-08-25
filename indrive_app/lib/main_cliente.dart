import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/cliente/presentation/screens/cliente_home_screen.dart';
import 'features/cliente/presentation/screens/cliente_login_screen.dart';
import 'shared/widgets/auth_gate.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const ProviderScope(child: ClienteApp()));
}

class ClienteApp extends StatelessWidget {
  const ClienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inDrive Entregas — Cliente',
      theme: AppTheme.light,
      home: AuthGate(
        loginBuilder: (_) => const ClienteLoginScreen(),
        homeBuilder: (_) => const ClienteHomeScreen(),
      ),
    );
  }
}
