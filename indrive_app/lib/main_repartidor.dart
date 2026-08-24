import 'package:flutter/material.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/repartidor/presentation/screens/repartidor_home_screen.dart';
import 'features/repartidor/presentation/screens/repartidor_login_screen.dart';
import 'shared/widgets/auth_gate.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const RepartidorApp());
}

class RepartidorApp extends StatelessWidget {
  const RepartidorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inDrive Entregas — Repartidor',
      theme: AppTheme.light,
      home: AuthGate(
        loginBuilder: (_) => const RepartidorLoginScreen(),
        homeBuilder: (_) => const RepartidorHomeScreen(),
      ),
    );
  }
}
