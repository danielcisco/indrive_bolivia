import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_service.dart';
import '../../core/offline/offline_action_queue.dart';
import '../domain/entities/calificacion.dart';
import '../domain/entities/envio.dart';
import '../domain/entities/perfil_publico.dart';
import '../domain/value_objects/money.dart';
import 'envios_repository.dart';
import 'users_repository.dart';

final enviosRepositoryProvider = Provider<EnviosRepository>((ref) {
  return EnviosRepository();
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

/// uid del usuario autenticado, reactivo a cambios de sesión — los
/// providers "mi*" de abajo lo watchean en vez de leer
/// `FirebaseAuth.instance.currentUser!.uid` directo. Bug real que esto
/// arregla: al cerrar sesión y entrar con OTRA cuenta de prueba dentro del
/// mismo proceso de la app (sin reiniciarla), esos providers quedaban con
/// el `Future` ya resuelto de la cuenta anterior (Riverpod no vuelve a
/// llamar su función solo porque el widget se reconstruye) y el header
/// seguía mostrando el nombre/rating de la cuenta vieja.
final authUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
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
      // Fallback por si esta acción quedó encolada desde antes de que
      // existiera el campo (mismo criterio que Envio.fromFirestore).
      categoria: CategoriaPaquete.fromFirestore(
        payload['categoria'] as String? ?? 'documentos',
      ),
      esFragil: payload['esFragil'] as bool? ?? false,
    );
  });

  queue.startListening();
  ref.onDispose(queue.dispose);
  return queue;
});

/// Código de entrega del envío [envioId] (Sprint 8.2) — solo resuelve un
/// valor si quien está autenticado es el cliente dueño (la regla de
/// Firestore rechaza la lectura para cualquier otro, incluido el
/// repartidor asignado).
final codigoEntregaProvider = FutureProvider.family<String?, String>((
  ref,
  envioId,
) {
  return ref.watch(enviosRepositoryProvider).obtenerCodigoEntrega(envioId);
});

/// Listener en tiempo real de un envío — usado mientras está `en_curso`
/// para reflejar la posición del repartidor sin refrescar manualmente
/// (Sprint 4.1b). Ver `EnviosRepository.streamEnvio` para el porqué esto
/// no viola la regla de "no streams masivos".
final envioStreamProvider = StreamProvider.family<Envio?, String>((
  ref,
  envioId,
) {
  return ref.watch(enviosRepositoryProvider).streamEnvio(envioId);
});

/// Envío/entrega activa del usuario autenticado, en tiempo real (Sprint
/// 16) — alimenta la card de estado en el Home de Cliente/Repartidor.
final miEnvioActivoProvider = StreamProvider<Envio?>((ref) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Stream.value(null);
  return ref.watch(enviosRepositoryProvider).streamEnvioActivoDeCliente(uid);
});

final miEntregaActivaProvider = StreamProvider<Envio?>((ref) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(enviosRepositoryProvider)
      .streamEntregaActivaDeRepartidor(uid);
});

/// Repartidores disponibles en tiempo real (sprint extra) — alimenta el
/// mapa del Home de Cliente.
final repartidoresDisponiblesProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return ref.watch(usersRepositoryProvider).streamRepartidoresDisponibles();
    });

/// Envíos `en_curso` en tiempo real para el mapa en vivo del panel Admin
/// (Sprint 5.1). Ver `EnviosRepository.streamEnviosEnCurso` para el porqué
/// este stream acotado no viola la regla de "no streams masivos".
final enviosEnCursoStreamProvider =
    StreamProvider<List<Envio>>((ref) {
      return ref
          .watch(enviosRepositoryProvider)
          .streamEnviosEnCurso()
          .map((snapshot) => snapshot.docs.map(Envio.fromFirestore).toList());
    });

/// Si el usuario autenticado ya calificó [envioId] — null si todavía no
/// (Sprint 6.1). Sirve tanto para Cliente como para Repartidor: cada uno
/// consulta con su propio uid, que es el mismo para ambos porque
/// `obtenerCalificacionDe` busca por el uid de quien está logueado.
final miCalificacionProvider = FutureProvider.family<Calificacion?, String>((
  ref,
  envioId,
) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Future.value(null);
  return ref.watch(enviosRepositoryProvider).obtenerCalificacionDe(envioId, uid);
});

/// Combina el claim `isVerified` del ID token con `cedulaUrl` de
/// Firestore (diferido de KYC, seguimiento del Sprint 5.1) — decide si
/// `RepartidorHomeScreen` muestra el aviso de subir la foto de la Cédula.
/// Promedio de calificaciones del usuario autenticado (sprint extra,
/// Grupo B) — mostrado en cada Home.
final miRatingProvider = FutureProvider<({double promedio, int total})>((
  ref,
) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Future.value((promedio: 0.0, total: 0));
  return ref.watch(usersRepositoryProvider).obtenerMiRating(uid);
});

/// Perfil (nombre/nick/avatar) del usuario autenticado — alimenta
/// `UserProfileHeader` en las 3 apps.
final miPerfilProvider = FutureProvider<PerfilPublico?>((ref) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Future.value(null);
  return ref.watch(usersRepositoryProvider).obtenerMiPerfil(uid);
});

/// Perfil público de OTRO usuario — usado en el detalle de un envío para
/// mostrar la identidad de la contraparte (Cliente↔Repartidor).
final perfilPublicoProvider = FutureProvider.family<PerfilPublico?, String>((
  ref,
  uid,
) {
  return ref.watch(usersRepositoryProvider).obtenerPerfilPublico(uid);
});

/// Disponibilidad del repartidor autenticado (Sprint 8.4) — alimenta el
/// `Switch` de `RepartidorHomeScreen`.
final miDisponibilidadProvider = FutureProvider<bool>((ref) {
  final uid = ref.watch(authUidProvider).value;
  if (uid == null) return Future.value(true);
  return ref.watch(usersRepositoryProvider).obtenerDisponibilidad(uid);
});

final miEstadoKycProvider =
    FutureProvider<({bool isVerified, String? cedulaUrl})>((ref) async {
      final uid = ref.watch(authUidProvider).value;
      if (uid == null) return (isVerified: false, cedulaUrl: null);
      final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
      final isVerified = token.claims?['isVerified'] as bool? ?? false;
      final cedulaUrl = await ref
          .watch(usersRepositoryProvider)
          .obtenerCedulaUrl(uid);
      return (isVerified: isVerified, cedulaUrl: cedulaUrl);
    });
