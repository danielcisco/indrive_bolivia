import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/fcm_service.dart';
import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/cliente/presentation/screens/cliente_home_screen.dart';
import 'features/cliente/presentation/screens/cliente_login_screen.dart';
import 'features/cliente/presentation/screens/envio_detalle_screen.dart';
import 'firebase_options.dart';
import 'shared/data/providers.dart';
import 'shared/widgets/auth_gate.dart';
import 'shared/widgets/bienvenida_screen.dart';
import 'shared/widgets/esperando_verificacion_screen.dart';

/// Navegación fuera del árbol de widgets (Sprint 13): al tocar una
/// notificación sobre un envío (aceptado, contraoferta, recogido), navega
/// usando esta key en vez de necesitar un `BuildContext` que no tiene
/// disponible.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await bootstrapApp(options: DefaultFirebaseOptions.androidCliente);
  runApp(
    ProviderScope(
      overrides: [
        fcmServiceProvider.overrideWith((ref) {
          final service = FcmService(
            onEnvioNotificationTap: (envioId) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => EnvioDetalleScreen(envioId: envioId),
                ),
              );
            },
          );
          unawaited(service.initialize());
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
      child: const ClienteApp(),
    ),
  );
}

class ClienteApp extends ConsumerWidget {
  const ClienteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arranca FCM por primera vez del lado Cliente (sprint extra, Grupo
    // D) — mismo patrón que ya usa RepartidorApp.
    ref.watch(fcmServiceProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'inDrive Entregas — Cliente',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: AuthGate(
        expectedRole: 'cliente',
        requierePerfilCompleto: true,
        loginBuilder: (_) => BienvenidaScreen(
          appLabel: 'Cliente',
          destino: (_) => const ClienteLoginScreen(),
        ),
        verificacionPendienteBuilder: (_, onVerificado) =>
            EsperandoVerificacionScreen(
              onVerificado: onVerificado,
              appLabel: 'Cliente',
              descripcionDesbloqueo: 'puedas publicar envíos',
            ),
        homeBuilder: (_) => const ClienteHomeScreen(),
      ),
    );
  }
}
