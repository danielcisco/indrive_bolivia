import 'package:flutter/material.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/screens/admin_home_screen.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inDrive Entregas — Panel Admin',
      theme: AppTheme.light,
      home: const AdminHomeScreen(),
    );
  }
}
