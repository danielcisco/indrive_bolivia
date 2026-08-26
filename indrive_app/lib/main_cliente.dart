import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/cliente/presentation/screens/cliente_home_screen.dart';
import 'features/cliente/presentation/screens/cliente_login_screen.dart';
import 'firebase_options.dart';
import 'shared/data/providers.dart';
import 'shared/widgets/auth_gate.dart';

Future<void> main() async {
  await bootstrapApp(options: DefaultFirebaseOptions.androidCliente);
  runApp(const ProviderScope(child: ClienteApp()));
}

class ClienteApp extends ConsumerWidget {
  const ClienteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arranca FCM por primera vez del lado Cliente (sprint extra, Grupo
    // D) — mismo patrón que ya usa RepartidorApp.
    ref.watch(fcmServiceProvider);

    return MaterialApp(
      title: 'inDrive Entregas — Cliente',
      theme: AppTheme.light,
      home: AuthGate(
        expectedRole: 'cliente',
        loginBuilder: (_) => const ClienteLoginScreen(),
        homeBuilder: (_) => const ClienteHomeScreen(),
      ),
    );
  }
}
