import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import 'crashlytics_service.dart';

/// Bootstrap común a los tres entry points (Cliente, Repartidor, Admin):
/// inicializa Firebase y engancha Crashlytics antes de correr la app.
///
/// [options] es obligatorio pasarlo explícito en Android (Cliente y
/// Repartidor tienen `applicationId`/Firebase apps distintos por flavor,
/// ver `firebase_options.dart`) — si se omite, cae a
/// `DefaultFirebaseOptions.currentPlatform`, que sigue funcionando tal
/// cual para Admin (Web, no tiene el problema de flavors).
///
/// Firebase Performance Monitoring no necesita llamada explícita: queda
/// activo automáticamente en cuanto [Firebase.initializeApp] corre.
Future<void> bootstrapApp({FirebaseOptions? options}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: options ?? DefaultFirebaseOptions.currentPlatform,
  );
  await CrashlyticsService.initialize();
}
