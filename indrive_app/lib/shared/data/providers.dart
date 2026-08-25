import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_service.dart';
import '../../core/offline/offline_action_queue.dart';
import '../domain/entities/envio.dart';
import '../domain/value_objects/money.dart';
import 'envios_repository.dart';
import 'users_repository.dart';

final enviosRepositoryProvider = Provider<EnviosRepository>((ref) {
  return EnviosRepository();
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

/// Instancia única del servicio de notificaciones — se inicializa apenas
/// algo lo lee por primera vez (`RepartidorApp` lo hace en su build), igual
/// que `offlineActionQueueProvider` arranca su propio ciclo de vida solo.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});

/// Instancia única de la cola offline para toda la app: registra el
/// handler de `crear_envio` (el único conectado por ahora — Sprint 3.2
/// sumará más), empieza a escuchar reconexión, y libera sus recursos
/// cuando el provider se destruye.
final offlineActionQueueProvider = Provider<OfflineActionQueue>((ref) {
  final queue = OfflineActionQueue();
  final repository = ref.watch(enviosRepositoryProvider);

  queue.registerHandler('crear_envio', (action) async {
    final payload = action.payload;
    await repository.crearEnvioConId(
      action.id,
      clienteId: payload['clienteId'] as String,
      descripcion: payload['descripcion'] as String,
      origen: GeoPoint(
        (payload['origenLat'] as num).toDouble(),
        (payload['origenLng'] as num).toDouble(),
      ),
      destino: GeoPoint(
        (payload['destinoLat'] as num).toDouble(),
        (payload['destinoLng'] as num).toDouble(),
      ),
      montoOfertadoInicial: Money.centavos(payload['montoCentavos'] as int),
    );
  });

  queue.startListening();
  ref.onDispose(queue.dispose);
  return queue;
});

/// Fetch puntual de un envío por id (no es un stream: Sprint 3.1 no
/// requiere tiempo real todavía, eso llega con FCM en Fase 3.2/4.1).
final envioProvider = FutureProvider.family<Envio?, String>((ref, envioId) {
  return ref.watch(enviosRepositoryProvider).obtenerEnvio(envioId);
});
