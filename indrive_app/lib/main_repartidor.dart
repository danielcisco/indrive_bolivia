import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/tracking/background_location_service.dart';
import 'features/repartidor/presentation/screens/repartidor_home_screen.dart';
import 'features/repartidor/presentation/screens/repartidor_login_screen.dart';
import 'firebase_options.dart';
import 'shared/data/providers.dart';
import 'shared/widgets/auth_gate.dart';
import 'shared/widgets/bienvenida_screen.dart';
import 'shared/widgets/esperando_verificacion_screen.dart';

Future<void> main() async {
  await bootstrapApp(options: DefaultFirebaseOptions.androidRepartidor);
  await initializeBackgroundLocationService();
  runApp(const ProviderScope(child: RepartidorApp()));
}

class RepartidorApp extends ConsumerWidget {
  const RepartidorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fuerza la creación (y por lo tanto el arranque) del servicio de
    // notificaciones apenas la app monta — mismo patrón que
    // offlineActionQueueProvider arrancando su propio ciclo de vida solo.
    ref.watch(fcmServiceProvider);

    return MaterialApp(
      title: 'inDrive Entregas — Repartidor',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: AuthGate(
        expectedRole: 'repartidor',
        requierePerfilCompleto: true,
        loginBuilder: (_) => BienvenidaScreen(
          appLabel: 'Repartidor',
          destino: (_) => const RepartidorLoginScreen(),
        ),
        verificacionPendienteBuilder: (_, onVerificado) =>
            EsperandoVerificacionScreen(
              onVerificado: onVerificado,
              appLabel: 'Repartidor',
              descripcionDesbloqueo: 'veas envíos disponibles',
            ),
        homeBuilder: (_) => const RepartidorHomeScreen(),
      ),
    );
  }
}
