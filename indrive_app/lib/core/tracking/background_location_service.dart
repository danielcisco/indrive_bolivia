import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../firebase_options.dart';
import '../../shared/data/envios_repository.dart';
import '../../shared/domain/entities/envio.dart';
import 'location_accuracy_filter.dart';

/// Cuánto esperar por `setEnvioId` desde la UI antes de asumir que este
/// arranque del isolate es una recuperación tras un kill del proceso (no
/// un arranque normal disparado por "Iniciar viaje").
const _esperaAntesDeRecuperarEstado = Duration(seconds: 5);

const String kTrackingNotificationChannelId = 'tracking_en_curso';
const int _kTrackingNotificationId = 911;

/// Configura (sin arrancar) el Foreground Service de tracking. Se llama
/// una vez al iniciar la app Repartidor — arrancar/detener el servicio de
/// verdad lo hacen [iniciarTracking]/[detenerTracking] cuando el
/// repartidor toca "Iniciar viaje"/"Marcar como entregado".
Future<void> initializeBackgroundLocationService() async {
  const channel = AndroidNotificationChannel(
    kTrackingNotificationChannelId,
    'Entrega en curso',
    description:
        'Notificación persistente mientras el tracking GPS está activo.',
    importance: Importance.low,
  );
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartTracking,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: kTrackingNotificationChannelId,
      initialNotificationTitle: 'Entrega en curso',
      initialNotificationContent: 'Preparando el rastreo de ubicación...',
      foregroundServiceNotificationId: _kTrackingNotificationId,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

Future<void> iniciarTracking(String envioId) async {
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
  service.invoke('setEnvioId', {'envioId': envioId});
}

void detenerTracking() {
  FlutterBackgroundService().invoke('stopService');
}

/// Corre en un isolate separado del de la UI — por eso necesita su propia
/// inicialización de Firebase, y por eso está marcado como entry point.
///
/// Este archivo es inherentemente solo-Repartidor (nada más lo invoca), así
/// que usa sus `FirebaseOptions` de forma explícita en vez de
/// `currentPlatform` — evita depender de qué flavor cree Android que está
/// corriendo.
@pragma('vm:entry-point')
void onStartTracking(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.androidRepartidor,
  );

  final repository = EnviosRepository();
  String? envioId;
  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<Envio?>? envioStatusSubscription;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  Future<void> detener() async {
    await positionSubscription?.cancel();
    await envioStatusSubscription?.cancel();
    await service.stopSelf();
  }

  // Un único punto de entrada para "este es el envío que hay que trackear
  // ahora", sea porque la UI lo pidió (setEnvioId) o porque se recuperó
  // solo tras un restart del proceso (ver más abajo). Suscribirse al
  // propio envío es lo que permite el auto-stop: antes el único freno era
  // que el repartidor tocara "Marcar como entregado" en la UI — si el
  // status deja de ser en_curso por cualquier otra vía, el tracking se
  // detiene solo, sin depender de esa acción manual.
  void rastrear(String id) {
    envioId = id;
    envioStatusSubscription?.cancel();
    envioStatusSubscription = repository.streamEnvio(id).listen((envio) {
      if (envio == null || envio.status != EnvioStatus.enCurso) {
        detener();
      }
    });
  }

  service.on('setEnvioId').listen((event) {
    final id = event?['envioId'] as String?;
    if (id != null) rastrear(id);
  });

  service.on('stopService').listen((event) => detener());

  // Recuperación tras muerte del proceso: si Android mata y reinicia el
  // servicio solo (autoStart interno del plugin), este isolate arranca de
  // cero y nadie vuelve a invocar setEnvioId desde la UI. Si no llega en
  // este plazo, se asume que es ese caso y se recupera el envío en_curso
  // del repartidor autenticado desde Firestore.
  Future<void>.delayed(_esperaAntesDeRecuperarEstado, () async {
    if (envioId != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await repository.listarEntregasDeRepartidor(
      uid,
      limit: 20,
    );
    for (final envio in snapshot.docs.map(Envio.fromFirestore)) {
      if (envio.status == EnvioStatus.enCurso) {
        rastrear(envio.id);
        return;
      }
    }
  });

  // distanceFilter en vez de un Timer: el propio proveedor de ubicación
  // del sistema operativo descarta lecturas hasta que el dispositivo se
  // mueve ~15 m — throttling por distancia, tal como exige CLAUDE.md, sin
  // "streams crudos" ni cálculo manual de distancia.
  positionSubscription = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    ),
  ).listen((position) async {
    final id = envioId;
    if (id == null || !esPosicionValida(position)) return;
    await repository.actualizarPosicionRepartidor(
      envioId: id,
      posicion: GeoPoint(position.latitude, position.longitude),
    );
  });
}
