import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../firebase_options.dart';
import '../../shared/data/envios_repository.dart';
import 'location_accuracy_filter.dart';

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
@pragma('vm:entry-point')
void onStartTracking(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repository = EnviosRepository();
  String? envioId;
  StreamSubscription<Position>? positionSubscription;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  service.on('setEnvioId').listen((event) {
    envioId = event?['envioId'] as String?;
  });

  service.on('stopService').listen((event) async {
    await positionSubscription?.cancel();
    await service.stopSelf();
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
