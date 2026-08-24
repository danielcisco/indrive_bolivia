import 'package:flutter/material.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/cliente/presentation/screens/cliente_home_screen.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const ClienteApp());
}

class ClienteApp extends StatelessWidget {
  const ClienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inDrive Entregas — Cliente',
      theme: AppTheme.light,
      home: const ClienteHomeScreen(),
    );
  }
}
