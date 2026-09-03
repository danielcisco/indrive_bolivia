import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/fcm_service.dart';
import 'core/observability/app_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/tracking/background_location_service.dart';
import 'features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart';
import 'features/repartidor/presentation/screens/mis_entregas_screen.dart';
import 'features/repartidor/presentation/screens/repartidor_home_screen.dart';
import 'features/repartidor/presentation/screens/repartidor_login_screen.dart';
import 'firebase_options.dart';
import 'shared/data/providers.dart';
import 'shared/widgets/auth_gate.dart';
import 'shared/widgets/bienvenida_screen.dart';
import 'shared/widgets/esperando_verificacion_screen.dart';

/// Navegación fuera del árbol de widgets (Sprint 13): al tocar una
/// notificación de envío nuevo, `FcmService` navega usando esta key en vez
/// de necesitar un `BuildContext` que no tiene disponible.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await bootstrapApp(options: DefaultFirebaseOptions.androidRepartidor);
  await initializeBackgroundLocationService();
  runApp(
    ProviderScope(
      overrides: [
        fcmServiceProvider.overrideWith((ref) {
          final service = FcmService(
            onEnvioNotificationTap: (envioId, tipo) {
              // "oferta_aceptada" (Sprint 14): el envío pasó a estar
              // asignado a este repartidor por decisión del Cliente, no
              // por una acción propia — `EnvioRepartidorDetalleScreen`
              // asume un envío todavía pendiente (muestra "Aceptar
              // directo"/contraoferta) y no tiene sentido acá. Va a "Mis
              // entregas" con el envío resaltado en su lugar.
              if (tipo == 'oferta_aceptada') {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MisEntregasScreen(envioIdRecienAsignado: envioId),
                  ),
                );
                return;
              }
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) =>
                      EnvioRepartidorDetalleScreen(envioId: envioId),
                ),
              );
            },
            // Sin envioId (sprint extra: verificación de cuenta) — vuelve
            // a la ruta base, donde `AuthGate` ya lee `isVerified` en
            // tiempo real vía `EsperandoVerificacionScreen`.
            onCuentaVerificada: () => navigatorKey.currentState
                ?.popUntil((route) => route.isFirst),
          );
          unawaited(service.initialize());
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
      child: const RepartidorApp(),
    ),
  );
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
      navigatorKey: navigatorKey,
      title: 'inDrive Entregas — Repartidor',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
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
